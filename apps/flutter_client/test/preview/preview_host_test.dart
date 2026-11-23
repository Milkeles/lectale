import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/preview/preview_host.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:resource_renderers/resource_renderers.dart';

import '../support/course_fixture.dart';
import '../support/fake_http_adapter.dart';
import '../support/pump_app.dart';

/// The trust boundary of the viewers: the real [PreviewResourceHost] reaches
/// only the pinned course, whatever a manifest or a Markdown file asks for
/// (V4-SEC-03, threat 5.6).
void main() {
  late FakeHttpAdapter server;
  late PreviewResourceHost host;
  final opened = <Uri>[];

  setUp(() {
    server = FakeHttpAdapter();
    opened.clear();
    final dio = Dio(BaseOptions(baseUrl: 'https://lectale.test/api'))
      ..httpClientAdapter = server;
    host = PreviewResourceHost(
      dio: dio,
      key: const PreviewKey(repoId: fixtureRepoId, sha: fixtureSha),
      opener: (uri) async {
        opened.add(uri);
        return true;
      },
    );
  });

  const base = '/api/preview/$fixtureRepoId/$fixtureSha';
  const otherSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final refused = <String, String>{
    'a foreign repository ID':
        '/api/preview/43/$fixtureSha/content/lesson/item',
    'a foreign commit': '/api/preview/$fixtureRepoId/$otherSha/content/a/b',
    'a foreign commit on the files route':
        '/api/preview/$fixtureRepoId/$otherSha/files/a.png',
    'a dot segment': '$base/files/a/../b.png',
    'a dot segment out of the course': '$base/files/../../x.png',
    'a double slash': '$base/files//x.png',
    'a double slash after the prefix': '$base//files/x.png',
    'the README route, which is not a file': '$base/readme',
    'the course route': base,
    'another API area': '/api/courses/some-course/content/a/b',
    'an unrelated API route': '/api/health',
    'a catalog route': '/api/catalog',
    'an absolute address': 'https://evil.example$base/files/a.png',
    'a protocol-relative address': '//evil.example$base/files/a.png',
    'a relative path': 'preview/$fixtureRepoId/$fixtureSha/files/a.png',
    'a trailing newline': '$base/files/a.png\n',
    'a backslash': '$base/files/a\\b.png',
    'an encoded dot segment': '$base/files/%2e%2e/x.png',
    'a query string': '$base/files/a.png?x=1',
    'a fragment': '$base/files/a.png#x',
    'an empty file name': '$base/files/',
    'an upper-case commit':
        '/api/preview/$fixtureRepoId/${fixtureSha.toUpperCase()}/files/a.png',
  };

  group('refused before any request', () {
    for (final MapEntry(key: name, value: href) in refused.entries) {
      test('read of $name', () async {
        await expectLater(
          host.read(ApiHref(href)),
          throwsA(isA<ArgumentError>()),
        );
        expect(server.requests, isEmpty);
      });

      test('address of $name', () {
        expect(() => host.addressOf(ApiHref(href)), throwsArgumentError);
      });

      test('folder listing of $name', () async {
        await expectLater(host.listFolder(href), throwsA(isA<ArgumentError>()));
        expect(server.requests, isEmpty);
      });
    }

    test('a repository path that climbs out of the course', () async {
      for (final path in ['../x.png', 'a/../../x.png', '/etc/passwd', '']) {
        await expectLater(
          host.read(RepositoryFile(path)),
          throwsA(isA<ArgumentError>()),
          reason: path,
        );
      }
      expect(server.requests, isEmpty);
    });

    test('opening a foreign commit is refused, not launched', () {
      expect(
        () => host.addressOf(
          const ApiHref('/api/preview/$fixtureRepoId/$otherSha/files/a.png'),
        ),
        throwsArgumentError,
      );
      expect(opened, isEmpty);
    });
  });

  group('allowed', () {
    test('a content href of the pinned course is read as given', () async {
      server.on(
        'GET',
        '$base/content/reading-data/notes',
        const FakeResponse(200, '# Notes'),
      );

      final bytes = await host.read(
        const ApiHref('$base/content/reading-data/notes'),
      );

      expect(String.fromCharCodes(bytes), '# Notes');
      expect(server.requests.single.uri.host, 'lectale.test');
      expect(
        server.requests.single.uri.path,
        '/api/preview/$fixtureRepoId/$fixtureSha/content/reading-data/notes',
      );
    });

    test('an assignment href with its tilde is allowed', () async {
      server.on(
        'GET',
        '$base/content/assignment~homework-1/brief',
        const FakeResponse(200, 'x'),
      );

      await host.read(
        const ApiHref('$base/content/assignment~homework-1/brief'),
      );

      expect(server.requests, hasLength(1));
    });

    test(
      'a repository file is read from the files route of the commit',
      () async {
        server.on(
          'GET',
          '$base/files/figures/histogram.png',
          FakeResponse(200, fixturePng),
        );

        await host.read(const RepositoryFile('figures/histogram.png'));

        expect(
          server.requests.single.uri.toString(),
          'https://lectale.test$base/files/figures/histogram.png',
        );
      },
    );

    test(
      'the address to open is same-origin with the repository and commit',
      () {
        final uri = host.addressOf(const RepositoryFile('figures/a.png'));

        expect(uri.host, 'lectale.test');
        expect(uri.path, '$base/files/figures/a.png');
      },
    );
  });

  group('the byte limit holds while reading', () {
    test(
      'an answer over the limit is refused, without a length header',
      () async {
        // A String body carries no content-length header in the fake server.
        server.on('GET', '$base/content/a/b', FakeResponse(200, 'x' * 2000));

        await expectLater(
          host.read(const ApiHref('$base/content/a/b'), maxBytes: 1000),
          throwsA(isA<ResourceTooLarge>()),
        );
      },
    );

    test(
      'an answer over the limit is refused when its length says so',
      () async {
        server.on(
          'GET',
          '$base/content/a/b',
          FakeResponse(200, Uint8List(2000)),
        );

        await expectLater(
          host.read(const ApiHref('$base/content/a/b'), maxBytes: 1000),
          throwsA(isA<ResourceTooLarge>()),
        );
      },
    );

    test('an answer at the limit is returned', () async {
      server.on('GET', '$base/content/a/b', FakeResponse(200, Uint8List(1000)));

      final bytes = await host.read(
        const ApiHref('$base/content/a/b'),
        maxBytes: 1000,
      );

      expect(bytes, hasLength(1000));
    });

    test('a missing file is a J5 not-found, not a crash', () async {
      server.on(
        'GET',
        '$base/content/a/b',
        FakeResponse(404, apiError('course_not_found')),
      );

      await expectLater(
        host.read(const ApiHref('$base/content/a/b')),
        throwsA(isA<ImportNotFound>()),
      );
    });
  });
}
