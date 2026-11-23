import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// Opens public courses through the Lectale API.
///
/// It is the only place that knows status codes and error codes: screens get
/// a [CoursePreview] or an [ImportFailure].
class CourseRepository {
  /// Creates a repository over `_dio`, which already points at the API root.
  CourseRepository(this._dio, {this.timeout = const Duration(seconds: 30)})
    : _api = LectaleApi(_dio).api;

  final Dio _dio;
  final ApiClient _api;

  /// How long to wait for an answer before giving up (J5, "taking too long").
  final Duration timeout;

  /// Imports the course at [url], which must already be the canonical
  /// `https://github.com/owner/repository` form (V4-CORE-01).
  ///
  /// Throws an [ImportFailure] for every outcome the J5 table names, and
  /// [ImportCancelled] when [cancelToken] was cancelled.
  Future<CoursePreview> importCourse(
    String url, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api
          .importCourse(ImportCourseRequest(url: url), cancelToken: cancelToken)
          .timeout(timeout);
    } on TimeoutException {
      // Stop the request that is still running; nobody is waiting for it.
      cancelToken?.cancel('timed out');
      throw const ImportTimedOut();
    } on DioException catch (error) {
      throw failureFromDio(await _withParsedBody(error));
      // The generated models throw errors, not exceptions, for a 200 body
      // that breaks the contract. A learner needs the J5 message, not a crash.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const ImportUnexpected(retryable: false);
      // The same reason: a wrongly typed field in a 200 body.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const ImportUnexpected(retryable: false);
    }
  }
}

/// Reloads and reads a pinned preview: the same answers as an import, for a
/// reload, a bookmark or a shared link (J3a).
extension PreviewLoading on CourseRepository {
  /// Reloads the preview at [key]. Throws an [ImportFailure] for each J5
  /// case; a 404 is [ImportNotFound].
  Future<CoursePreview> preview(PreviewKey key) =>
      _guard(() => _api.getPreview(repoId: key.apiRepoId, sha: key.apiSha));

  /// Reads the course's root README as Markdown, at most [inlineTextLimit]
  /// bytes (512 KiB, as for lesson Markdown), judged while reading and so
  /// also when the answer has no length header.
  ///
  /// Throws an [ImportFailure]; a 404 is [ImportNotFound], which here means
  /// the file is missing. Throws [ResourceTooLarge] over the limit.
  Future<String> readme(PreviewKey key) async {
    final bytes = await _guard(
      () => readBoundedBytes(
        _dio,
        '/preview/${key.repoId}/${key.sha}/readme',
        maxBytes: inlineTextLimit,
      ),
    );
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ImportTimedOut();
    } on DioException catch (error) {
      throw failureFromDio(await _withParsedBody(error));
      // The generated models throw errors, not exceptions, for a 200 body
      // that breaks the contract.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const ImportUnexpected(retryable: false);
      // The same reason: a wrongly typed field in a 200 body.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const ImportUnexpected(retryable: false);
    }
  }
}

/// Reads [path] under the API root as bytes, stopping at [maxBytes] while it
/// reads, so a large or endless answer is never buffered whole and a missing
/// length header changes nothing.
///
/// Throws [ResourceTooLarge] over the limit, and the J5 [ImportFailure] for
/// every other failure, with the server's error body read so the code is
/// known.
Future<Uint8List> readBoundedBytes(
  Dio dio,
  String path, {
  int? maxBytes,
}) async {
  final cancel = CancelToken();
  var tooLarge = false;
  try {
    final response = await dio.get<List<int>>(
      path,
      cancelToken: cancel,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: maxBytes == null
          ? null
          : (received, total) {
              if (received > maxBytes || total > maxBytes) {
                tooLarge = true;
                cancel.cancel('too large');
              }
            },
    );
    final bytes = Uint8List.fromList(response.data ?? const []);
    if (maxBytes != null && bytes.length > maxBytes) {
      throw const ResourceTooLarge();
    }
    return bytes;
  } on DioException catch (error) {
    if (tooLarge) {
      throw const ResourceTooLarge();
    }
    final response = error.response;
    final data = response?.data;
    if (response != null && data is List<int>) {
      // A byte answer carries the error body as bytes; read it so the J5
      // mapping can see its `code`.
      try {
        response.data = jsonDecode(utf8.decode(data, allowMalformed: true));
      } on FormatException {
        response.data = null;
      }
    }
    throw failureFromDio(error);
  }
}

/// A streamed error answer (the README route) arrives unread; read it, so
/// the J5 mapping can see the error's `code`.
Future<DioException> _withParsedBody(DioException error) async {
  final response = error.response;
  final data = response?.data;
  if (response != null && data is ResponseBody) {
    try {
      final bytes = await data.stream.expand((chunk) => chunk).toList();
      response.data = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      response.data = null;
    }
  }
  return error;
}

/// Maps a transport error to the J5 case it belongs to.
///
/// Throws [ImportCancelled] for a cancelled request.
ImportFailure failureFromDio(DioException error) {
  switch (error.type) {
    case DioExceptionType.cancel:
      throw const ImportCancelled();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const ImportTimedOut();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const ImportOffline();
    case DioExceptionType.badResponse:
      return _failureFromResponse(error.response);
    case DioExceptionType.unknown:
      return error.response == null
          ? const ImportOffline()
          : _failureFromResponse(error.response);
  }
}

ImportFailure _failureFromResponse(Response<dynamic>? response) {
  final status = response?.statusCode ?? 0;
  final body = _apiErrorOf(response?.data);
  if (body == null) {
    // An answer without Lectale's error body, such as a proxy's page. A
    // server fault may pass; a client fault will not.
    return ImportUnexpected(retryable: status >= 500);
  }
  final requestId = body.requestId;
  return switch (body.code) {
    'invalid_url' => const ImportInvalidAddress(AddressIssue.malformed),
    'course_not_found' => ImportNotFound(requestId: requestId),
    'manifest_missing' => ImportManifestMissing(requestId: requestId),
    'invalid_manifest' => ImportInvalidManifest(
      problems: _problemsOf(body.details),
      truncated: body.details?['truncated'] == true,
      requestId: requestId,
    ),
    'manifest_too_large' => ImportManifestTooLarge(requestId: requestId),
    'rate_limited' => ImportRateLimited(
      retryAfter: _waitOf(body.retryAfterSeconds),
      requestId: requestId,
    ),
    'github_unavailable' ||
    'repository_changed' => ImportGitHubUnavailable(requestId: requestId),
    _ => ImportUnexpected(retryable: body.retryable, requestId: requestId),
  };
}

ApiError? _apiErrorOf(Object? data) {
  if (data is! Map<dynamic, dynamic>) {
    return null;
  }
  try {
    return ApiError.fromJson(data.cast<String, Object?>());
    // A body that is not Lectale's error shape makes the generated model
    // throw errors; treat it as an answer without a usable body.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return null;
    // The same reason: a wrongly typed field.
    // ignore: avoid_catching_errors
  } on TypeError {
    return null;
  }
}

Duration? _waitOf(num? seconds) {
  if (seconds == null || seconds < 0) {
    return null;
  }
  return Duration(seconds: seconds.ceil());
}

List<ManifestProblem> _problemsOf(Map<String, Object?>? details) {
  final errors = details?['errors'];
  if (errors is! List<Object?>) {
    return const [];
  }
  return [
    for (final item in errors)
      if (item is Map<Object?, Object?>)
        ManifestProblem(
          code: '${item['code'] ?? ''}',
          path: '${item['path'] ?? ''}',
          message: '${item['message'] ?? ''}',
        ),
  ];
}
