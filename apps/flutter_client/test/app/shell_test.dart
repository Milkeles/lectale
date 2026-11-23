import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/app/theme.dart';
import 'package:lectale/src/widgets/skip_link.dart';
import 'package:lectale/src/widgets/top_bar.dart';

import '../support/course_fixture.dart';
import '../support/fake_http_adapter.dart';
import '../support/keyboard.dart';
import '../support/pump_app.dart';

const String _course = fixtureCourse;
final String _reader = fixtureReader('reading-data', 'notes');

/// Where the skip link is drawn. Its layout box stays in place and the visible
/// part moves, so measure the part inside.
Rect _skipLinkRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(SkipLink),
    matching: find.byType(DcFocusRing),
  ),
);

void main() {
  late FakeHttpAdapter server;

  setUp(() {
    server = FakeHttpAdapter();
    serveCourse(server);
  });

  group('skip link', () {
    testSemantics('is out of sight until it has focus', (tester) async {
      await pumpLectale(tester, server);
      expect(_skipLinkRect(tester).bottom, lessThan(0));

      await expectTabOrder(tester, ['Skip to main content']);

      final rect = _skipLinkRect(tester);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.height, greaterThanOrEqualTo(24));
      expect(rect.width, greaterThanOrEqualTo(24));
    });

    for (final (name, location) in [('Course', _course), ('Reader', _reader)]) {
      testSemantics('is the first stop on $name', (tester) async {
        await pumpLectale(tester, server, initialLocation: location);
        await expectTabOrder(tester, ['Skip to main content', 'Lectale home']);
      });
    }
  });

  group('skip link ring', () {
    testSemantics('fits inside the window, ring and gap included', (
      tester,
    ) async {
      await pumpLectale(tester, server);
      await expectTabOrder(tester, ['Skip to main content']);
      await tester.pump(const Duration(seconds: 1));

      final ring = lectaleStyle.focusRing;
      expect(
        _skipLinkRect(tester).top,
        greaterThanOrEqualTo(ring.offset + ring.width),
        reason: 'the ring is drawn offset + width above the link',
      );
    });

    testSemantics('also on Course, which has its own frame', (tester) async {
      await pumpLectale(tester, server, initialLocation: _course);
      await expectTabOrder(tester, ['Skip to main content']);
      await tester.pump(const Duration(seconds: 1));

      final ring = lectaleStyle.focusRing;
      expect(
        _skipLinkRect(tester).top,
        greaterThanOrEqualTo(ring.offset + ring.width),
      );
    });
  });

  group('routes', () {
    for (final bad in [
      '/preview/abc/$fixtureSha',
      '/preview/42/xyz',
      '/preview/0/$fixtureSha',
      '/preview/-1/$fixtureSha',
      '/preview/42/${fixtureSha.toUpperCase()}',
      '/preview/42/${fixtureSha.substring(1)}',
      '/preview/9007199254740993/$fixtureSha',
      '/preview/42.5/$fixtureSha',
    ]) {
      testWidgets('a bad deep link $bad redirects to /open', (tester) async {
        final router = await pumpLectale(tester, server, initialLocation: bad);
        await tester.pumpAndSettle();

        expect(locationOf(router), '/open');
        expect(find.text('Open a course from GitHub'), findsOneWidget);
        expect(server.requests, isEmpty, reason: 'no request for a bad link');
      });
    }

    testWidgets('a bad link inside a lesson address redirects too', (
      tester,
    ) async {
      final router = await pumpLectale(
        tester,
        server,
        initialLocation: '/preview/abc/xyz/lesson/item',
      );
      await tester.pumpAndSettle();

      expect(locationOf(router), '/open');
    });

    testWidgets('/ redirects to the open-by-link screen', (tester) async {
      final router = await pumpLectale(tester, server);

      expect(locationOf(router), '/open');
      expect(find.text('Open a course from GitHub'), findsOneWidget);
    });
  });

  group('top bar', () {
    testSemantics('is a link named "Lectale home" on Course', (tester) async {
      await pumpLectale(tester, server, initialLocation: _course);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Lectale home')),
        isSemantics(
          label: 'Lectale home',
          isLink: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
    });

    testSemantics('the link opens Home by pointer', (tester) async {
      final router = await pumpLectale(
        tester,
        server,
        initialLocation: _course,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(TopBar),
          matching: find.byType(DcPressable),
        ),
      );
      await tester.pumpAndSettle();

      expect(locationOf(router), '/open');
      expect(find.text('Open a course from GitHub'), findsOneWidget);
    });

    testSemantics('the link opens Home by keyboard', (tester) async {
      final router = await pumpLectale(
        tester,
        server,
        initialLocation: _course,
      );

      await expectTabOrder(tester, ['Skip to main content', 'Lectale home']);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/open');
    });

    for (final (name, location) in [('Course', _course), ('Reader', _reader)]) {
      testSemantics('$name meets the guidelines', (tester) async {
        await pumpLectale(tester, server, initialLocation: location);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        await expectAccessible(tester);
      });
    }
  });
}
