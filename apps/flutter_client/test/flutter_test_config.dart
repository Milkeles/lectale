import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the fonts of the app and its packages, such as IBM Plex and the
/// Lucide icon font, so that goldens show real text and icons instead of
/// placeholder boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that misses its widget leaves the test checking a state it never
  // reached, so a miss fails the test instead of printing a warning.
  WidgetController.hitTestWarningShouldBeFatal = true;
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final font in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(font['family'] as String);
    for (final asset
        in (font['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
  await testMain();
}
