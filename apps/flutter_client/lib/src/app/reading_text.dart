import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/app/theme.dart';

/// The family name of the reading face, declared in pubspec.yaml (ADR-0012).
const String readingFontFamily = 'Source Serif 4';

/// The reading size in dp at 100 percent text (`docs/ux/token-plan.md`).
const double readingFontSize = 18;

/// The reading line height in dp.
const double readingLineHeight = 30;

/// The language of a course or resource as a [Locale], for
/// `TextStyle.locale`. Flutter hands it to the shaper, which applies the
/// font's locale-specific forms: Bulgarian courses get Bulgarian letters and
/// other Cyrillic courses keep the standard ones (ADR-0012).
///
/// Reads a BCP 47 tag such as `bg`, `bg-BG`, `sr_Latn` or `zh-Hant-TW`, with
/// `-` or `_`. Returns null for an empty or malformed tag, so the text falls
/// back to the platform locale rather than a wrong one.
Locale? localeFromLanguageTag(String? tag) {
  final parts = (tag ?? '').trim().split(RegExp('[-_]'));
  final language = parts.first;
  if (!RegExp(r'^[A-Za-z]{2,3}$').hasMatch(language)) {
    return null;
  }
  String? script;
  String? region;
  for (final part in parts.skip(1)) {
    if (script == null &&
        region == null &&
        RegExp(r'^[A-Za-z]{4}$').hasMatch(part)) {
      script = part[0].toUpperCase() + part.substring(1).toLowerCase();
    } else if (region == null &&
        RegExp(r'^([A-Za-z]{2}|[0-9]{3})$').hasMatch(part)) {
      region = part.toUpperCase();
    } else {
      return null;
    }
  }
  return Locale.fromSubtags(
    languageCode: language.toLowerCase(),
    scriptCode: script,
    countryCode: region,
  );
}

/// The text styles of course content: reading text and the titles of courses
/// and lessons. Home has no course text, so the screens that read it come
/// with the Course and Reader tasks.
///
/// Both use Source Serif 4 with the optical-size axis set to the size drawn,
/// since Flutter doesn't set it. Weights come from the theme, so the dark
/// weight offset applies. Pass [locale] from `course.language`, or from the
/// resource's own language when it has one.
class ReadingStyles {
  /// Creates the styles for [locale].
  const ReadingStyles._({
    required this.locale,
    required this.reading,
    required this.titleColor,
    required this._titles,
  });

  /// The styles for the theme above [context].
  factory ReadingStyles.of(BuildContext context, {Locale? locale}) {
    final theme = DcTheme.of(context);
    final typography = theme.typography;
    final brand = LectaleColors.of(context).brand;

    TextStyle serif({
      required double size,
      required double lineHeight,
      required FontWeight weight,
      required Color color,
    }) => TextStyle(
      fontFamily: readingFontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontVariations: [
        FontVariation('wght', weight.value.toDouble()),
        FontVariation('opsz', size),
      ],
      color: color,
      locale: locale,
      leadingDistribution: TextLeadingDistribution.even,
    );

    // The heading map of the token plan: h1 30/36, h2 24/32, h3 21.5/30,
    // h4 19.5/28, h5 and h6 18/28.
    const sizes = <int, (double, double)>{
      1: (30, 36),
      2: (24, 32),
      3: (21.5, 30),
      4: (19.5, 28),
      5: (18, 28),
      6: (18, 28),
    };
    return ReadingStyles._(
      locale: locale,
      reading: serif(
        size: readingFontSize,
        lineHeight: readingLineHeight,
        weight: typography.regular,
        color: theme.colors.foreground,
      ),
      titleColor: brand,
      titles: {
        for (final MapEntry(key: level, value: (size, lineHeight))
            in sizes.entries)
          level: serif(
            size: size,
            lineHeight: lineHeight,
            weight: typography.semibold,
            color: brand,
          ),
      },
    );
  }

  /// The language the styles shape for; null for the platform's.
  final Locale? locale;

  /// Course text: 18 dp on 30 dp, regular, in the foreground color.
  final TextStyle reading;

  /// The color of titles: the brand mulberry.
  final Color titleColor;

  final Map<int, TextStyle> _titles;

  /// The title style of heading [level] (1 to 6): semibold mulberry, with the
  /// optical size of the size it is drawn at. Level 1 is the course or
  /// lesson title.
  TextStyle title([int level = 1]) => _titles[level.clamp(1, 6)]!;
}
