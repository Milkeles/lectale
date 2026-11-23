import 'package:flutter/foundation.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

/// A course pinned at one commit: the numeric repository ID and the full
/// commit SHA that every preview address carries (ADR-0008).
@immutable
class PreviewKey {
  /// Creates a key. Use [tryParse] for values that come from an address.
  const PreviewKey({required this.repoId, required this.sha});

  /// The key of an import result.
  factory PreviewKey.of(CoursePreview preview) =>
      PreviewKey(repoId: preview.repoId.value, sha: preview.sha.value);

  /// Reads the two path parameters of a Course address, or returns null when
  /// they are not a positive integer and a 40-character lower-case hex SHA.
  static PreviewKey? tryParse(String? repoId, String? sha) {
    final id = int.tryParse(repoId ?? '');
    if (id == null || id <= 0 || id > 9007199254740991) {
      return null;
    }
    if (sha == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(sha)) {
      return null;
    }
    return PreviewKey(repoId: id, sha: sha);
  }

  /// The numeric GitHub repository ID.
  final int repoId;

  /// The full commit SHA.
  final String sha;

  /// The ID as the generated client takes it.
  GitHubRepoId get apiRepoId => GitHubRepoId(repoId);

  /// The SHA as the generated client takes it.
  CommitSha get apiSha => CommitSha(sha);

  @override
  bool operator ==(Object other) =>
      other is PreviewKey && other.repoId == repoId && other.sha == sha;

  @override
  int get hashCode => Object.hash(repoId, sha);

  @override
  String toString() => 'PreviewKey($repoId, $sha)';
}
