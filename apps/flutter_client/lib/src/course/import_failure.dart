import 'package:flutter/foundation.dart';

/// Why a typed address can't be sent, or was refused by the server.
enum AddressIssue {
  /// Nothing was typed.
  empty,

  /// The text is not a GitHub repository address.
  malformed,

  /// The address names a host other than github.com.
  otherHost,
}

/// One problem the validator found in a repository's course.yaml
/// (`details.errors[]` of `invalid_manifest`).
@immutable
class ManifestProblem {
  /// Creates a problem.
  const ManifestProblem({
    required this.code,
    required this.path,
    required this.message,
  });

  /// The validator's stable code, such as `SCHEMA_INVALID`.
  final String code;

  /// JSON Pointer to the offending value; empty for the whole file.
  final String path;

  /// The validator's explanation.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ManifestProblem &&
      other.code == code &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, path, message);
}

/// Why opening a course failed: one case per row of the J5 error table
/// (`docs/ux/journeys-m2.md`).
///
/// The repository throws these so a screen never reads status codes.
@immutable
sealed class ImportFailure implements Exception {
  const ImportFailure();

  /// The support reference of the server's answer; null when no answer
  /// arrived, or the answer had no usable body.
  String? get requestId => null;
}

/// No response arrived: offline, DNS failure or a lost connection.
final class ImportOffline extends ImportFailure {
  /// Creates the failure.
  const ImportOffline();
}

/// No answer arrived within the client's time limit.
final class ImportTimedOut extends ImportFailure {
  /// Creates the failure.
  const ImportTimedOut();
}

/// The address is not one the server accepts: found by the client's own
/// check, or reported by `invalid_url` (400).
final class ImportInvalidAddress extends ImportFailure {
  /// Creates the failure.
  const ImportInvalidAddress(this.issue);

  /// What is wrong with the address.
  final AddressIssue issue;
}

/// `course_not_found` (404): missing, private and unsafe repositories look
/// the same (V4-SEC-03).
final class ImportNotFound extends ImportFailure {
  /// Creates the failure.
  const ImportNotFound({this.requestId});

  @override
  final String? requestId;
}

/// `manifest_missing` (422): no course.yaml at the top level.
final class ImportManifestMissing extends ImportFailure {
  /// Creates the failure.
  const ImportManifestMissing({this.requestId});

  @override
  final String? requestId;
}

/// `invalid_manifest` (422): course.yaml failed validation.
final class ImportInvalidManifest extends ImportFailure {
  /// Creates the failure.
  const ImportInvalidManifest({
    required this.problems,
    this.truncated = false,
    this.requestId,
  });

  /// The problems in the order the validator reported them.
  final List<ManifestProblem> problems;

  /// Whether the validator stopped listing before the end.
  final bool truncated;

  @override
  final String? requestId;
}

/// `manifest_too_large` (413): course.yaml is bigger than the server reads.
final class ImportManifestTooLarge extends ImportFailure {
  /// Creates the failure.
  const ImportManifestTooLarge({this.requestId});

  @override
  final String? requestId;
}

/// `rate_limited` (429).
final class ImportRateLimited extends ImportFailure {
  /// Creates the failure.
  const ImportRateLimited({this.retryAfter, this.requestId});

  /// How long to wait, when the server said.
  final Duration? retryAfter;

  @override
  final String? requestId;
}

/// `github_unavailable` (502) or `repository_changed` (503): GitHub didn't
/// answer, or the repository couldn't be confirmed.
final class ImportGitHubUnavailable extends ImportFailure {
  /// Creates the failure.
  const ImportGitHubUnavailable({this.requestId});

  @override
  final String? requestId;
}

/// Any other answer.
final class ImportUnexpected extends ImportFailure {
  /// Creates the failure.
  const ImportUnexpected({required this.retryable, this.requestId});

  /// Whether the server said trying again can help.
  final bool retryable;

  @override
  final String? requestId;
}

/// The caller cancelled the request. Not a J5 case, so it is not an
/// [ImportFailure]: nothing is shown for it.
class ImportCancelled implements Exception {
  /// Creates the signal.
  const ImportCancelled();
}
