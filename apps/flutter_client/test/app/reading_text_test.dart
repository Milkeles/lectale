import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/app/reading_text.dart';
import 'package:lectale/src/app/theme.dart';

const String _sentence = 'Всяка добра лекция';

Widget _themed(Brightness brightness, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: DcTheme(
    data: lectaleTheme(brightness: brightness),
    child: child,
  ),
);

/// The styles of a theme, read the way a screen reads them.
Future<ReadingStyles> _stylesIn(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Locale? locale,
}) async {
  late ReadingStyles styles;
  await tester.pumpWidget(
    _themed(
      brightness,
      Builder(
        builder: (context) {
          styles = ReadingStyles.of(context, locale: locale);
          return const SizedBox();
        },
      ),
    ),
  );
  return styles;
}

void main() {
  group('localeFromLanguageTag', () {
    test('reads language, script and region', () {
      expect(localeFromLanguageTag('bg'), const Locale('bg'));
      expect(localeFromLanguageTag('bg-BG'), const Locale('bg', 'BG'));
      expect(localeFromLanguageTag('bg_bg'), const Locale('bg', 'BG'));
      expect(
        localeFromLanguageTag('sr-latn-rs'),
        const Locale.fromSubtags(
          languageCode: 'sr',
          scriptCode: 'Latn',
          countryCode: 'RS',
        ),
      );
      expect(
        localeFromLanguageTag(' zh-Hant-TW '),
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(localeFromLanguageTag('es-419'), const Locale('es', '419'));
    });

    test('gives null for anything that is not a language tag', () {
      for (final tag in [
        null,
        '',
        '  ',
        'b',
        'bulgarian',
        '12',
        'bg-',
        'bg-x-y',
      ]) {
        expect(localeFromLanguageTag(tag), isNull, reason: '"$tag"');
      }
    });
  });

  group('reading text', () {
    testWidgets('is Source Serif 4 at 18 on 30, regular, optical size 18', (
      tester,
    ) async {
      final style = (await _stylesIn(tester)).reading;

      expect(style.fontFamily, 'Source Serif 4');
      expect(style.fontSize, 18);
      expect(style.height! * style.fontSize!, closeTo(30, 1e-9));
      expect(style.fontWeight, FontWeight.w400);
      expect(
        style.fontVariations,
        containsAll(const [
          FontVariation('opsz', 18),
          FontVariation('wght', 400),
        ]),
      );
      expect(style.color, lectaleColorTheme.light.foreground);
    });

    testWidgets('takes the lighter dark-mode weight from the theme', (
      tester,
    ) async {
      final style = (await _stylesIn(
        tester,
        brightness: Brightness.dark,
      )).reading;

      expect(style.fontWeight, const FontWeight(350));
      expect(style.fontVariations, contains(const FontVariation('wght', 350)));
    });

    testWidgets('carries the language of the course', (tester) async {
      final styles = await _stylesIn(tester, locale: const Locale('bg'));

      expect(styles.reading.locale, const Locale('bg'));
      expect(styles.title().locale, const Locale('bg'));
    });
  });

  group('titles', () {
    testWidgets('are semibold mulberry with the optical size they are drawn '
        'at', (tester) async {
      final styles = await _stylesIn(tester);
      const sizes = {1: 30.0, 2: 24.0, 3: 21.5, 4: 19.5, 5: 18.0, 6: 18.0};

      for (final MapEntry(key: level, value: size) in sizes.entries) {
        final style = styles.title(level);
        expect(style.fontFamily, 'Source Serif 4');
        expect(style.fontSize, size);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, LectaleColors.light.brand);
        expect(
          style.fontVariations,
          containsAll([
            FontVariation('opsz', size),
            const FontVariation('wght', 600),
          ]),
        );
      }
    });

    testWidgets('are never smaller than reading text or larger than h1', (
      tester,
    ) async {
      final styles = await _stylesIn(tester);
      for (var level = 1; level <= 6; level++) {
        expect(
          styles.title(level).fontSize,
          inInclusiveRange(18, styles.title().fontSize!),
        );
      }
    });

    testWidgets('use the dark mulberry on dark paper', (tester) async {
      final styles = await _stylesIn(tester, brightness: Brightness.dark);
      expect(styles.title().color, LectaleColors.dark.brand);
    });
  });

  group('Bulgarian letter forms (ADR-0012)', () {
    // Draws the sentence at the reading size and returns its pixels.
    Future<List<int>> pixels(WidgetTester tester, Locale locale) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _themed(
          Brightness.light,
          Align(
            alignment: Alignment.topLeft,
            // A fixed box, so a difference in the bytes is a difference in
            // the drawn letters and not in the size of the picture.
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 40,
                child: Builder(
                  builder: (context) => Text(
                    _sentence,
                    style: ReadingStyles.of(context, locale: locale).reading,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        return data!.buffer.asUint8List();
      });
      return bytes!;
    }

    Future<double> width(WidgetTester tester, Locale locale) async {
      late double result;
      await tester.pumpWidget(
        _themed(
          Brightness.light,
          Builder(
            builder: (context) {
              final painter = TextPainter(
                text: TextSpan(
                  text: _sentence,
                  style: ReadingStyles.of(context, locale: locale).reading,
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              result = painter.width;
              painter.dispose();
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('bg and ru draw the same sentence with different letters', (
      tester,
    ) async {
      final bulgarian = await pixels(tester, const Locale('bg'));
      final russian = await pixels(tester, const Locale('ru'));
      final russianAgain = await pixels(tester, const Locale('ru'));

      expect(
        russianAgain,
        russian,
        reason: 'drawing is repeatable, so a difference below is the locale',
      );
      expect(bulgarian.length, russian.length);
      expect(bulgarian, isNot(russian));
    });

    testWidgets('bg and ru also set the sentence at different widths', (
      tester,
    ) async {
      // The Bulgarian forms (locl) change the advances, not only the shapes.
      final bg = await width(tester, const Locale('bg'));
      final ru = await width(tester, const Locale('ru'));
      expect(bg, isNot(ru));
    });
  });
}
