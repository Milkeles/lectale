import 'package:flutter/foundation.dart';
import 'package:lectale/src/course/import_failure.dart';

// The constants are the strings themselves; a comment on each would repeat it.
// ignore_for_file: public_member_api_docs

/// Fixed texts of the Home screen (`docs/ux/screens/home.md` §9).
abstract final class HomeCopy {
  static const String title = 'Open a course from GitHub';
  static const String help =
      'Any public GitHub repository with a course.yaml file. '
      'No account needed; Lectale only reads it.';
  static const String label = 'GitHub repository address';
  static const String hint = 'For example, https://github.com/owner/repository';
  static const String button = 'Open course';
  static const String progress = 'Reading the repository';
  static const String slowProgress =
      'Still reading. Large courses take longer.';
  static const String truncated = 'Showing the first 50 problems.';

  /// Spoken once when a rate-limit wait ends. The spec asks for the end of
  /// the wait to be announced but gives no words; this is a proposal.
  static const String waitOver = 'You can try again.';
}

/// What the Home screen shows for one failure.
@immutable
class FailureCopy {
  /// Creates the copy.
  const FailureCopy({
    required this.title,
    required this.body,
    required this.summary,
    this.requestId,
    this.problems = const [],
    this.truncated = false,
  });

  /// The alert's title.
  final String title;

  /// The alert's explanation.
  final String body;

  /// What the polite live region says (S2): the title, and for the problems
  /// list also the count; for a rate limit also the wait.
  final String summary;

  /// The support reference, when the server answered.
  final String? requestId;

  /// The rows of the problems list, in the validator's order.
  final List<ProblemCopy> problems;

  /// Whether to say the list was cut.
  final bool truncated;
}

/// One row of the problems list.
@immutable
class ProblemCopy {
  /// Creates the row.
  const ProblemCopy({
    required this.message,
    required this.location,
    required this.pointer,
    required this.code,
  });

  /// The validator's message.
  final String message;

  /// Where, in words.
  final String location;

  /// The exact JSON Pointer; empty for the whole file.
  final String pointer;

  /// The validator's code.
  final String code;
}

/// The message under the field for an address problem (J5a, Home §6).
String addressMessage(AddressIssue issue) => switch (issue) {
  AddressIssue.empty => 'Enter the address of a GitHub repository.',
  AddressIssue.malformed =>
    "That doesn't look like a GitHub repository address. "
        'Use the form https://github.com/owner/repository.',
  AddressIssue.otherHost =>
    'Lectale opens repositories on github.com. '
        'Use the form https://github.com/owner/repository.',
};

/// The alert for [failure], or null when the failure belongs to the field.
FailureCopy? alertCopy(ImportFailure failure) {
  switch (failure) {
    case ImportInvalidAddress():
      return null;
    case ImportOffline():
      return _plain(
        "Lectale can't be reached",
        'Check your internet connection, then try again.',
      );
    case ImportTimedOut():
      return _plain(
        'Lectale is taking too long',
        "The request didn't finish. Try again in a moment.",
      );
    case ImportNotFound(:final requestId):
      return _plain(
        'Repository not available',
        "Lectale can't open this repository. Check the address. "
            "A private repository can't be opened here.",
        requestId,
      );
    case ImportManifestMissing(:final requestId):
      return _plain(
        "course.yaml can't be used",
        'This repository has no course.yaml at its top level. '
            'The course author needs to add one.',
        requestId,
      );
    case ImportManifestTooLarge(:final requestId):
      return _plain(
        "course.yaml can't be used",
        'course.yaml is larger than Lectale can read. '
            'The course author needs to shorten it.',
        requestId,
      );
    case ImportInvalidManifest(
      :final problems,
      :final truncated,
      :final requestId,
    ):
      const title = "course.yaml can't be used";
      final count = problems.length;
      return FailureCopy(
        title: title,
        body: count == 1
            ? "This repository's course.yaml has 1 problem. "
                  'The course author needs to fix it before it can open.'
            : "This repository's course.yaml has $count problems. "
                  'The course author needs to fix them before it can open.',
        summary: '$title. ${problemCount(count)}.',
        requestId: requestId,
        problems: [
          for (final problem in problems)
            ProblemCopy(
              message: problem.message,
              location: describePointer(problem.path),
              pointer: problem.path,
              code: problem.code,
            ),
        ],
        truncated: truncated,
      );
    case ImportRateLimited(:final retryAfter, :final requestId):
      const title = 'Too many requests';
      final wait = waitText(retryAfter);
      return FailureCopy(
        title: title,
        body: wait,
        summary: '$title. $wait',
        requestId: requestId,
      );
    case ImportGitHubUnavailable(:final requestId):
      return _plain(
        "GitHub isn't answering",
        "Lectale couldn't get this course from GitHub. "
            'Try again in a moment.',
        requestId,
      );
    case ImportUnexpected(:final requestId):
      return _plain(
        'Lectale ran into a problem',
        'Try again in a moment. '
            'If it keeps happening, quote the reference.',
        requestId,
      );
  }
}

FailureCopy _plain(String title, String body, [String? requestId]) =>
    FailureCopy(title: title, body: body, summary: title, requestId: requestId);

/// "1 problem", "3 problems".
String problemCount(int count) => count == 1 ? '1 problem' : '$count problems';

/// The wait of a rate limit, as J5 words it: seconds under a minute, whole
/// minutes (rounded up) beyond, and "a minute" when the server named none.
String waitText(Duration? wait) {
  if (wait == null) {
    return 'Try again in a minute.';
  }
  final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
  if (seconds < 60) {
    return seconds == 1
        ? 'Try again in 1 second.'
        : 'Try again in $seconds seconds.';
  }
  final minutes = (seconds / 60).ceil();
  return minutes == 1
      ? 'Try again in a minute.'
      : 'Try again in $minutes minutes.';
}

/// A JSON Pointer in words: each number is shown one higher, after the name
/// of its parent ("/outline/2/resources/0/path" reads "Outline item 3,
/// resource 1, path"), and the root reads "Whole file".
String describePointer(String pointer) {
  if (pointer.isEmpty) {
    return 'Whole file';
  }
  final parts = <String>[];
  for (final raw in pointer.substring(1).split('/')) {
    final segment = raw.replaceAll('~1', '/').replaceAll('~0', '~');
    final index = int.tryParse(segment);
    if (index == null || index < 0) {
      parts.add(segment);
      continue;
    }
    final number = index + 1;
    if (parts.isEmpty) {
      parts.add('item $number');
      continue;
    }
    final parent = parts.removeLast();
    parts.add(
      parent.length > 1 && parent.endsWith('s')
          ? '${parent.substring(0, parent.length - 1)} $number'
          : '$parent item $number',
    );
  }
  final text = parts.join(', ');
  return text.isEmpty
      ? 'Whole file'
      : text[0].toUpperCase() + text.substring(1);
}
