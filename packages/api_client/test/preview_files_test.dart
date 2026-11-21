import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

const _sha = CommitSha('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
const _repoId = GitHubRepoId(42);

class _FileAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(
      options.uri.path,
      '/api/preview/42/${_sha.value}/files/media/pic.png',
    );
    expect(options.headers['Range'], 'bytes=0-2');
    return ResponseBody.fromBytes(
      [255, 1, 128],
      206,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
        'content-range': ['bytes 0-2/9'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'streams a nested file range with literal separators and binary bytes',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://lectale.test/api'))
        ..httpClientAdapter = _FileAdapter();
      addTearDown(client.close);
      final response = await client.openPreviewFile(
        repoId: _repoId,
        sha: _sha,
        path: 'media/pic.png',
        range: 'bytes=0-2',
      );

      expect(response.statusCode, 206);
      expect(response.headers.value('content-range'), 'bytes 0-2/9');
      expect(await response.data!.stream.expand((chunk) => chunk).toList(), [
        255,
        1,
        128,
      ]);
    },
  );

  test('rejects unsafe file paths before Dio can normalize them', () {
    final client = Dio();
    addTearDown(client.close);
    for (final path in ['a/../b', 'a%2Fb', 'a//b', '.git/config', r'a\b']) {
      expect(
        () => client.openPreviewFile(repoId: _repoId, sha: _sha, path: path),
        throwsArgumentError,
      );
    }
  });

  test('decodes folder entry types, sizes and canonical file hrefs', () {
    const prefix =
        '/api/preview/42/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        '/files/media';
    final folder = PreviewFolder.fromJson({
      'entries': [
        {
          'name': 'src/pic.png',
          'type': 'file',
          'size': 9,
          'href': '$prefix/src/pic.png',
        },
        {'name': 'src', 'type': 'directory', 'size': 0},
      ],
    });
    expect(folder.entries.first.type, PreviewFolderEntryType.file);
    expect(folder.entries.first.size, 9);
    expect(folder.entries.first.name, 'src/pic.png');
    expect(folder.entries.first.href, '$prefix/src/pic.png');
    expect(folder.entries.last.type, PreviewFolderEntryType.directory);
    expect(folder.entries.last.href, isNull);
  });
}
