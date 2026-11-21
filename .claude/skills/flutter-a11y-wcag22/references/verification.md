# Verification recipes

All snippets use the litse-ui helpers described in the `devchat-ui-usage` skill (`pumpDc`, `expectAccessible`) or `pumpScreen` from the test package.

## Guideline matchers (flutter_test)

```dart
testWidgets('screen meets guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await pumpScreen(tester, const CourseScreen());
  await tester.pumpAndSettle();
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(wcagTargetSizeGuideline)); // 24 x 24, 2.5.8
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline)); // 48, touch layouts
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline)); // 44, touch layouts
  handle.dispose();
});
```

Use `expectAccessible(tester)` for the first three. The text contrast matcher reads the screenshot, so run it with the test font (litse-ui's `withTestFont`).

## Text scale and reflow

```dart
tester.platformDispatcher.textScaleFactorTestValue = 2.0; // 200%
addTearDown(tester.platformDispatcher.clearAllTestValues);
tester.view
  ..physicalSize = const Size(320, 640)
  ..devicePixelRatio = 1;
addTearDown(tester.view.reset);
await pumpScreen(tester, const CourseScreen());
expect(tester.takeException(), isNull); // no RenderFlex overflow
```

## Reduced motion

Wrap the app in `MediaQuery(data: MediaQueryData(disableAnimations: true), ...)` and assert that the end state appears without `pump(duration)`.

## Keyboard traversal

```dart
await tester.sendKeyEvent(LogicalKeyboardKey.tab);
await tester.pump();
expect(Focus.of(tester.element(find.text('Open course'))).hasFocus, isTrue);
```

Send Tab repeatedly, record the focused labels, and compare with the expected reading order. Send Escape inside a `showDcDialog` and assert focus returns to the opener.

## Semantics tree and debugger

`debugDumpSemanticsTree()` prints the tree in a test. In a running app, set `showSemanticsDebugger: true` on `WidgetsApp` to draw labels over the UI. Use `tester.getSemantics(find.byType(X))` with `isSemantics(label:, isButton:, isEnabled: ...)` for exact matches.

## Web: axe-core through Playwright

Build with `flutter build web`, serve `build/web`, then enable semantics before scanning. Chromium is preinstalled (`PLAYWRIGHT_BROWSERS_PATH`).

```js
const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const page = await (await chromium.launch()).newPage({ viewport: { width: 320, height: 640 } });
await page.goto('http://localhost:8080/');
await page.getByLabel('Enable accessibility').click({ force: true });
await page.waitForSelector('flt-semantics');
const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
console.log(results.violations);
```

Run at 320, 768 and 1440 px, in both themes. Treat axe results as leads: Flutter renders a canvas, so axe sees only the semantics tree, and a clean run is not a pass. Also check `page.keyboard.press('Tab')` order and the focus ring in a screenshot.

## Manual screen readers

| Platform | Tool | Check |
| --- | --- | --- |
| Windows | NVDA with Firefox and Chrome | landmarks, headings list, forms mode, status announcements |
| macOS, iOS | VoiceOver (Safari, native app) | rotor headings, custom actions, focus order |
| Android | TalkBack | explore by touch, 48 dp targets, largest font |
| Linux | Orca | basic reading and activation; record gaps |

PDF, notebook and video viewers need their own pass, because their accessibility is not documented by the packages (plan: pdfrx).
