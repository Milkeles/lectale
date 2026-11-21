import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/app/theme.dart';

/// The pairs of `docs/ux/token-plan.md`, "Colour", measured on the schemes the
/// app builds, not on the seeds.
void main() {
  const variants = <(String, Brightness, bool)>[
    ('light', Brightness.light, false),
    ('dark', Brightness.dark, false),
    ('light high contrast', Brightness.light, true),
    ('dark high contrast', Brightness.dark, true),
  ];

  for (final (name, brightness, highContrast) in variants) {
    group(name, () {
      final colors = lectaleColorTheme.resolve(
        brightness,
        highContrast: highContrast,
      );
      final roles = brightness == Brightness.dark
          ? LectaleColors.dark
          : highContrast
          ? LectaleColors.lightHighContrast
          : LectaleColors.light;
      // Text needs 4.5:1, or 7:1 when the platform asks for more contrast.
      final text = highContrast ? 7.0 : 4.5;
      double ratio(Color a, Color b) => DcContrast.ratio(a, b);

      test('text on Paper and on Sand reaches $text:1', () {
        for (final surface in [colors.canvas, colors.background, colors.card]) {
          expect(ratio(colors.foreground, surface), greaterThanOrEqualTo(text));
          expect(
            ratio(colors.mutedForeground, surface),
            greaterThanOrEqualTo(text),
          );
        }
        expect(
          ratio(colors.mutedForeground, colors.muted),
          greaterThanOrEqualTo(text),
        );
      });

      test('mulberry links and titles reach $text:1 on Paper and Sand', () {
        for (final role in [roles.brand, roles.link]) {
          expect(ratio(role, colors.canvas), greaterThanOrEqualTo(text));
          expect(ratio(role, colors.card), greaterThanOrEqualTo(text));
        }
      });

      test('the button label reaches $text:1 on gold', () {
        expect(
          ratio(colors.primaryForeground, colors.primary),
          greaterThanOrEqualTo(text),
        );
      });

      test('signal red reaches $text:1 as text and behind its label', () {
        expect(
          ratio(colors.destructive, colors.canvas),
          greaterThanOrEqualTo(text),
        );
        expect(
          ratio(colors.destructive, colors.card),
          greaterThanOrEqualTo(text),
        );
        expect(
          ratio(colors.destructiveForeground, colors.destructive),
          greaterThanOrEqualTo(text),
        );
      });

      test('the focus ring and the ribbon reach 3:1 on Paper and Sand', () {
        // The ribbon is drawn in the primary color, as is the ring.
        expect(colors.ring, colors.primary);
        expect(ratio(colors.ring, colors.canvas), greaterThanOrEqualTo(3));
        expect(ratio(colors.ring, colors.card), greaterThanOrEqualTo(3));
      });

      test('field borders reach 3:1 on Paper', () {
        expect(ratio(colors.input, colors.canvas), greaterThanOrEqualTo(3));
      });

      test('Paper is one color for canvas and background', () {
        expect(colors.canvas, colors.background);
      });
    });
  }

  group('the plan table, to the measured digit', () {
    final light = lectaleColorTheme.light;
    final dark = lectaleColorTheme.dark;
    final lightHighContrast = lectaleColorTheme.lightHighContrast;
    const roles = (light: LectaleColors.light, dark: LectaleColors.dark);
    Matcher near(double value) => closeTo(value, 0.02);
    double ratio(Color a, Color b) => DcContrast.ratio(a, b);

    test('graphite on Paper and on Sand', () {
      expect(ratio(light.foreground, light.canvas), near(13.40));
      expect(ratio(dark.foreground, dark.canvas), near(13.79));
      expect(ratio(light.foreground, light.card), near(11.82));
      expect(ratio(dark.foreground, dark.card), near(11.71));
    });

    test('muted text', () {
      expect(ratio(light.mutedForeground, light.canvas), near(5.79));
      expect(ratio(light.mutedForeground, light.card), near(5.11));
      expect(ratio(dark.mutedForeground, dark.canvas), near(7.60));
    });

    test('mulberry', () {
      expect(ratio(roles.light.link, light.canvas), near(7.15));
      expect(ratio(roles.light.link, light.card), near(6.31));
      expect(ratio(roles.dark.link, dark.canvas), near(8.62));
      expect(ratio(roles.dark.link, dark.card), near(7.32));
    });

    test('button label on gold', () {
      expect(ratio(light.primaryForeground, light.primary), near(5.54));
      expect(
        ratio(lightHighContrast.primaryForeground, lightHighContrast.primary),
        near(8.18),
      );
      expect(ratio(dark.primaryForeground, dark.primary), near(11.27));
    });

    test('gold on Paper and on Sand', () {
      expect(ratio(light.ring, light.canvas), near(4.92));
      expect(ratio(dark.ring, dark.canvas), near(12.93));
      expect(ratio(light.ring, light.card), near(4.34));
      expect(ratio(dark.ring, dark.card), near(10.98));
    });

    test('signal red on Paper and on Sand', () {
      expect(ratio(light.destructive, light.canvas), near(6.40));
      expect(ratio(light.destructive, light.card), near(5.65));
      expect(ratio(dark.destructive, dark.canvas), near(7.80));
    });
  });

  test('gold is never a text role', () {
    for (final scheme in [
      lectaleColorTheme.light,
      lectaleColorTheme.dark,
      lectaleColorTheme.lightHighContrast,
      lectaleColorTheme.darkHighContrast,
    ]) {
      expect(scheme.foreground, isNot(scheme.primary));
      expect(scheme.mutedForeground, isNot(scheme.primary));
    }
    expect(LectaleColors.light.link, isNot(lectaleColorTheme.light.primary));
    expect(LectaleColors.dark.brand, isNot(lectaleColorTheme.dark.primary));
  });

  testWidgets('LectaleColors follows the theme above it', (tester) async {
    LectaleColors? seen;
    Widget probe(Brightness brightness, {bool highContrast = false}) => DcTheme(
      data: lectaleTheme(brightness: brightness, highContrast: highContrast),
      child: Builder(
        builder: (context) {
          seen = LectaleColors.of(context);
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(probe(Brightness.light));
    expect(seen, LectaleColors.light);
    await tester.pumpWidget(probe(Brightness.dark));
    expect(seen, LectaleColors.dark);
    await tester.pumpWidget(probe(Brightness.light, highContrast: true));
    expect(seen, LectaleColors.lightHighContrast);
  });
}
