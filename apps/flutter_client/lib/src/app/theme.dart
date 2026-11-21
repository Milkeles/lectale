import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';

// Seeds are from docs/ux/token-plan.md. The plan has three hues (graphite
// neutrals, a gold accent, mulberry), which DcColorTheme.fromPalettes can't
// express, so the four schemes are written out role by role. The contrast
// test measures every pair the plan lists.

const Color _paperLight = Color(0xFFF4F1ED);
const Color _paperDark = Color(0xFF191B1A);
const Color _sandLight = Color(0xFFE8E3DC);
const Color _sandDark = Color(0xFF262927);
const Color _graphiteLight = Color(0xFF242725);
const Color _graphiteDark = Color(0xFFE9E5DE);
const Color _mutedLight = Color(0xFF5A5F5B);
const Color _mutedDark = Color(0xFFA9ADA7);
// Stronger muted text for the high-contrast schemes (7:1).
const Color _mutedLightHighContrast = Color(0xFF454A46);
const Color _mutedDarkHighContrast = Color(0xFFC8CBC5);
// Field borders must reach 3:1 against the page (WCAG 1.4.11).
const Color _controlBorder = Color(0xFF767B77);

const Color _goldLight = Color(0xFF905E0C);
const Color _goldLightHighContrast = Color(0xFF6E4708);
const Color _goldDark = Color(0xFFF3DDA4);
const Color _white = Color(0xFFFFFFFF);

const Color _signalRedLight = Color(0xFFA3292E);
const Color _signalRedDark = Color(0xFFF2958E);
// Signal red and mulberry reach 7:1 on Sand only in these deeper and lighter
// variants, so the high-contrast schemes use them.
const Color _signalRedLightHighContrast = Color(0xFF8A1D22);
const Color _signalRedDarkHighContrast = Color(0xFFF6B0AA);

const Color _mulberryLight = Color(0xFF753E5E);
const Color _mulberryDark = Color(0xFFE0A7C0);
const Color _mulberryLightHighContrast = Color(0xFF66324F);

/// The mulberry the app takes its operating-system color from (the entry in
/// the system's list of running apps). Widgets never use it: they read the
/// theme.
const Color lectaleMulberry = _mulberryLight;

/// The two roles that `DcColorScheme` has no slot for: the brand color and
/// the link color. Both are mulberry; they are separate roles so a later
/// change to one doesn't touch the other.
///
/// Read them with [LectaleColors.of]. Gold is not here: it is the theme's
/// `primary` and `ring`, and is never text.
@immutable
class LectaleColors {
  /// Creates the roles.
  const LectaleColors({required this.brand, required this.link});

  /// The logo mark and the course and lesson titles.
  final Color brand;

  /// Underlined links.
  final Color link;

  /// Mulberry on Paper.
  static const LectaleColors light = LectaleColors(
    brand: _mulberryLight,
    link: _mulberryLight,
  );

  /// Mulberry on dark Paper.
  static const LectaleColors dark = LectaleColors(
    brand: _mulberryDark,
    link: _mulberryDark,
  );

  /// Mulberry on Paper and Sand in the light high-contrast scheme, 7:1 on
  /// both. The dark mulberry already reaches it.
  static const LectaleColors lightHighContrast = LectaleColors(
    brand: _mulberryLightHighContrast,
    link: _mulberryLightHighContrast,
  );

  /// The roles for the theme above [context].
  static LectaleColors of(BuildContext context) {
    final theme = DcTheme.of(context);
    if (theme.brightness == Brightness.dark) {
      return dark;
    }
    return theme.highContrast ? lightHighContrast : light;
  }
}

DcColorScheme _scheme({
  required Color paper,
  required Color sand,
  required Color foreground,
  required Color muted,
  required Color primary,
  required Color primaryForeground,
  required Color destructive,
  required Color destructiveForeground,
  required Color border,
  required Color input,
}) => DcColorScheme(
  background: paper,
  canvas: paper,
  foreground: foreground,
  card: sand,
  cardForeground: foreground,
  popover: sand,
  popoverForeground: foreground,
  primary: primary,
  primaryForeground: primaryForeground,
  secondary: sand,
  secondaryForeground: foreground,
  muted: sand,
  mutedForeground: muted,
  accent: sand,
  accentForeground: foreground,
  destructive: destructive,
  destructiveForeground: destructiveForeground,
  border: border,
  input: input,
  // Gold, as the primary button: the focus ring and the ribbon share it.
  ring: primary,
  // Charts are unused (token plan); neutral tones keep the roles defined.
  chart1: muted,
  chart2: foreground,
  chart3: muted,
  chart4: foreground,
  chart5: muted,
);

/// Warm paper, graphite and mulberry, with one gold accent: the owner's
/// choice in `docs/ux/token-plan.md`.
final DcColorTheme lectaleColorTheme = DcColorTheme(
  name: 'Lectale',
  light: _scheme(
    paper: _paperLight,
    sand: _sandLight,
    foreground: _graphiteLight,
    muted: _mutedLight,
    primary: _goldLight,
    primaryForeground: _white,
    destructive: _signalRedLight,
    destructiveForeground: _white,
    border: _graphiteLight.withValues(alpha: 0.12),
    input: _controlBorder,
  ),
  dark: _scheme(
    paper: _paperDark,
    sand: _sandDark,
    foreground: _graphiteDark,
    muted: _mutedDark,
    primary: _goldDark,
    primaryForeground: _graphiteLight,
    destructive: _signalRedDark,
    destructiveForeground: _paperDark,
    border: _graphiteDark.withValues(alpha: 0.14),
    input: _controlBorder,
  ),
  lightHighContrast: _scheme(
    paper: _paperLight,
    sand: _sandLight,
    foreground: _graphiteLight,
    muted: _mutedLightHighContrast,
    primary: _goldLightHighContrast,
    primaryForeground: _white,
    destructive: _signalRedLightHighContrast,
    destructiveForeground: _white,
    border: _mutedLight,
    input: _mutedLight,
  ),
  darkHighContrast: _scheme(
    paper: _paperDark,
    sand: _sandDark,
    foreground: _graphiteDark,
    muted: _mutedDarkHighContrast,
    primary: _goldDark,
    primaryForeground: _graphiteLight,
    destructive: _signalRedDarkHighContrast,
    destructiveForeground: _paperDark,
    border: _mutedDark,
    input: _mutedDark,
  ),
);

/// The look of the app: comfortable touch targets (44 dp fields), the
/// warm-paper colors, no shadows and flat controls, as the token plan asks.
/// The focus ring keeps litse-ui's 2 dp width and 2 dp gap.
final DcStyle lectaleStyle = DcStyle.comfortable.copyWith(
  name: 'Lectale',
  shadows: DcShadows.none,
  depth: DcDepth.flat,
  focusRing: const DcFocusRingStyle(),
);

/// The theme for the platform's [brightness] and contrast setting.
DcThemeData lectaleTheme({
  required Brightness brightness,
  bool highContrast = false,
}) => DcThemeData(
  colorTheme: lectaleColorTheme,
  style: lectaleStyle,
  brightness: brightness,
  highContrast: highContrast,
);
