---
name: devchat-ui-usage
description: Build and test Lectale Flutter UI with devchat_ui (litse-ui), the widgets-only Dc* component library. Use when writing or reviewing any screen or widget, replacing Material widgets (Scaffold, ListTile, TextField, Chip, SnackBar), choosing a DcTheme, DcColorTheme or DcStyle, adding a missing component to litse-ui, or pumping a widget with the theme in a widget test (pumpDc, pumpScreen, expectAccessible).
---

# Building UI with devchat_ui

devchat_ui sits on Flutter's widgets layer. It never imports Material or Cupertino, and neither does Lectale app code. Reason: Flutter 3.50 deprecates the in-SDK Material and Cupertino libraries, and one design language (`DcTheme`) keeps every screen consistent and contrast-checked.

Import with `import 'package:devchat_ui/devchat_ui.dart';`. Plain `Text`, `Icon`, `Row`, `Column`, `ListView`, `Navigator` and the other `widgets.dart` classes are fine; `DcTheme` sets their default text style and icon theme.

## Theme entry points

- `DcTheme(data:, child:)` applies a `DcThemeData`; `DcAnimatedTheme` does the same and animates changes (instant when the platform asks for reduced motion).
- `DcThemeData({colorTheme, style, brightness, highContrast, colors, icons, button, input, card})`. `colorTheme` defaults to `DcColorTheme.devchat`; `style` to `DcStyle.standard`.
- `DcColorTheme` presets: `devchat`, `neutral`, `zinc`, `stone`, `slate`, `blue`, `violet`, `rose`, `green`, `orange`. Make one with `DcColorTheme.fromPalettes(name:, base:, accent:)`. It throws if contrast targets cannot be met, so contrast is settled at construction.
- `DcStyle` presets: `standard` (pointer), `compact`, `comfortable` (touch: 36/44/52 px controls), `sharp`, `soft`. Customise with `copyWith`, e.g. `typography: DcTypography(scale: 1.15)`.
- Read tokens with `DcTheme.of(context)`: `.colors` (`DcColorScheme` roles: `background`, `canvas`, `foreground`, `card`, `popover`, `primary`, `secondary`, `muted`, `mutedForeground`, `accent`, `destructive`, `border`, `input`, `ring`, `chart1..5`, each with a `...Foreground` pair where it has one), `.typography` (`caption`, `small`, `body`, `label`, `reading`, `subtitle`, `title`, `heading`, `display`, `code`), `.style.space(n)` (n x 4 px), `.style.radius`, `.style.controlHeights`.
- App setup: call `registerDcLicenses()` in `main`, and give `WidgetsApp.router` the delegates `DcLocalizations.delegate` and `DefaultWidgetsLocalizations.delegate`, with `supportedLocales: DcLocalizations.supportedLocales`.
- Colors come from roles, never from hex literals in widgets. A hex value belongs in a palette passed to `DcColorTheme.fromPalettes`.

## Components (constructor names are the real ones)

| Component | Key parameters |
| --- | --- |
| `DcButton({onPressed, child, variant, size, leading, trailing, loading, semanticLabel})` | variants `primary, secondary, outline, ghost, destructive, link`; sizes `small, medium, large, icon`; `onPressed: null` disables |
| `DcButton.icon({onPressed, icon, semanticLabel})` | `semanticLabel` is required, because an icon has no text |
| `DcInput({controller, placeholder, semanticLabel, leading, trailing, invalid, obscureText, autofillHints, onChanged, onSubmitted})`, `DcTextarea(...)` | single line and multi-line text |
| `DcCheckbox({value, onChanged, tristate, label, invalid})`, `DcSwitch({value, onChanged, label})` | `onChanged: null` disables the switch |
| `DcRadioGroup<T>({value, onChanged, children, direction})` with `DcRadio<T>({value, label})` | arrow-key navigation |
| `DcLabel(text, {onTap})` | label that can focus a field |
| `DcCard({title, description, action, child, footer})` | the slots are optional |
| `DcAlert({title, description, icon, variant, announce})` | `standard` or `destructive`; `announce: true` makes it a live region |
| `DcBadge({child, variant, leading})`, `DcAvatar({name, size, semanticLabel})` | `primary, secondary, destructive, outline` |
| `DcDialog({title, description, child, actions})`, `DcDialog.alert(...)`, `showDcDialog<T>(context:, builder:)` | Escape and barrier dismiss; the alert form has no close button |
| `DcTabs<T>({value, onChanged, tabs})` with `DcTab<T>({value, label, content})` | tab semantics, keyboard operable |
| `DcTooltip({message, child})`, `DcSeparator({axis})`, `DcSpinner({semanticLabel})`, `DcSkeleton({width, height})` | spinner and skeleton stop when motion is reduced |
| `DcPressable({onPressed, builder, child, semanticLabel})`, `DcFocusRing({visible, child, borderRadius})` | build a custom control; `DcPressable` gives focus, hover, press, Enter/Space |

Icons: `LucideIcons.<name>` (re-exported), shown with `Icon(LucideIcons.x)`.

## Material to devchat_ui

| Material | Use |
| --- | --- |
| `MaterialApp`, `MaterialApp.router` | `WidgetsApp` / `WidgetsApp.router` wrapped in `DcTheme` |
| `Scaffold`, `AppBar` | `ColoredBox(color: colors.canvas)` plus `Column`; **missing** app bar and sidebar |
| `ElevatedButton`, `TextButton`, `OutlinedButton`, `FilledButton` | `DcButton`: `primary` for filled, `ghost` for text, `outline` for outlined |
| `IconButton`, `FloatingActionButton` | `DcButton.icon` |
| `InkWell`, `GestureDetector` as a button | `DcPressable` (a bare `GestureDetector` is pointer-only) |
| `TextField`, `TextFormField` | `DcInput`, `DcTextarea`; form validation is app code, show errors with `invalid` plus a message |
| `Checkbox`, `Switch`, `Radio` | `DcCheckbox`, `DcSwitch`, `DcRadioGroup` and `DcRadio` |
| `Card` | `DcCard` |
| `Divider` | `DcSeparator` |
| `CircularProgressIndicator` | `DcSpinner`; **missing** determinate progress bar |
| `AlertDialog`, `showDialog` | `DcDialog.alert`, `showDcDialog` |
| `Tooltip` | `DcTooltip` |
| `TabBar`, `TabBarView` | `DcTabs` |
| `Chip` | `DcBadge` when it only displays; **missing** for selectable or deletable chips |
| `CircleAvatar` | `DcAvatar` |
| `MaterialBanner` | `DcAlert` |
| `Icons.*` | `LucideIcons.*` |
| `Theme.of(context).colorScheme` / `textTheme` | `DcTheme.of(context).colors` / `.typography` |
| `ListTile`, `SnackBar`, `DropdownButton`, `PopupMenuButton`, `Drawer`, `NavigationRail`, `BottomSheet`, `ExpansionTile`, `Slider`, `LinearProgressIndicator`, `DataTable`, `Stepper` | **missing**; build the component in litse-ui (below) |

The planned order of missing components is: progress, toast, menu/popover, select, sidebar, breadcrumb, accordion, tree, skip link, sheet, slider, table, drop zone. Check `lib/devchat_ui.dart` first, because a component may have landed since this table was written.

## When a component is missing

Add it to litse-ui; do not reach for Material and do not hand-roll a one-off in a feature package. Follow `docs/how-to/add-a-component.md` in the litse-ui repository (read the design language first). In short: build on `DcPressable`, use tokens only, show `DcFocusRing`, expose semantics, keep targets at least 24 by 24 px, then add the tests, the golden matrix, a catalog use case and a README row. Export it from `lib/devchat_ui.dart`. If the work is blocked, record the gap in `PLAN.md` and use the plain widgets-layer composition as a stopgap, marked with a TODO that names the component.

The one place Material is allowed is `packages/resource_renderers/lib/src/adapters/`, for third-party viewers (PDF, YouTube player) that need it. Bridge it to the theme with `MaterialUiCompatibilityBridge`, and never let a Material type leave the adapter. The `tool/check_rules` hook fails the build on `material.dart` imports elsewhere.

## Testing with the theme

- litse-ui's `test/helpers.dart` (use the same pattern in Lectale's test helpers): `pumpDc(tester, widget, {theme, locale, realFonts})` puts the widget in a `WidgetsApp` and `DcTheme`, centred on `colors.background`. Text uses Flutter's test font so contrast checks read solid blocks; pass `realFonts: true` for goldens.
- Feature tests: `pumpScreen(tester, screen, overrides: [...], localizationsDelegates: [...])` and `pumpRouter(tester, routes:, initialLocation:)` from `devchat_testing` (devchat-frontend) wrap in `ProviderScope`, `DcTheme` and localizations. Lectale's `packages/testing` should follow the same shape.
- Accessibility: `expectAccessible(tester)` settles animations then runs `textContrastGuideline`, `labeledTapTargetGuideline` and a 24 x 24 px `MinimumTapTargetGuideline` (WCAG 2.5.8, named `wcagTargetSizeGuideline`). Also use `isSemantics(...)` with `tester.getSemantics`, and `expectNoOffscreenLayers(tester)` to reject opacity, shader, filter and backdrop layers at rest.
- Goldens: `expectGoldenMatrix(tester, name, builder)` draws two color themes x both brightnesses x three styles in one image, tagged `golden`, drawn and compared on Linux only (`just goldens`). Look at the image before committing it.
- Riverpod only; no `provider` or BLoC in tests or code.
