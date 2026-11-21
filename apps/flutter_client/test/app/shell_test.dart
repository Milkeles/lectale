import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/widgets/skip_link.dart';
import 'package:lectale/src/widgets/top_bar.dart';

import '../support/fake_http_adapter.dart';
import '../support/keyboard.dart';
import '../support/pump_app.dart';

const String _course = '/preview/42/$fixtureSha';

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

  setUp(() => server = FakeHttpAdapter());

  group('skip link', () {
    testSemantics('is out of sight until it has focus', (tester) async {
      await pumpLectale(tester, server);
      expect(_skipLinkRect(tester).bottom, lessThan(0));

      await expectTabOrder(tester, ['Skip to main content']);

      final rect = _skipLinkRect(tester);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.height, greaterThanOrEqualTo(24));
      expect(rect.width, greaterThanOrEqualTo(24));
    });

    for (final (name, location) in [
      ('Course', _course),
      ('Reader', '$_course/read/intro'),
    ]) {
      testSemantics('is the first stop on $name', (tester) async {
        await pumpLectale(tester, server, initialLocation: location);
        await expectTabOrder(tester, ['Skip to main content', 'Lectale home']);
      });
    }
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

      expect(locationOf(router), '/');
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

      expect(locationOf(router), '/');
    });

    for (final (name, location) in [
      ('Course', _course),
      ('Reader', '$_course/read/intro'),
    ]) {
      testSemantics('$name meets the guidelines', (tester) async {
        await pumpLectale(tester, server, initialLocation: location);
        await expectAccessible(tester);
        expect(find.text(name), findsOneWidget, reason: 'placeholder heading');
      });
    }
  });
}
