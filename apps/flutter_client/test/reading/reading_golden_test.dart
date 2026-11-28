@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/course_fixture.dart';
import '../support/fake_http_adapter.dart';
import '../support/pump_app.dart';

/// Pictures of Course and Reader at 360, 768 and 1440 px, drawn and compared
/// on Linux only (`dart_test.yaml`). Draw them again with
/// `flutter test --update-goldens --tags golden`, then look at them before
/// committing.
void main() {
  const sizes = <(String, Size)>[
    ('360', Size(360, 800)),
    ('768', Size(768, 1024)),
    ('1440', Size(1440, 900)),
  ];

  Future<void> draw(
    WidgetTester tester,
    String location,
    Size size,
    String golden, {
    Brightness brightness = Brightness.light,
  }) async {
    final server = FakeHttpAdapter();
    serveCourse(server);
    await pumpLectale(
      tester,
      server,
      size: size,
      realFonts: true,
      brightness: brightness,
      initialLocation: location,
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/$golden.png'),
    );
  }

  for (final (name, size) in sizes) {
    testWidgets('Course at $name px', (tester) async {
      await draw(tester, fixtureCourse, size, 'course_$name');
    });

    testWidgets('Reader at $name px', (tester) async {
      await draw(
        tester,
        fixtureReader('reading-data', 'notes'),
        size,
        'reader_$name',
      );
    });
  }

  testWidgets('Course at 1440 px, dark', (tester) async {
    await draw(
      tester,
      fixtureCourse,
      sizes.last.$2,
      'course_1440_dark',
      brightness: Brightness.dark,
    );
  });

  testWidgets('Reader at 1440 px, dark', (tester) async {
    await draw(
      tester,
      fixtureReader('reading-data', 'notes'),
      sizes.last.$2,
      'reader_1440_dark',
      brightness: Brightness.dark,
    );
  });

  // Dark mode once lost bold, table-header weight and the italic of math
  // variables (the variable font's weight axis was pinned at regular). The
  // golden shows all three in one picture.
  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('Markdown emphasis, table header and math, $name', (
      tester,
    ) async {
      final server = FakeHttpAdapter();
      serveCourse(
        server,
        readmeText:
            'Plain text, then **bold text**, then *italic text*, and a '
            r'formula $x^2 + \bar{x} = \frac{1}{n}\sum x_i$ inline.'
            '\n\n'
            '| Measure | Symbol |\n|---|---|\n| Mean | cell text |\n',
      );
      await pumpLectale(
        tester,
        server,
        size: const Size(800, 640),
        realFonts: true,
        brightness: brightness,
        initialLocation: fixtureCourse,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/markdown_emphasis_$name.png'),
      );
    });
  }
}
