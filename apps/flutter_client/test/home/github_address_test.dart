import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/home/github_address.dart';

const String _canonical = 'https://github.com/ada/stats-101';

void main() {
  group('accepted forms (Home §8)', () {
    for (final input in <String>[
      _canonical,
      '  $_canonical  ',
      'http://github.com/ada/stats-101',
      'github.com/ada/stats-101',
      'www.github.com/ada/stats-101',
      'https://www.github.com/ada/stats-101',
      'HTTPS://GitHub.com/ada/stats-101',
      '$_canonical/',
      '$_canonical.git',
      '$_canonical?tab=readme-ov-file',
      '$_canonical#readme',
      '$_canonical/tree/main/lessons',
      '$_canonical/blob/main/course.yaml',
      '$_canonical/issues',
      'git@github.com:ada/stats-101.git',
      'ssh://git@github.com/ada/stats-101',
      'ssh://git@github.com/ada/stats-101.git',
    ]) {
      test('"$input"', () {
        expect(
          parseGitHubAddress(input),
          isA<AddressAccepted>().having((a) => a.url, 'url', _canonical),
        );
      });
    }

    test('keeps dots, underscores and capitals in the repository name', () {
      expect(
        parseGitHubAddress('github.com/Ada-L/stats_101.v2'),
        isA<AddressAccepted>().having(
          (a) => a.url,
          'url',
          'https://github.com/Ada-L/stats_101.v2',
        ),
      );
    });
  });

  group('rejected', () {
    void rejects(String input, AddressIssue issue) => test(
      '"$input" is $issue',
      () => expect(
        parseGitHubAddress(input),
        isA<AddressRejected>().having((r) => r.issue, 'issue', issue),
      ),
    );

    rejects('', AddressIssue.empty);
    rejects('   ', AddressIssue.empty);
    rejects('stats 101', AddressIssue.malformed);
    rejects('ada/stats-101', AddressIssue.malformed);
    rejects('stats-101', AddressIssue.malformed);
    rejects('https://github.com', AddressIssue.malformed);
    rejects('https://github.com/ada', AddressIssue.malformed);
    rejects('https://github.com/ada/..', AddressIssue.malformed);
    rejects('https://github.com/ada/.', AddressIssue.malformed);
    rejects('https://github.com/ada/stats%20101', AddressIssue.malformed);
    rejects('https://github.com/a_b/stats', AddressIssue.malformed);
    rejects('ftp://github.com/ada/stats-101', AddressIssue.malformed);
    rejects('https://gitlab.com/ada/stats-101', AddressIssue.otherHost);
    rejects('gitlab.com/ada/stats-101', AddressIssue.otherHost);
    rejects(
      'https://github.com.example.com/ada/stats-101',
      AddressIssue.otherHost,
    );
    rejects('git@gitlab.com:ada/stats-101.git', AddressIssue.otherHost);
  });
}
