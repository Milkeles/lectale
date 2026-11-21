@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_adapter.dart';
import '../support/pump_app.dart';

/// Pictures of Home, drawn and compared on Linux only (`dart_test.yaml`).
/// Draw them again with `flutter test --update-goldens --tags golden`, then
/// look at them before committing.
void main() {
  const sizes = <(String, Size)>[
    ('360', Size(360, 800)),
    ('768', Size(768, 1024)),
    ('1440', Size(1440, 900)),
  ];

  for (final (name, size) in sizes) {
    testWidgets('idle at $name px', (tester) async {
      await pumpLectale(tester, FakeHttpAdapter(), size: size, realFonts: true);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/home_idle_$name.png'),
      );
    });

    testWidgets('invalid course.yaml at $name px', (tester) async {
      final server = FakeHttpAdapter()
        ..on(
          'POST',
          importPath,
          FakeResponse(
            422,
            apiError(
              'invalid_manifest',
              details: {
                'errors': [
                  {
                    'code': 'INVALID_REPO_PATH',
                    'path': '/outline/2/resources/0/path',
                    'message': 'Use a repository-relative path.',
                  },
                  {
                    'code': 'DUPLICATE_NODE_ID',
                    'path': '/outline/4/id',
                    'message': 'This ID is used twice.',
                  },
                ],
              },
            ),
          ),
        );
      await pumpLectale(tester, server, size: size, realFonts: true);
      await typeAddress(tester, 'github.com/ada/stats-101');
      await pressOpenCourse(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/home_invalid_manifest_$name.png'),
      );
    });
  }
}
