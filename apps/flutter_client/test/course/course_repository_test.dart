import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/course/course_repository.dart';
import 'package:lectale/src/course/import_failure.dart';

import '../support/fake_http_adapter.dart';
import '../support/pump_app.dart';

const String _url = 'https://github.com/ada/stats-101';

void main() {
  late FakeHttpAdapter server;
  late CourseRepository repository;

  setUp(() {
    server = FakeHttpAdapter();
    repository = CourseRepository(
      Dio(BaseOptions(baseUrl: 'https://lectale.test/api'))
        ..httpClientAdapter = server,
      timeout: const Duration(seconds: 5),
    );
  });

  Future<ImportFailure> failureOf(FakeResponse response) async {
    server.on('POST', importPath, response);
    try {
      await repository.importCourse(_url);
    } on ImportFailure catch (failure) {
      return failure;
    }
    fail('Expected a failure.');
  }

  test('returns the pinned preview and sends the address as JSON', () async {
    server.on('POST', importPath, FakeResponse(200, previewJson(repoId: 7)));

    final preview = await repository.importCourse(_url);

    expect(preview.repoId.value, 7);
    expect(preview.sha.value, fixtureSha);
    expect(server.bodiesOf('POST', '/courses/import'), [
      {'url': _url},
    ]);
  });

  group('maps the J5 error table', () {
    test('invalid_url to the address', () async {
      expect(
        await failureOf(FakeResponse(400, apiError('invalid_url'))),
        isA<ImportInvalidAddress>().having(
          (f) => f.issue,
          'issue',
          AddressIssue.malformed,
        ),
      );
    });

    test('course_not_found with its reference', () async {
      final failure = await failureOf(
        FakeResponse(404, apiError('course_not_found', requestId: 'abc123')),
      );
      expect(failure, isA<ImportNotFound>());
      expect(failure.requestId, 'abc123');
    });

    test('manifest_missing and manifest_too_large', () async {
      expect(
        await failureOf(FakeResponse(422, apiError('manifest_missing'))),
        isA<ImportManifestMissing>(),
      );
      expect(
        await failureOf(FakeResponse(413, apiError('manifest_too_large'))),
        isA<ImportManifestTooLarge>(),
      );
    });

    test('invalid_manifest with its problems and the truncated flag', () async {
      final failure = await failureOf(
        FakeResponse(
          422,
          apiError(
            'invalid_manifest',
            details: {
              'errors': [
                {'code': 'SCHEMA_INVALID', 'path': '/title', 'message': 'No.'},
              ],
              'truncated': true,
            },
          ),
        ),
      );
      expect(
        failure,
        isA<ImportInvalidManifest>()
            .having((f) => f.truncated, 'truncated', isTrue)
            .having((f) => f.problems, 'problems', const [
              ManifestProblem(
                code: 'SCHEMA_INVALID',
                path: '/title',
                message: 'No.',
              ),
            ]),
      );
    });

    test('rate_limited with retryAfterSeconds, rounded up', () async {
      final failure = await failureOf(
        FakeResponse(429, apiError('rate_limited', retryAfterSeconds: 2.2)),
      );
      expect(
        failure,
        isA<ImportRateLimited>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 3),
        ),
      );
    });

    test('github_unavailable and repository_changed', () async {
      expect(
        await failureOf(FakeResponse(502, apiError('github_unavailable'))),
        isA<ImportGitHubUnavailable>(),
      );
      expect(
        await failureOf(FakeResponse(503, apiError('repository_changed'))),
        isA<ImportGitHubUnavailable>(),
      );
    });

    test('any other code, retryable as the server says', () async {
      expect(
        await failureOf(FakeResponse(500, apiError('x', retryable: true))),
        isA<ImportUnexpected>().having((f) => f.retryable, 'retryable', true),
      );
      expect(
        await failureOf(FakeResponse(400, apiError('x'))),
        isA<ImportUnexpected>().having((f) => f.retryable, 'retryable', false),
      );
    });

    test('no response at all as offline, with no reference', () async {
      final failure = await failureOf(const FakeResponse.offline());
      expect(failure, isA<ImportOffline>());
      expect(failure.requestId, isNull);
    });

    test('an answer that is not an error body', () async {
      expect(
        await failureOf(const FakeResponse(503, '<html>down</html>')),
        isA<ImportUnexpected>().having((f) => f.retryable, 'retryable', true),
      );
      expect(
        await failureOf(const FakeResponse(404, '<html>no</html>')),
        isA<ImportUnexpected>().having((f) => f.retryable, 'retryable', false),
      );
    });

    test('a 200 that breaks the contract', () async {
      expect(
        await failureOf(const FakeResponse(200, {'repoId': 'x'})),
        isA<ImportUnexpected>(),
      );
    });
  });

  test('gives up after the timeout and stops the request', () async {
    server.on('POST', importPath, const FakeResponse.hangs());
    final quick = CourseRepository(
      Dio(BaseOptions(baseUrl: 'https://lectale.test/api'))
        ..httpClientAdapter = server,
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      quick.importCourse(_url, cancelToken: CancelToken()),
      throwsA(isA<ImportTimedOut>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(server.cancelled, 1);
  });

  test('a cancelled request is not a failure', () async {
    server.on('POST', importPath, const FakeResponse.hangs());
    final token = CancelToken();

    final result = repository.importCourse(_url, cancelToken: token);
    await Future<void>.delayed(Duration.zero);
    token.cancel();

    await expectLater(result, throwsA(isA<ImportCancelled>()));
  });
}
