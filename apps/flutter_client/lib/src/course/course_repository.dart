import 'dart:async';

import 'package:dio/dio.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

/// Opens public courses through the Lectale API.
///
/// It is the only place that knows status codes and error codes: screens get
/// a [CoursePreview] or an [ImportFailure].
class CourseRepository {
  /// Creates a repository over [dio], which already points at the API root.
  CourseRepository(Dio dio, {this.timeout = const Duration(seconds: 30)})
    : _api = LectaleApi(dio).api;

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
      throw failureFromDio(error);
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
