import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/widgets/skip_link.dart';

import '../support/fake_http_adapter.dart';
import '../support/keyboard.dart';
import '../support/pump_app.dart';

const String _address = 'https://github.com/ada/stats-101';

bool _enabled(WidgetTester tester) =>
    tester
        .widget<DcButton>(find.widgetWithText(DcButton, 'Open course'))
        .onPressed !=
    null;

/// Two halves of one text, kept apart so a list of texts reads one per entry.
String _join(String first, String second) => '$first$second';

/// Submits the address and waits for the answer.
Future<void> _submitAndSettle(WidgetTester tester) async {
  await typeAddress(tester, _address);
  await pressOpenCourse(tester);
  await tester.pumpAndSettle();
}

/// Names what has keyboard focus, in words a test can compare.
String _focused() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null || focus is FocusScopeNode) {
    return 'nothing';
  }
  if (context.findAncestorWidgetOfExactType<SkipLink>() != null) {
    return 'skip link';
  }
  if (context.findAncestorWidgetOfExactType<DcButton>() != null) {
    return 'open course';
  }
  return focus!.debugLabel ?? 'unknown';
}

void main() {
  late FakeHttpAdapter server;

  setUp(() {
    server = FakeHttpAdapter()
      // An opened course loads its README.
      ..on(
        'GET',
        '/api/preview/42/$fixtureSha/readme',
        const FakeResponse(200, '# Statistics 101'),
      );
  });

  group('idle', () {
    testSemantics('shows the heading, help, label, hint and button', (
      tester,
    ) async {
      await pumpLectale(tester, server);

      expect(find.text('Open a course from GitHub'), findsOneWidget);
      expect(
        find.text(
          'Any public GitHub repository with a course.yaml file. '
          'No account needed; Lectale only reads it.',
        ),
        findsOneWidget,
      );
      expect(find.text('GitHub repository address'), findsOneWidget);
      expect(
        find.text('For example, https://github.com/owner/repository'),
        findsOneWidget,
      );
      expect(find.widgetWithText(DcButton, 'Open course'), findsOneWidget);
      expect(_enabled(tester), isTrue);
      expect(find.byType(DcAlert), findsNothing);
      expect(server.requests, isEmpty);
    });

    testSemantics('the top bar is plain text, not a link', (tester) async {
      await pumpLectale(tester, server);

      expect(find.text('Lectale'), findsOneWidget);
      expect(find.bySemanticsLabel('Lectale home'), findsNothing);
    });

    testSemantics('focuses the field at the wide threshold only', (
      tester,
    ) async {
      await pumpLectale(tester, server, size: const Size(1440, 900));
      expect(_focused(), 'repository address');
    });

    testSemantics('leaves focus alone below the wide threshold', (
      tester,
    ) async {
      await pumpLectale(tester, server);
      expect(_focused(), 'nothing');
    });
  });

  group('keyboard', () {
    testSemantics('order is skip link, address field, Open course', (
      tester,
    ) async {
      await pumpLectale(tester, server);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(), 'skip link');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(), 'repository address');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(), 'open course');
    });

    testSemantics('the skip link moves focus to the main content', (
      tester,
    ) async {
      await pumpLectale(tester, server);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_focused(), 'main content');

      // The next stop after the jump is the page's first control.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(), 'repository address');
    });

    testSemantics('keyboard alone opens a course', (tester) async {
      server.on('POST', importPath, FakeResponse(200, previewJson()));
      final router = await pumpLectale(tester, server);

      await expectTabOrder(tester, [
        'Skip to main content',
        'GitHub repository address',
      ]);
      tester.testTextInput.enterText(_address);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/preview/42/$fixtureSha');
      expect(server.bodiesOf('POST', '/courses/import'), [
        {'url': _address},
      ]);
    });

    testSemantics('Enter on Open course opens the course', (tester) async {
      server.on('POST', importPath, FakeResponse(200, previewJson()));
      final router = await pumpLectale(tester, server);
      await typeAddress(tester, _address);

      await expectTabOrder(tester, ['Open course']);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/preview/42/$fixtureSha');
    });

    testSemantics('Shift+Tab walks the same order backwards', (tester) async {
      await pumpLectale(tester, server);

      await expectTabOrder(tester, [
        'Skip to main content',
        'GitHub repository address',
        'Open course',
      ]);
      await expectTabOrder(tester, [
        'GitHub repository address',
        'Skip to main content',
      ], backwards: true);
    });

    testSemantics('Enter in the field opens the course', (tester) async {
      server.on('POST', importPath, FakeResponse(200, previewJson()));
      await pumpLectale(tester, server);

      await typeAddress(tester, _address);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
    });
  });

  group('loading', () {
    testSemantics('shows progress and keeps the field and button usable', (
      tester,
    ) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);

      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      expect(find.text('Reading the repository'), findsOneWidget);
      expect(find.byType(DcSpinner), findsOneWidget);
      expect(find.widgetWithText(DcButton, 'Open course'), findsOneWidget);
      expect(_enabled(tester), isTrue);
      expect(
        tester.widget<DcInput>(find.byType(DcInput)).enabled,
        isTrue,
        reason: 'the field stays editable',
      );
    });

    testSemantics('says so after 8 seconds', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Reading the repository'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Still reading. Large courses take longer.'),
        findsOneWidget,
      );
    });

    testSemantics('editing the address cancels the request', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      await typeAddress(tester, '$_address-2');
      await tester.pump();

      expect(find.text('Reading the repository'), findsNothing);
      expect(server.cancelled, 1);
      expect(_enabled(tester), isTrue);
    });

    testSemantics('Escape cancels the request', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Reading the repository'), findsNothing);
      expect(server.cancelled, 1);
    });

    testSemantics('pressing Open course again restarts with the new text', (
      tester,
    ) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      await pressOpenCourse(tester);

      expect(server.requests, hasLength(2));
      expect(server.cancelled, 1);
      expect(find.text('Reading the repository'), findsOneWidget);
    });

    testSemantics('gives up after 30 seconds', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Lectale is taking too long'), findsOneWidget);
      expect(
        find.text("The request didn't finish. Try again in a moment."),
        findsOneWidget,
      );
      expect(find.textContaining('Reference'), findsNothing);
      expect(_enabled(tester), isTrue);
      expect(server.cancelled, 1, reason: 'the stuck request is stopped');
    });
  });

  group('field errors', () {
    testSemantics('an empty field asks for an address, with no request', (
      tester,
    ) async {
      await pumpLectale(tester, server);

      await pressOpenCourse(tester);

      expect(
        find.text('Enter the address of a GitHub repository.'),
        findsOneWidget,
      );
      expect(tester.widget<DcInput>(find.byType(DcInput)).invalid, isTrue);
      expect(find.byType(DcAlert), findsNothing);
      expect(server.requests, isEmpty);
    });

    testSemantics('text that is not an address names the form', (tester) async {
      await pumpLectale(tester, server);

      await typeAddress(tester, 'stats 101');
      await pressOpenCourse(tester);

      expect(
        find.text(
          "That doesn't look like a GitHub repository address. "
          'Use the form https://github.com/owner/repository.',
        ),
        findsOneWidget,
      );
      expect(server.requests, isEmpty);
    });

    testSemantics('another host says Lectale opens github.com', (tester) async {
      await pumpLectale(tester, server);

      await typeAddress(tester, 'https://gitlab.com/ada/stats-101');
      await pressOpenCourse(tester);

      expect(
        find.text(
          'Lectale opens repositories on github.com. '
          'Use the form https://github.com/owner/repository.',
        ),
        findsOneWidget,
      );
      expect(server.requests, isEmpty);
    });

    testSemantics('a server 400 invalid_url shows on the field', (
      tester,
    ) async {
      server.on('POST', importPath, FakeResponse(400, apiError('invalid_url')));
      await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      expect(find.textContaining("That doesn't look like"), findsOneWidget);
      expect(find.byType(DcAlert), findsNothing);
    });

    testSemantics('focus goes to the field after any error', (tester) async {
      await pumpLectale(tester, server);

      await pressOpenCourse(tester);

      expect(_focused(), 'repository address');
    });

    testSemantics('the address is sent in the one form the server accepts', (
      tester,
    ) async {
      server.on('POST', importPath, const FakeResponse(200));
      await pumpLectale(tester, server);

      await typeAddress(tester, '  git@github.com:ada/stats-101.git  ');
      await pressOpenCourse(tester);
      await tester.pump();

      expect(server.bodiesOf('POST', '/courses/import'), [
        {'url': _address},
      ]);
    });
  });

  group('alerts', () {
    // Each row of the J5 error table, as Home words it.
    final cases = <String, ({FakeResponse response, List<String> texts})>{
      'not found or private': (
        response: FakeResponse(404, apiError('course_not_found')),
        texts: [
          'Repository not available',
          _join(
            "Lectale can't open this repository. Check the address. ",
            "A private repository can't be opened here.",
          ),
          'Reference 4f2a9c',
        ],
      ),
      'no course.yaml': (
        response: FakeResponse(422, apiError('manifest_missing')),
        texts: [
          "course.yaml can't be used",
          _join(
            'This repository has no course.yaml at its top level. ',
            'The course author needs to add one.',
          ),
          'Reference 4f2a9c',
        ],
      ),
      'course.yaml too large': (
        response: FakeResponse(413, apiError('manifest_too_large')),
        texts: [
          "course.yaml can't be used",
          _join(
            'course.yaml is larger than Lectale can read. ',
            'The course author needs to shorten it.',
          ),
          'Reference 4f2a9c',
        ],
      ),
      'GitHub not answering': (
        response: FakeResponse(502, apiError('github_unavailable')),
        texts: [
          "GitHub isn't answering",
          _join(
            "Lectale couldn't get this course from GitHub. ",
            'Try again in a moment.',
          ),
          'Reference 4f2a9c',
        ],
      ),
      'repository not confirmed': (
        response: FakeResponse(503, apiError('repository_changed')),
        texts: ["GitHub isn't answering", 'Reference 4f2a9c'],
      ),
      'offline': (
        response: const FakeResponse.offline(),
        texts: [
          "Lectale can't be reached",
          'Check your internet connection, then try again.',
        ],
      ),
      'anything else': (
        response: FakeResponse(500, apiError('boom', retryable: true)),
        texts: [
          'Lectale ran into a problem',
          _join(
            'Try again in a moment. ',
            'If it keeps happening, quote the reference.',
          ),
          'Reference 4f2a9c',
        ],
      ),
    };

    for (final MapEntry(key: name, value: expected) in cases.entries) {
      testSemantics('$name: copy, reference and a usable button', (
        tester,
      ) async {
        server.on('POST', importPath, expected.response);
        await pumpLectale(tester, server);

        await _submitAndSettle(tester);

        for (final text in expected.texts) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.byType(DcAlert), findsOneWidget);
        expect(_enabled(tester), isTrue);
        expect(_focused(), 'repository address');
        if (!expected.texts.any((text) => text.startsWith('Reference'))) {
          expect(find.textContaining('Reference'), findsNothing);
        }
      });
    }

    testSemantics('an answer without an error body is "ran into a problem"', (
      tester,
    ) async {
      server.on(
        'POST',
        importPath,
        const FakeResponse(502, '<html>Bad</html>'),
      );
      await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      expect(find.text('Lectale ran into a problem'), findsOneWidget);
      expect(find.textContaining('Reference'), findsNothing);
      expect(_enabled(tester), isTrue, reason: 'a 502 may pass');
    });

    testSemantics(
      'a failure that retrying cannot fix disables the button until '
      'the address changes',
      (tester) async {
        server.on('POST', importPath, FakeResponse(400, apiError('boom')));
        await pumpLectale(tester, server);

        await _submitAndSettle(tester);
        expect(find.text('Lectale ran into a problem'), findsOneWidget);
        expect(_enabled(tester), isFalse);

        await typeAddress(tester, '$_address-2');
        expect(_enabled(tester), isTrue);
      },
    );

    testSemantics('invalid course.yaml lists each problem with its location', (
      tester,
    ) async {
      server.on(
        'POST',
        importPath,
        FakeResponse(
          422,
          apiError(
            'invalid_manifest',
            details: {
              'errors': [
                {
                  'code': 'INVALID_REPO_PATH',
                  'path': '/outline/2/resources/0/path',
                  'message': 'Use a repository-relative path.',
                },
                {
                  'code': 'YAML_INVALID',
                  'path': '',
                  'message': 'The file is not valid YAML.',
                },
              ],
              'truncated': true,
            },
          ),
        ),
      );
      await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      expect(find.text("course.yaml can't be used"), findsOneWidget);
      expect(
        find.text(
          "This repository's course.yaml has 2 problems. "
          'The course author needs to fix them before it can open.',
        ),
        findsOneWidget,
      );
      expect(find.text('Use a repository-relative path.'), findsOneWidget);
      expect(find.text('Outline item 3, resource 1, path'), findsOneWidget);
      expect(
        find.textContaining('/outline/2/resources/0/path'),
        findsOneWidget,
      );
      expect(find.text('The file is not valid YAML.'), findsOneWidget);
      expect(find.text('Whole file'), findsOneWidget);
      expect(find.text('Showing the first 50 problems.'), findsOneWidget);
      expect(find.text('Reference 4f2a9c'), findsOneWidget);
    });

    testSemantics('a single problem uses the singular', (tester) async {
      server.on(
        'POST',
        importPath,
        FakeResponse(
          422,
          apiError(
            'invalid_manifest',
            details: {
              'errors': [
                {'code': 'SCHEMA_INVALID', 'path': '/title', 'message': 'Bad.'},
              ],
            },
          ),
        ),
      );
      await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      expect(
        find.text(
          "This repository's course.yaml has 1 problem. "
          'The course author needs to fix it before it can open.',
        ),
        findsOneWidget,
      );
      expect(find.text('Showing the first 50 problems.'), findsNothing);
    });
  });

  group('rate limit', () {
    testSemantics('says the wait in seconds and blocks Open course until it '
        'ends', (tester) async {
      server.on(
        'POST',
        importPath,
        FakeResponse(
          429,
          apiError('rate_limited', retryable: true, retryAfterSeconds: 40),
        ),
      );
      await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      expect(find.text('Too many requests'), findsOneWidget);
      expect(find.text('Try again in 40 seconds.'), findsOneWidget);
      expect(_enabled(tester), isFalse);

      // Editing the address does not lift a limit that is not about it.
      await typeAddress(tester, '$_address-2');
      expect(_enabled(tester), isFalse);

      await tester.pump(const Duration(seconds: 41));
      expect(_enabled(tester), isTrue);
    });

    testSemantics('announces when the wait ends', (tester) async {
      server.on(
        'POST',
        importPath,
        FakeResponse(429, apiError('rate_limited', retryAfterSeconds: 5)),
      );
      await pumpLectale(tester, server);
      await _submitAndSettle(tester);
      expect(find.bySemanticsLabel('You can try again.'), findsNothing);

      await tester.pump(const Duration(seconds: 6));

      expect(find.bySemanticsLabel('You can try again.'), findsOneWidget);
    });

    for (final (seconds, text) in <(num?, String)>[
      (null, 'Try again in a minute.'),
      (1, 'Try again in 1 second.'),
      (59, 'Try again in 59 seconds.'),
      (60, 'Try again in a minute.'),
      (61, 'Try again in 2 minutes.'),
      (300, 'Try again in 5 minutes.'),
    ]) {
      testSemantics('words a wait of $seconds s as "$text"', (tester) async {
        server.on(
          'POST',
          importPath,
          FakeResponse(
            429,
            apiError('rate_limited', retryAfterSeconds: seconds),
          ),
        );
        await pumpLectale(tester, server);

        await _submitAndSettle(tester);

        expect(find.text(text), findsOneWidget);
      });
    }
  });

  group('success', () {
    testSemantics('opens the course at /preview/{repoId}/{sha}', (
      tester,
    ) async {
      server.on('POST', importPath, FakeResponse(200, previewJson()));
      final router = await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      expect(locationOf(router), '/preview/42/$fixtureSha');
      // The course opens from the import result in memory: no second request
      // for the preview, only the README of the overview.
      expect(find.text('Statistics 101'), findsWidgets);
      expect(
        server.requests.where(
          (r) => r.method == 'GET' && r.path == '/api/preview/42/$fixtureSha',
        ),
        isEmpty,
      );
      expect(find.text('Open a course from GitHub'), findsNothing);
    });
  });

  group('semantics', () {
    testSemantics('landmarks, heading, field and button', (tester) async {
      await pumpLectale(tester, server);

      expect(
        tester.getSemantics(find.text('Open a course from GitHub')),
        isSemantics(label: 'Open a course from GitHub', isHeader: true),
      );
      expect(
        tester.getSemantics(find.byType(DcInput)),
        isSemantics(
          isTextField: true,
          label:
              'GitHub repository address\n'
              'For example, https://github.com/owner/repository',
        ),
      );
      expect(
        tester.getSemantics(find.widgetWithText(DcButton, 'Open course')),
        isSemantics(
          label: 'Open course',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(SkipLink),
            matching: find.byType(DcPressable),
          ),
        ),
        isSemantics(
          label: 'Skip to main content',
          isLink: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
    });

    testSemantics('the field carries its error as its description', (
      tester,
    ) async {
      await pumpLectale(tester, server);

      await pressOpenCourse(tester);

      expect(
        tester.getSemantics(find.byType(DcInput)),
        isSemantics(
          isTextField: true,
          label:
              'GitHub repository address\n'
              'For example, https://github.com/owner/repository\n'
              'Enter the address of a GitHub repository.',
        ),
      );
    });

    testSemantics('an alert is not live; its summary is, in a separate node', (
      tester,
    ) async {
      server.on(
        'POST',
        importPath,
        FakeResponse(
          422,
          apiError(
            'invalid_manifest',
            details: {
              'errors': [
                for (var i = 0; i < 3; i++)
                  {'code': 'SCHEMA_INVALID', 'path': '/a/$i', 'message': 'No.'},
              ],
            },
          ),
        ),
      );
      await pumpLectale(tester, server);

      await _submitAndSettle(tester);

      final summary = find.bySemanticsLabel(
        "course.yaml can't be used. 3 problems.",
      );
      expect(summary, findsOneWidget);
      expect(
        tester.getSemantics(summary),
        isSemantics(
          label: "course.yaml can't be used. 3 problems.",
          isLiveRegion: true,
        ),
      );
      expect(
        tester.getSemantics(find.byType(DcAlert)).flagsCollection.isLiveRegion,
        isFalse,
      );
    });

    testSemantics('progress is a polite live region', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server);
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);

      expect(
        tester.getSemantics(find.text('Reading the repository')),
        isSemantics(label: 'Reading the repository', isLiveRegion: true),
      );
    });
  });

  group('accessibility guidelines', () {
    for (final (name, size) in <(String, Size)>[
      ('360', const Size(360, 800)),
      ('768', const Size(768, 1024)),
      ('1440', const Size(1440, 900)),
    ]) {
      for (final brightness in Brightness.values) {
        testSemantics('idle at $name px, ${brightness.name}', (tester) async {
          await pumpLectale(tester, server, size: size, brightness: brightness);
          await expectAccessible(tester);
        });

        testSemantics('a field error at $name px, ${brightness.name}', (
          tester,
        ) async {
          await pumpLectale(tester, server, size: size, brightness: brightness);
          await pressOpenCourse(tester);
          await tester.pumpAndSettle();
          await expectAccessible(tester);
        });

        testSemantics(
          'an alert with problems at $name px, ${brightness.name}',
          (tester) async {
            server.on(
              'POST',
              importPath,
              FakeResponse(
                422,
                apiError(
                  'invalid_manifest',
                  details: {
                    'errors': [
                      {
                        'code': 'INVALID_REPO_PATH',
                        'path': '/outline/2/resources/0/path',
                        'message': 'Use a repository-relative path.',
                      },
                    ],
                  },
                ),
              ),
            );
            await pumpLectale(
              tester,
              server,
              size: size,
              brightness: brightness,
            );
            await _submitAndSettle(tester);
            await expectAccessible(tester);
          },
        );
      }
    }

    testSemantics('idle in high contrast', (tester) async {
      await pumpLectale(tester, server, highContrast: true);
      await expectAccessible(tester);
    });

    testSemantics('loading', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server, size: const Size(360, 800));
      await typeAddress(tester, _address);
      await pressOpenCourse(tester);
      // The spinner never settles, so check without waiting for it.
      await expectAccessible(tester);
    });
  });

  group('layout', () {
    testSemantics('reflows at 200 percent text on a phone', (tester) async {
      server.on(
        'POST',
        importPath,
        FakeResponse(404, apiError('course_not_found')),
      );
      await pumpLectale(
        tester,
        server,
        size: const Size(360, 800),
        textScale: 2,
      );
      await _submitAndSettle(tester);

      expect(tester.takeException(), isNull);
      // The alert is on screen, so the reflow is checked with it.
      expect(find.text('Repository not available'), findsOneWidget);
      // No horizontal scrolling: everything is inside the 360 px window.
      final button = tester.getRect(
        find.widgetWithText(DcButton, 'Open course'),
      );
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(360));
    });

    testSemantics('the button is full width on a phone', (tester) async {
      await pumpLectale(tester, server, size: const Size(360, 800));

      final button = tester.getRect(
        find.widgetWithText(DcButton, 'Open course'),
      );
      final field = tester.getRect(find.byType(DcInput));
      expect(button.width, field.width);
    });

    testSemantics('the field and button share a row on a tablet', (
      tester,
    ) async {
      await pumpLectale(tester, server);

      final button = tester.getRect(
        find.widgetWithText(DcButton, 'Open course'),
      );
      final field = tester.getRect(find.byType(DcInput));
      expect(button.top, field.top);
      expect(field.right, lessThan(button.left));
      expect(button.height, greaterThanOrEqualTo(44));
      expect(field.height, greaterThanOrEqualTo(44));
    });

    testSemantics('the column is 560 dp on the start line at 1440 px', (
      tester,
    ) async {
      await pumpLectale(tester, server, size: const Size(1440, 900));

      final heading = tester.getRect(find.text('Open a course from GitHub'));
      final brand = tester.getRect(find.text('Lectale'));
      expect(heading.left, 36, reason: 'the 36 dp gutter');
      final row = tester.getRect(find.byType(DcInput)).right;
      final button = tester.getRect(
        find.widgetWithText(DcButton, 'Open course'),
      );
      expect(button.right - heading.left, lessThanOrEqualTo(560));
      expect(row, lessThan(button.left));
      expect(
        brand.left,
        greaterThan(heading.left),
        reason: 'the mark comes first',
      );
    });
  });
}
