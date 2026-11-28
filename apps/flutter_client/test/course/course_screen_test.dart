import 'dart:ui' show Tristate;

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/course/course_cover.dart';
import 'package:lectale/src/widgets/ribbon.dart';

import '../support/course_fixture.dart';
import '../support/fake_http_adapter.dart';
import '../support/keyboard.dart';
import '../support/pump_app.dart';

const Size _wide = Size(1440, 900);
const Size _phone = Size(360, 800);

/// The drawn formulas, found by type name so the app's tests need no direct
/// dependency on the math package.
final Finder _math = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == 'Math',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<(FakeHttpAdapter, GoRouter)> _open(
  WidgetTester tester, {
  Size size = _wide,
  bool readme = true,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  void Function(FakeHttpAdapter server)? setup,
}) async {
  final server = FakeHttpAdapter();
  serveCourse(server, readme: readme);
  setup?.call(server);
  final router = await pumpLectale(
    tester,
    server,
    size: size,
    textScale: textScale,
    brightness: brightness,
    initialLocation: fixtureCourse,
  );
  await _settle(tester);
  return (server, router);
}

void main() {
  testWidgets('opens from a link: title, summary and Start course', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('Statistics 101'), findsWidgets);
    expect(
      find.text('Probability and inference for beginners, with worked data.'),
      findsOneWidget,
    );
    expect(find.text('Start course'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('About 40 min'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('CC-BY-4.0'), findsOneWidget);
    expect(_math, findsOneWidget);
  });

  testSemantics('the overview renders the README without HTML', (tester) async {
    final (server, _) = await _open(tester);

    // Raw HTML is text, never markup (V4-SEC-03).
    expect(find.textContaining('<script>alert(1)</script>'), findsOneWidget);
    // The README's h1 renders as an h2, so the page has one h1.
    final headings = <String>[];
    void visit(SemanticsNode node) {
      if (node.headingLevel > 0) {
        headings.add('${node.headingLevel}:${node.label}');
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(
      tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    expect(headings, contains('1:Statistics 101'));
    expect(headings.where((h) => h.startsWith('1:')), hasLength(1));
    // The README's first heading repeats the course title, so it is not
    // drawn a second time (design review, Codex §2.5).
    expect(headings, isNot(contains('2:Statistics 101')));
    expect(find.text('Statistics 101'), findsOneWidget);
    expect(
      server.requests.where((r) => r.path.endsWith('/figures/histogram.png')),
      hasLength(1),
      reason: 'the repository image loads through the files route',
    );
    // The image from another host is never requested.
    expect(server.requests.every((r) => r.uri.host == 'lectale.test'), isTrue);
  });

  testWidgets('no cover: the slot collapses and the title comes first', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byType(CourseCover), findsNothing);
    // The title is the first thing under the Contents bar.
    expect(tester.getTopLeft(find.text('Statistics 101')).dy, lessThan(200));
  });

  testWidgets('a cover stands beside the title on a wide window', (
    tester,
  ) async {
    await _open(
      tester,
      setup: (server) =>
          serveCourse(server, preview: fixturePreview(cover: 'cover.png')),
    );

    expect(tester.getSize(find.byType(CourseCover)).height, 168);
    final cover = tester.getTopLeft(find.byType(CourseCover));
    final title = tester.getTopLeft(find.text('Statistics 101'));
    expect(title.dx, greaterThan(cover.dx + 112));
  });

  testWidgets('a cover that is not a raster image collapses', (tester) async {
    await _open(
      tester,
      setup: (server) =>
          serveCourse(server, preview: fixturePreview(cover: 'cover.svg')),
    );

    expect(find.byType(CourseCover), findsNothing);
  });

  testWidgets('a cover that fails to load collapses, gap included', (
    tester,
  ) async {
    await _open(
      tester,
      setup: (server) {
        serveCourse(server, preview: fixturePreview(cover: 'missing.png'));
        server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha/files/missing.png',
          FakeResponse(404, apiError('course_not_found')),
        );
      },
    );

    expect(tester.getSize(find.byType(CourseCover)), Size.zero);
  });

  testWidgets('no cover on a phone', (tester) async {
    await _open(tester, size: _phone);

    expect(find.byType(CourseCover), findsNothing);
  });

  testWidgets('on a phone Authors sits beside its value like the other '
      'facts', (tester) async {
    await _open(tester, size: _phone);

    final authors = tester.getTopLeft(find.text('Authors'));
    final names = tester.getTopLeft(find.text('Ada Lovelace'));
    expect((authors.dy - names.dy).abs(), lessThan(8));
    expect(authors.dx, tester.getTopLeft(find.text('Level')).dx);
  });

  group('Contents', () {
    testSemantics('wide: the pane is a nav with the ribbon on Overview', (
      tester,
    ) async {
      await _open(tester);

      expect(find.bySemanticsLabel('Course contents'), findsOneWidget);
      expect(find.byType(Ribbon), findsOneWidget);
      expect(find.text('Module 1: Data'), findsOneWidget);
      expect(find.text('Reading data'), findsOneWidget);
      final overview = tester.getSemantics(find.bySemanticsLabel('Overview'));
      expect(overview.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        find.bySemanticsLabel(RegExp('^Homework 1, assignment, due ')),
        findsOneWidget,
      );
    });

    testWidgets('wide: the Contents control closes and reopens the pane', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('Module 1: Data'), findsOneWidget);

      await tester.tap(find.widgetWithText(DcButton, 'Contents'));
      await tester.pump();
      expect(find.text('Module 1: Data'), findsNothing);
      // The pane is off screen, so the ribbon moves to the bar.
      expect(find.byType(Ribbon), findsOneWidget);

      await tester.tap(find.widgetWithText(DcButton, 'Contents'));
      await tester.pump();
      expect(find.text('Module 1: Data'), findsOneWidget);
    });

    testWidgets('phone: the control opens a panel that Escape closes', (
      tester,
    ) async {
      final (_, router) = await _open(tester, size: _phone);
      expect(find.text('Module 1: Data'), findsNothing);

      await tester.tap(find.widgetWithText(DcButton, 'Contents'));
      await tester.pumpAndSettle();

      expect(locationOf(router), '$fixtureCourse?contents');
      expect(find.text('Module 1: Data'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(locationOf(router), fixtureCourse);
      expect(find.text('Module 1: Data'), findsNothing);
    });

    testWidgets('phone: choosing a lesson in the panel opens it', (
      tester,
    ) async {
      final (_, router) = await _open(tester, size: _phone);
      await tester.tap(find.widgetWithText(DcButton, 'Contents'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Summaries'));
      await tester.pumpAndSettle();

      expect(locationOf(router), fixtureReader('summaries', 'script'));
    });
  });

  group('Start course', () {
    testWidgets('opens the first lesson', (tester) async {
      final (_, router) = await _open(tester);

      await tester.tap(find.widgetWithText(DcButton, 'Start course'));
      await tester.pumpAndSettle();

      expect(locationOf(router), fixtureReader('reading-data', 'notes'));
    });

    testWidgets('after a lesson was opened it reads Continue and reopens it', (
      tester,
    ) async {
      final (_, router) = await _open(tester);
      await tester.tap(find.text('Summaries'));
      await tester.pumpAndSettle();
      expect(locationOf(router), fixtureReader('summaries', 'script'));

      router.go(fixtureCourse);
      await tester.pumpAndSettle();

      expect(find.text('Continue: Summaries'), findsOneWidget);
      expect(find.text('Start course'), findsNothing);
    });

    testWidgets('is removed when the course has no lessons', (tester) async {
      await _open(
        tester,
        setup: (server) {
          final preview = fixturePreview();
          (preview['outline']! as Map<String, Object?>)['nodes'] = <Object?>[];
          (preview['outline']! as Map<String, Object?>)['assignments'] =
              <Object?>[];
          serveCourse(server, preview: preview);
        },
      );

      expect(find.text('Start course'), findsNothing);
      expect(find.text('This course has no lessons yet.'), findsOneWidget);
      expect(find.text('Open another course'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('a link that no longer opens says so and offers a way out', (
      tester,
    ) async {
      await _open(
        tester,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha',
          FakeResponse(404, apiError('course_not_found')),
        ),
      );

      expect(find.text('Course not available'), findsOneWidget);
      expect(find.text('Enter the GitHub address'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Reference 4f2a9c'), findsOneWidget);
      final button = tester.widget<DcButton>(
        find.widgetWithText(DcButton, 'Contents'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('offline offers Try again, which loads the course', (
      tester,
    ) async {
      final (server, _) = await _open(
        tester,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha',
          const FakeResponse.offline(),
        ),
      );
      expect(find.text("Lectale can't be reached"), findsOneWidget);

      serveCourse(server);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(find.text('Start course'), findsOneWidget);
    });

    testWidgets('loading shows skeletons and a disabled Contents control', (
      tester,
    ) async {
      await _open(
        tester,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha',
          FakeResponse.after(const Duration(seconds: 5), 200, fixturePreview()),
        ),
      );

      expect(find.byType(DcSkeleton), findsWidgets);
      final button = tester.widget<DcButton>(
        find.widgetWithText(DcButton, 'Contents'),
      );
      expect(button.onPressed, isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a missing README is an error inside the overview only', (
      tester,
    ) async {
      await _open(
        tester,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha/readme',
          FakeResponse(404, apiError('course_not_found')),
        ),
      );

      expect(find.text("This file isn't available"), findsOneWidget);
      expect(
        find.text("The overview can't be shown. Use Contents to start."),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Start course'), findsOneWidget);
    });

    testWidgets('a README over 512 KiB is refused while it is read', (
      tester,
    ) async {
      // A String body has no length header, so only the read can notice.
      await _open(
        tester,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha/readme',
          FakeResponse(200, 'x' * (512 * 1024 + 1)),
        ),
      );

      expect(
        find.text(
          'The overview is too large to show here. Use Contents to start.',
        ),
        findsOneWidget,
      );
      // The rest of the page is usable.
      expect(find.text('Start course'), findsOneWidget);
      expect(find.text('Module 1: Data'), findsOneWidget);
      final contents = tester.widget<DcButton>(
        find.widgetWithText(DcButton, 'Contents'),
      );
      expect(contents.onPressed, isNotNull);
    });

    testWidgets('a README that fails offers Try again', (tester) async {
      final (server, _) = await _open(
        tester,
        setup: (server) => server.on(
          'GET',
          '/api/preview/$fixtureRepoId/$fixtureSha/readme',
          FakeResponse(502, apiError('github_unavailable', retryable: true)),
        ),
      );
      expect(find.text("GitHub isn't answering"), findsOneWidget);

      serveCourse(server);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(_math, findsOneWidget);
    });

    testWidgets('no README: a notice and the outline inline on a phone', (
      tester,
    ) async {
      await _open(tester, size: _phone, readme: false);

      expect(
        find.text('This course has no overview yet. Use Contents to start.'),
        findsOneWidget,
      );
      expect(find.text('Module 1: Data'), findsOneWidget);
      expect(find.widgetWithText(DcButton, 'Contents'), findsNothing);
    });
  });

  group('keyboard', () {
    testSemantics('Tab order is the spec order', (tester) async {
      await _open(tester);

      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Overview',
        'Start course',
        'Ada Lovelace, opens in your browser',
        'the notes, opens the file in your browser',
        'an outside page, opens in your browser',
      ]);
    });

    testSemantics('Contents moves with arrows, Home and End', (tester) async {
      final (_, router) = await _open(tester);
      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Overview',
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Reading data'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Summaries'));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Homework 1'));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(focusedLabel(tester), startsWith('Overview'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(locationOf(router), fixtureReader('reading-data', 'notes'));
    });

    testSemantics('Enter on Start course opens the first lesson', (
      tester,
    ) async {
      final (_, router) = await _open(tester);

      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Overview',
        'Start course',
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(locationOf(router), fixtureReader('reading-data', 'notes'));
    });

    testSemantics('a phone goes from the Contents control to the page', (
      tester,
    ) async {
      await _open(tester, size: _phone);

      await expectTabOrder(tester, [
        'Skip to main content',
        'Lectale home',
        'Contents',
        'Start course',
      ]);
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
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        await expectAccessible(tester);
      });
    }

    testWidgets('reflows at 200 percent text without overflow', (tester) async {
      await _open(tester, size: _phone, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Start course'), findsOneWidget);
    });
  });
}
