import 'package:flutter/foundation.dart';
import 'package:lectale/src/course/import_failure.dart';

/// The outcome of reading what a learner typed.
@immutable
sealed class AddressParse {
  const AddressParse();
}

/// A repository address the server accepts.
final class AddressAccepted extends AddressParse {
  /// Creates the result.
  const AddressAccepted(this.url);

  /// Always `https://github.com/owner/repository`: the only form the API
  /// takes (`ImportCourseRequest.url`).
  final String url;
}

/// Text that can't be turned into a repository address.
final class AddressRejected extends AddressParse {
  /// Creates the result.
  const AddressRejected(this.issue);

  /// What is wrong.
  final AddressIssue issue;
}

final _scpForm = RegExp(r'^git@([^:/\s]+):(.+)$');
final _withScheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*)://(.*)$');
final _owner = RegExp(r'^[A-Za-z0-9-]+$');
final _repository = RegExp(r'^[A-Za-z0-9_.-]+$');

/// Turns what a learner typed into the canonical address, or says why not
/// (Home §8, "Address forms accepted").
///
/// Accepted: surrounding spaces; `https://` or `http://` or neither; `www.`;
/// a trailing slash; `.git`; a query or fragment; `/tree/...` and `/blob/...`
/// paths, which are cut to the repository because the preview pins the
/// default branch; and the clone forms `git@github.com:owner/repo.git` and
/// `ssh://git@github.com/owner/repo`.
AddressParse parseGitHubAddress(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return const AddressRejected(AddressIssue.empty);
  }
  if (text.contains(RegExp(r'\s'))) {
    return const AddressRejected(AddressIssue.malformed);
  }

  String rest;
  final scp = _scpForm.firstMatch(text);
  final scheme = _withScheme.firstMatch(text);
  if (scp != null) {
    rest = '${scp[1]}/${scp[2]}';
  } else if (scheme != null) {
    if (!const {
      'http',
      'https',
      'ssh',
      'git',
    }.contains(scheme[1]!.toLowerCase())) {
      return const AddressRejected(AddressIssue.malformed);
    }
    rest = scheme[2]!;
  } else {
    rest = text;
  }

  // Drop the query and fragment, then split the host from the path.
  rest = rest.split(RegExp('[?#]')).first;
  final slash = rest.indexOf('/');
  if (slash < 0) {
    return const AddressRejected(AddressIssue.malformed);
  }
  var host = rest.substring(0, slash).toLowerCase();
  final at = host.lastIndexOf('@');
  if (at >= 0) {
    host = host.substring(at + 1);
  }
  // A name without a dot, such as the `owner` of `owner/repo`, is a path.
  if (!host.contains('.')) {
    return const AddressRejected(AddressIssue.malformed);
  }
  if (host != 'github.com' && host != 'www.github.com') {
    return const AddressRejected(AddressIssue.otherHost);
  }

  final segments = rest
      .substring(slash + 1)
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length < 2) {
    return const AddressRejected(AddressIssue.malformed);
  }
  final owner = segments[0];
  var repository = segments[1];
  if (repository.endsWith('.git')) {
    repository = repository.substring(0, repository.length - 4);
  }
  if (!_owner.hasMatch(owner) ||
      !_repository.hasMatch(repository) ||
      repository == '.' ||
      repository == '..') {
    return const AddressRejected(AddressIssue.malformed);
  }
  return AddressAccepted('https://github.com/$owner/$repository');
}
