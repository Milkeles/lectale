import 'package:dio/dio.dart';

import 'package:lectale_api_client/src/generated/default_client/models/commit_sha.dart';
import 'package:lectale_api_client/src/generated/default_client/models/git_hub_repo_id.dart';

final _pathSegment = RegExp(
  r'^(?:\.well-known|[A-Za-z0-9_-](?:[A-Za-z0-9_.-]*[A-Za-z0-9_-])?)$',
);
final _commit = RegExp(r'^[0-9a-f]{40}$');

/// Requests to the pinned repository files route through a Dio client
/// configured with the Lectale API base URL.
extension PreviewFileRequests on Dio {
  /// Streams a regular file at [sha] with its MIME and range headers.
  ///
  /// [path] is a canonical repository-relative path. Literal slashes delimit
  /// its segments. Set [range] to request one byte interval (SEC-027).
  Future<Response<ResponseBody>> openPreviewFile({
    required GitHubRepoId repoId,
    required CommitSha sha,
    required String path,
    String? range,
    CancelToken? cancelToken,
  }) {
    if (repoId.value <= 0 ||
        repoId.value > 9007199254740991 ||
        _commit.stringMatch(sha.value) != sha.value ||
        path.length > 500 ||
        path
            .split('/')
            .any((segment) => _pathSegment.stringMatch(segment) != segment)) {
      throw ArgumentError('Invalid pinned repository file address.');
    }

    return get<ResponseBody>(
      '/preview/${repoId.value}/${sha.value}/files/$path',
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Range': ?range},
        validateStatus: (status) => status == 200 || status == 206,
      ),
      cancelToken: cancelToken,
    );
  }
}
