import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:lectale/src/course/course_repository.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an address outside the app.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// Opens [uri] in the browser, or the system's handler for it.
Future<bool> launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The viewers' window onto one pinned course.
///
/// It reaches only that course: a read is allowed for an address in the
/// pinned course's `content`, `folders` or `files` routes, and for nothing
/// else, whatever a course's Markdown or manifest says (V4-SEC-03, threat
/// 5.6). Failures are thrown as the app's J5 failures, so one error view
/// serves every region.
class PreviewResourceHost implements ResourceHost {
  /// Creates the host for [key], reading with [dio], whose base address is
  /// the API root.
  PreviewResourceHost({
    required this.dio,
    required this.key,
    this.opener = launchExternally,
  }) : _hrefPattern = RegExp(
         '^/api/preview/${key.repoId}/${key.sha}/'
         r'(?:content|folders)/(?:assignment~)?[a-z][a-z0-9-]*/[a-z][a-z0-9-]*$'
         '|^/api/preview/${key.repoId}/${key.sha}/files/'
         r'[A-Za-z0-9_.\-/]+$',
       );

  /// The one HTTP client of the app.
  final Dio dio;

  /// The pinned course this host serves.
  final PreviewKey key;

  /// Opens addresses outside the app. Tests replace it.
  final UrlOpener opener;

  final RegExp _hrefPattern;

  /// The path a request takes under the API root: the href without its
  /// leading `/api`.
  String _requestPath(ResourceTarget target) {
    final href = switch (target) {
      ApiHref(:final href) => href,
      RepositoryFile(:final path) =>
        '/api/preview/${key.repoId}/${key.sha}/files/$path',
    };
    if (!_hrefPattern.hasMatch(href) ||
        href.contains('..') ||
        href.contains('//')) {
      throw ArgumentError.value(href, 'target', 'Not in the pinned course.');
    }
    return href.substring('/api'.length);
  }

  @override
  Future<Uint8List> read(ResourceTarget target, {int? maxBytes}) async {
    // Checked inside the future, so a refusal is an error the caller awaits.
    final path = _requestPath(target);
    return await readBoundedBytes(dio, path, maxBytes: maxBytes);
  }

  @override
  Future<PreviewFolder> listFolder(String href) async {
    final path = _requestPath(ApiHref(href));
    try {
      final response = await dio.get<Object?>(path);
      return PreviewFolder.fromJson(
        (response.data! as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } on DioException catch (error) {
      throw failureFromDio(error);
      // A body that breaks the contract makes the generated model throw an
      // error; show the J5 "ran into a problem" copy, not a crash.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const ImportUnexpected(retryable: false);
      // The same reason: a wrongly typed field.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const ImportUnexpected(retryable: false);
    }
  }

  @override
  Uri addressOf(ResourceTarget target) {
    final href = switch (target) {
      ApiHref(:final href) => href,
      RepositoryFile(:final path) =>
        '/api/preview/${key.repoId}/${key.sha}/files/$path',
    };
    // Validates the address, so a download can't point outside the course.
    _requestPath(target);
    final base = Uri.parse(dio.options.baseUrl);
    return (base.hasAuthority ? base : Uri.base).resolve(href);
  }

  @override
  Future<bool> open(Uri uri) => opener(uri);
}
