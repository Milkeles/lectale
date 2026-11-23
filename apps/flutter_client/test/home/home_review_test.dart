import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/widgets/skip_link.dart';

import '../support/fake_http_adapter.dart';
import '../support/keyboard.dart';
import '../support/pump_app.dart';

/// Regression tests for the Home review fixes that the interrupted work
/// saved (`docs/ux/reviews/2026-11-21-home-build-review.md`, rows H2 and H3; H1, the ring around the field, is not reused),
/// checked here on the open-by-link screen. The web engine's choice of text
/// input element (H2) can only be seen in a browser.

const String _address = 'https://github.com/ada/stats-101';

bool _fieldHasFocus() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'repository address';

void main() {
  late FakeHttpAdapter server;

  setUp(() => server = FakeHttpAdapter());

  group('H2: the field has its name in the semantics tree', () {
    for (final enableAfterFirstFrame in [false, true]) {
      testWidgets('autofocused, semantics turned on '
          '${enableAfterFirstFrame ? 'after' : 'before'} the first frame', (
        tester,
      ) async {
        SemanticsHandle? handle;
        if (!enableAfterFirstFrame) {
          handle = tester.ensureSemantics();
        }
        await pumpLectale(tester, server, size: const Size(1440, 900));
        handle ??= tester.ensureSemantics();
        await tester.pump();

        expect(_fieldHasFocus(), isTrue);
        expect(
          tester.getSemantics(find.byType(DcInput)),
          isSemantics(
            isTextField: true,
            isFocused: true,
            label:
                'GitHub repository address\n'
                'For example, https://github.com/owner/repository',
          ),
        );
        handle.dispose();
      });
    }
  });

  group('H3: Enter keeps focus in the field', () {
    // The soft keyboards of Android and iOS keep "go", which closes the
    // keyboard on purpose; every other platform keeps focus. The override is
    // undone inside each test, before the framework checks its variables.
    void onLinux(
      String name,
      Future<void> Function(WidgetTester tester) body,
    ) => testSemantics(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    onLinux('Enter submits and the field keeps focus', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server, size: const Size(1440, 900));
      tester.testTextInput.enterText(_address);
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.unspecified);
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Reading the repository'), findsOneWidget);
      expect(_fieldHasFocus(), isTrue);
      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'the text input connection stays open, so typing still works',
      );
    });

    onLinux('Escape then cancels the request', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server, size: const Size(1440, 900));
      tester.testTextInput.enterText(_address);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.unspecified);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Reading the repository'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Reading the repository'), findsNothing);
    });

    onLinux('Tab continues from the field to Open course', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server, size: const Size(1440, 900));
      tester.testTextInput.enterText(_address);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.unspecified);
      await tester.pump(const Duration(milliseconds: 1));

      await expectTabOrder(tester, ['Open course']);
    });

    onLinux('Escape cancels from the skip link too', (tester) async {
      server.on('POST', importPath, const FakeResponse.hangs());
      await pumpLectale(tester, server, size: const Size(1440, 900));
      tester.testTextInput.enterText(_address);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.unspecified);
      await tester.pump(const Duration(milliseconds: 1));
      await expectTabOrder(tester, ['Skip to main content'], backwards: true);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<SkipLink>(),
        isNotNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Reading the repository'), findsNothing);
    });
  });
}
