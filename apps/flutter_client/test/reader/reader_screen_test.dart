import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/widgets/ribbon.dart';

import '../support/course_fixture.dart';
import '../support/fake_http_adapter.dart';
import '../support/keyboard.dart';
import '../support/pump_app.dart';

const Size _wide = Size(1440, 900);
const Size _phone = Size(360, 800);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<(FakeHttpAdapter, GoRouter)> _open(
  WidgetTester tester,
  String location, {
  Size size = _wide,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool realFonts = false,
  void Function(FakeHttpAdapter server)? setup,
}) async {
  final server = FakeHttpAdapter();
  serveCourse(server);
  setup?.call(server);
  final router = await pumpLectale(
    tester,
    server,
    size: size,
    textScale: textScale,
    brightness: brightness,
    realFonts: realFonts,
    initialLocation: location,
  );
  await _settle(tester);
  return (server, router);
}

final String _notes = fixtureReader('reading-data', 'notes');
final String _survey = fixtureReader('reading-data', 'survey');
final String _script = fixtureReader('summaries', 'script');
final String _slides = fixtureReader('testing', 'slides');
final String _brief = fixtureReader('assignment~homework-1', 'brief');

void main() {
  group('a lesson with two files', () {
    testSemantics('shows module, title, description, files and the file', (
      tester,
    ) async {
      await _open(tester, _notes);

      expect(find.text('Module 1: Data'), findsWidgets);
      expect(find.text('How to load a CSV file.'), findsOneWidget);
      expect(find.bySemanticsLabel('In this lesson'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Survey results, Text, 12 KB'),
        findsOneWidget,
      );
      // The viewer: Markdown, with its table-less text and a code block.
      expect(find.textContaining('A table has rows'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Code, python')), findsOneWidget);
    });

    testSemantics('headings: one h1, the file name as h2, Markdown below', (
      tester,
    ) async {
      await _open(tester, _notes);

      final headings = <String>[];
      for (final element in find.byType(Semantics).evaluate()) {
        final level = (element.widget as Semantics).properties.headingLevel;
        if (level == null) {
          continue;
        }
        final text = find
            .descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => e.widget as Text)
            .map((t) => (t.textSpan ?? TextSpan(text: t.data)).toPlainText())
            .first;
        headings.add('$level:$text');
      }
      expect(headings, contains('1:Reading data'));
      expect(headings, contains('2:Data and its shape'));
      // The file's own "# Notes" moves down two levels, to h3.
      expect(headings, contains('3:Notes'));
    });

    testSemantics('the Download bar names the file, its kind and size', (
      tester,
    ) async {
      final (server, _) = await _open(tester, _survey);

      expect(find.text('survey.csv'), findsOneWidget);
      expect(find.text('Text, 12 KB'), findsWidgets);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Download')).hint,
        'survey.csv',
      );
      expect(find.textContaining('Ada,10'), findsOneWidget);
      expect(
        server.requests.where(
          (r) => r.path.endsWith('/content/reading-data/survey'),
        ),
        hasLength(1),
      );
    });

    testWidgets('choosing a file replaces the history entry', (tester) async {
      final (_, router) = await _open(tester, _notes);

      await tester.tap(find.text('Survey results').first);
      await _settle(tester);

      expect(locationOf(router), _survey);
      expect(find.textContaining('Ada,10'), findsOneWidget);
    });
  });

  group('Previous and Next', () {
    testWidgets('the first step has Next file and no Previous', (tester) async {
      await _open(tester, _notes);

      expect(find.text('Next file: Survey results'), findsOneWidget);
      expect(find.textContaining('Previous'), findsNothing);
    });

    testWidgets('across a lesson they name the lesson', (tester) async {
      await _open(tester, _survey);

      expect(find.text('Previous file: Data and its shape'), findsOneWidget);
      expect(find.text('Next lesson: Summaries'), findsOneWidget);
    });

    testWidgets('across modules to an assignment', (tester) async {
      await _open(tester, _slides);

      expect(find.text('Previous lesson: Summaries'), findsOneWidget);
      expect(find.text('Next assignment: Homework 1'), findsOneWidget);
    });

    testWidgets('Next to a new lesson pushes an entry and Back returns', (
      tester,
    ) async {
      final (_, router) = await _open(tester, _survey);

      await tester.tap(find.text('Next lesson: Summaries'));
      await _settle(tester);

      expect(locationOf(router), _script);
      expect(find.text('Summaries'), findsWidgets);
      router.pop();
      await _settle(tester);
      expect(locationOf(router), _survey);
    });

    testWidgets('Next to a new lesson moves focus to its title', (
      tester,
    ) async {
      await _open(tester, _survey);

      await tester.tap(find.text('Next lesson: Summaries'));
      await _settle(tester);

      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.focusNode == focus,
          ),
          matching: find.text('Summaries'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Next to the next file moves focus to its heading', (
      tester,
    ) async {
      final (_, router) = await _open(tester, _notes);

      await tester.tap(find.text('Next file: Survey results'));
      await _settle(tester);

      expect(locationOf(router), _survey);
      final focus = FocusManager.instance.primaryFocus;
      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.focusNode == focus,
          ),
          matching: find.text('Survey results'),
        ),
        findsWidgets,
      );
    });

    testWidgets('the last step ends calmly with Back to course', (
      tester,
    ) async {
      final (_, router) = await _open(tester, _brief);

      expect(
        find.text("You've reached the end of this course."),
        findsOneWidget,
      );
      expect(find.text('Next file: Brief'), findsNothing);
      await tester.ensureVisible(find.text('Back to course'));
      await tester.tap(find.text('Back to course'));
      await _settle(tester);

      expect(locationOf(router), fixtureCourse);
      // The ribbon is on this lesson now: the course remembers it.
      expect(find.text('Continue: Homework 1'), findsOneWidget);
    });

    testWidgets('stack with Next first when the labels do not fit', (
      tester,
    ) async {
      await _open(tester, _survey, size: _phone);

      final next = tester.getTopLeft(find.text('Next lesson: Summaries')).dy;
      final previous = tester
          .getTopLeft(find.text('Previous file: Data and its shape'))
          .dy;
      expect(next, lessThan(previous));
    });

    testWidgets('side by side on a wide window, Previous first', (
      tester,
    ) async {
      // Real fonts: the test font is as wide as it is tall.
      await _open(tester, _slides, realFonts: true);

      final next = tester.getTopLeft(find.text('Next assignment: Homework 1'));
      final previous = tester.getTopLeft(
        find.text('Previous lesson: Summaries'),
      );
      expect((previous.dy - next.dy).abs(), lessThan(6));
      expect(previous.dx, lessThan(next.dx));
    });
  });

  group('kinds', () {
    testSemantics('a code file has line numbers, a language and Copy', (
      tester,
    ) async {
      await _open(tester, _script);

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('1\n2'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Code, Python')), findsOneWidget);
    });

    testWidgets('a PDF shows the download card', (tester) async {
      await _open(tester, _slides);

      expect(find.text('testing.pdf'), findsOneWidget);
      expect(find.text('PDF, 2.3 MB'), findsWidgets);
      expect(
        find.text("Lectale can't show PDF files in this version."),
        findsOneWidget,
      );
      // A browser shows a PDF itself, so the button says what it does.
      expect(find.text('Download PDF'), findsOneWidget);
    });

    testWidgets('an assignment shows its dates and the note', (tester) async {
      await _open(tester, _brief);

      expect(find.textContaining('Due 4 Dec 2026'), findsWidgets);
      expect(
        find.textContaining("Submitting work isn't available in Lectale yet."),
        findsOneWidget,
      );
      expect(find.text('Summarise the survey.'), findsWidgets);
    });
  });

  group('states', () {
    testWidgets('a lesson that is not in the course says so', (tester) async {
      await _open(tester, fixtureReader('nope', 'nothing'));

      expect(find.text("This lesson isn't in this course."), findsOneWidget);
      expect(find.text('Open Overview'), findsOneWidget);
    });

    testWidgets('a missing file fails inside the viewer only', (tester) async {
      await _open(
        tester,
        _survey,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha/content/reading-data/survey',
          FakeResponse(404, apiError('course_not_found')),
        ),
      );

      expect(find.text("This file isn't available"), findsOneWidget);
      expect(find.text('Enter the GitHub address'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      // Navigation stays.
      expect(find.text('Next lesson: Summaries'), findsOneWidget);
      expect(find.widgetWithText(DcButton, 'Contents'), findsOneWidget);
    });

    testWidgets('a failure that can pass offers Try again', (tester) async {
      final (server, _) = await _open(
        tester,
        _survey,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha/content/reading-data/survey',
          FakeResponse(502, apiError('github_unavailable', retryable: true)),
        ),
      );
      expect(find.text("GitHub isn't answering"), findsOneWidget);

      serveCourse(server);
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(find.textContaining('Ada,10'), findsOneWidget);
    });

    testWidgets('a course that no longer opens shows the course error', (
      tester,
    ) async {
      await _open(
        tester,
        _notes,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha',
          FakeResponse(404, apiError('course_not_found')),
        ),
      );

      expect(find.text('Course not available'), findsOneWidget);
    });

    testWidgets('loading shows skeletons first', (tester) async {
      await _open(
        tester,
        _notes,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha',
          FakeResponse.after(const Duration(seconds: 5), 200, fixturePreview()),
        ),
      );

      expect(find.byType(DcSkeleton), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Contents', () {
    testSemantics('the ribbon and the current row mark the open lesson', (
      tester,
    ) async {
      await _open(tester, _script);

      expect(find.byType(Ribbon), findsOneWidget);
      expect(
        find.bySemanticsLabel('Summaries, lesson, current'),
        findsOneWidget,
      );
      final row = tester.getSemantics(
        find.bySemanticsLabel('Summaries, lesson, current'),
      );
      expect(row.flagsCollection.isSelected, isNotNull);
    });

    testSemantics('on a phone the place shows beside the control', (
      tester,
    ) async {
      await _open(tester, _script, size: _phone);

      expect(find.byType(Ribbon), findsOneWidget);
      expect(find.text('Summaries'), findsWidgets);
      expect(find.text('Module 1: Data'), findsOneWidget);
    });

    testSemantics('arrows, Home and End move; Enter opens a lesson', (
      tester,
    ) async {
      final (_, router) = await _open(tester, _script);
      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Summaries',
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Reading data'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Overview'));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Homework 1'));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Overview'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(locationOf(router), _slides);
    });

    testWidgets('Overview in the pane opens Course', (tester) async {
      final (_, router) = await _open(tester, _script);

      await tester.tap(find.text('Overview'));
      await _settle(tester);

      expect(locationOf(router), fixtureCourse);
    });
  });

  group('keyboard', () {
    testSemantics('Tab order follows the spec from top to Next', (
      tester,
    ) async {
      await _open(tester, _notes);

      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Reading data',
        'Data and its shape',
        'Download',
        'Code, python',
        'Next file: Survey results',
      ]);
    });

    testSemantics('Enter on Next opens the next file', (tester) async {
      final (_, router) = await _open(tester, _notes);

      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Reading data',
        'Data and its shape',
        'Download',
        'Code, python',
        'Next file: Survey results',
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(locationOf(router), _survey);
    });

    testSemantics('In this lesson is one stop; arrows choose a file', (
      tester,
    ) async {
      final (_, router) = await _open(tester, _notes);
      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Reading data',
        'Data and its shape',
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Survey results'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(locationOf(router), _survey);
    });
  });

  group('focus is not hidden behind the sticky bar (WCAG 2.4.11)', () {
    testSemantics('Tab to each control keeps it below the Contents bar', (
      tester,
    ) async {
      await _open(tester, _notes, size: const Size(360, 420));
      final bar = tester.getRect(find.widgetWithText(DcButton, 'Contents'));

      final visited = <String>[];
      for (var i = 0; i < 7; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump();
        final label = focusedLabel(tester) ?? '';
        // The skip link, the top bar and the Contents control are the chrome.
        if (label.startsWith('Skip') ||
            label.startsWith('Lectale home') ||
            label == 'Contents') {
          continue;
        }
        visited.add(label);
        final focused = FocusManager.instance.primaryFocus!;
        final rect = focused.rect;
        expect(
          rect.top,
          greaterThanOrEqualTo(bar.bottom - 0.5),
          reason: '"$label" must not sit under the Contents bar',
        );
      }
      expect(visited.any((l) => l.startsWith('Next file')), isTrue);
    });
  });

  group('design review', () {
    testWidgets('the pane and the text column are one centred group, 72 dp '
        'apart', (tester) async {
      await _open(tester, _script);

      // Group: 272 pane + 72 gap + 576 text = 920 dp in a 1440 window.
      final pane = tester.getTopLeft(find.text('Overview')).dx;
      expect(pane, greaterThanOrEqualTo(260));
      final module = find.text('Module 1: Data');
      final column = module
          .evaluate()
          .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dx)
          .reduce((a, b) => a > b ? a : b);
      expect(column, closeTo(260 + 272 + 72, 1));
    });

    testWidgets('the Contents control shows a chevron, and the ribbon leads '
        'it once the pane is closed', (tester) async {
      await _open(tester, _script);
      final control = find.widgetWithText(DcButton, 'Contents');
      expect(
        find.descendant(of: control, matching: find.byType(Icon)),
        findsOneWidget,
      );

      await tester.tap(control);
      await tester.pump();

      final ribbon = tester.getRect(find.byType(Ribbon));
      expect(ribbon.right, lessThanOrEqualTo(tester.getRect(control).left));
    });

    testWidgets('a file row takes a hover fill under the pointer', (
      tester,
    ) async {
      await _open(tester, _notes);
      final row = find.text('Survey results');
      Color? fill() => tester
          .widgetList<DecoratedBox>(
            find.ancestor(of: row, matching: find.byType(DecoratedBox)),
          )
          .map((box) => (box.decoration as BoxDecoration).color)
          .firstWhere((color) => color != null, orElse: () => null);
      expect(fill(), isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(row));
      await tester.pump();

      expect(fill(), isNotNull);
    });

    testWidgets('file kind and size sit at the far edge of the row when '
        'there is room', (tester) async {
      await _open(tester, _notes);

      final title = tester.getTopLeft(find.text('Survey results'));
      final meta = tester.getTopLeft(find.text('Text, 12 KB').first);
      expect(meta.dy, closeTo(title.dy, 6));
      expect(meta.dx, greaterThan(title.dx + 200));
    });

    testWidgets('the PDF card is compact, with the action beside the file', (
      tester,
    ) async {
      await _open(tester, _slides);

      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('testing.pdf'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(card.height, lessThan(130));
      final action = tester.getRect(
        find.widgetWithText(DcButton, 'Download PDF'),
      );
      expect(action.left, greaterThan(card.center.dx));
    });

    testWidgets('the language and Copy share a header on the code surface', (
      tester,
    ) async {
      await _open(tester, _script);

      final surface = tester.getRect(
        find
            .ancestor(
              of: find.text('Python'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final copy = tester.getRect(find.widgetWithText(DcButton, 'Copy'));
      expect(surface.contains(copy.center), isTrue);
      expect(surface.contains(tester.getCenter(find.text('Python'))), isTrue);
    });

    testWidgets('the file bar leads with the name and ends with Download', (
      tester,
    ) async {
      await _open(tester, _survey);

      final name = tester.getTopLeft(find.text('survey.csv'));
      final download = tester.getRect(
        find.widgetWithText(DcButton, 'Download'),
      );
      expect(name.dx, lessThan(download.left));
      expect(download.right, greaterThan(1000));
    });

    testWidgets('the footer keeps natural widths when the labels stack', (
      tester,
    ) async {
      await _open(tester, _script);

      final next = tester.getRect(
        find.widgetWithText(DcButton, 'Next lesson: Testing ideas'),
      );
      expect(next.width, lessThan(576));
    });

    testWidgets('metadata is 14 on 20', (tester) async {
      await _open(tester, _notes);

      // The module line is the one in the text column, right of the pane.
      final module = tester
          .widgetList<Text>(find.text('Module 1: Data'))
          .firstWhere((text) => text.style!.fontSize == 14);
      expect(module.style!.fontSize, 14);
      expect(module.style!.height, closeTo(20 / 14, 0.001));
    });
  });

  group('design re-review', () {
    Future<bool> sideBySide(
      WidgetTester tester,
      String location,
      Brightness brightness,
      String previous,
      String next,
    ) async {
      await _open(tester, location, realFonts: true, brightness: brightness);
      final a = tester.getTopLeft(find.text(previous)).dy;
      final b = tester.getTopLeft(find.text(next)).dy;
      return (a - b).abs() < 8;
    }

    for (final (name, location, previous, next) in [
      (
        'testing to the assignment',
        _slides,
        'Previous lesson: Summaries',
        'Next assignment: Homework 1',
      ),
      (
        'the code lesson',
        _script,
        'Previous lesson: Reading data',
        'Next lesson: Testing ideas',
      ),
      (
        'the second file',
        _survey,
        'Previous file: Data and its shape',
        'Next lesson: Summaries',
      ),
    ]) {
      testWidgets('light and dark pick the same footer layout: $name', (
        tester,
      ) async {
        // The footer is measured from the real buttons, so the dark theme's
        // lighter weights can't tip it into another layout.
        final light = await sideBySide(
          tester,
          location,
          Brightness.light,
          previous,
          next,
        );
        await tester.pumpWidget(const SizedBox());
        final dark = await sideBySide(
          tester,
          location,
          Brightness.dark,
          previous,
          next,
        );

        expect(dark, light);
      });
    }

    testWidgets('both labels sit side by side in a 576 dp column when they '
        'fit', (tester) async {
      await _open(tester, _slides, realFonts: true);

      final previous = tester.getRect(
        find.widgetWithText(DcButton, 'Previous lesson: Summaries'),
      );
      final next = tester.getRect(
        find.widgetWithText(DcButton, 'Next assignment: Homework 1'),
      );
      expect(previous.center.dy, closeTo(next.center.dy, 1));
      expect(next.left - previous.right, greaterThanOrEqualTo(18));
      expect(next.right - previous.left, lessThanOrEqualTo(576));
    });

    testWidgets('a lone Next is full width on a phone', (tester) async {
      await _open(tester, _notes, size: _phone);

      final next = tester.getRect(
        find.widgetWithText(DcButton, 'Next file: Survey results'),
      );
      expect(next.width, closeTo(360 - 2 * 18, 1));
    });

    testWidgets('the end note is reading text, 18 on 30', (tester) async {
      await _open(tester, _brief);

      final note = tester.widget<Text>(
        find.text("You've reached the end of this course."),
      );
      expect(note.style!.fontSize, 18);
      expect(note.style!.height, closeTo(30 / 18, 0.001));
    });

    testWidgets('the file card fills the column on a phone', (tester) async {
      await _open(tester, _slides, size: _phone);

      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('testing.pdf'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(card.width, closeTo(360 - 2 * 18, 1));
    });

    testWidgets('code gets a visible scrollbar cue', (tester) async {
      await _open(tester, _script, size: _phone);

      expect(find.byType(RawScrollbar), findsWidgets);
    });
  });

  group('accessibility', () {
    for (final (name, size, scale, brightness) in [
      ('1440 light', _wide, 1.0, Brightness.light),
      ('1440 dark', _wide, 1.0, Brightness.dark),
      ('360 light', _phone, 1.0, Brightness.light),
      ('360 dark', _phone, 1.0, Brightness.dark),
      ('360 at 200 percent text', _phone, 2.0, Brightness.light),
    ]) {
      testSemantics('meets the guidelines: $name', (tester) async {
        await _open(
          tester,
          _notes,
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        await expectAccessible(tester);
      });
    }

    testWidgets('reflows at 200 percent text without overflow', (tester) async {
      await _open(tester, _survey, size: _phone, textScale: 2);

      final problem = tester.takeException();
      expect(problem, isNull);
      expect(find.text('Next lesson: Summaries'), findsOneWidget);
    });
  });
}
