import 'package:devchat_ui/devchat_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/app.dart';
import 'package:lectale/src/app/router.dart';
import 'package:lectale/src/app/theme.dart';
import 'package:lectale/src/course/course_providers.dart';

import 'fake_http_adapter.dart';

/// A pinned commit for fixtures.
const String fixtureSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// The path of the import route, under the API root the tests use.
const String importPath = '/api/courses/import';

/// A valid `CoursePreview` body for repository [repoId].
Map<String, Object?> previewJson({int repoId = 42}) => {
  'repoId': repoId,
  'sha': fixtureSha,
  'readmePresent': true,
  'outline': {
    'course': {
      'id': 'course',
      'title': 'Statistics 101',
      'summary': 'Learn by reading.',
      'language': 'en',
      'version': '1.0.0',
    },
    'nodes': <Object?>[],
    'assignments': <Object?>[],
  },
};

/// An `ApiError` body.
Map<String, Object?> apiError(
  String code, {
  String requestId = '4f2a9c',
  bool retryable = false,
  num? retryAfterSeconds,
  Map<String, Object?>? details,
}) => {
  'code': code,
  'message': 'ignored: the client writes its own words',
  'requestId': requestId,
  'retryable': retryable,
  'retryAfterSeconds': ?retryAfterSeconds,
  'details': ?details,
};

/// [theme] with the solid blocks of Flutter's test font instead of letters.
///
/// The contrast check reads colors from a picture of the screen, and the thin
/// strokes of real letters blend with what is behind them there.
DcThemeData withTestFont(DcThemeData theme) => theme.copyWith(
  style: theme.style.copyWith(
    typography: theme.style.typography.copyWith(
      fontFamily: 'FlutterTest',
      monospaceFontFamily: 'FlutterTest',
    ),
  ),
);

DcThemeData _testTheme({
  required Brightness brightness,
  bool highContrast = false,
}) => withTestFont(
  lectaleTheme(brightness: brightness, highContrast: highContrast),
);

/// Pumps the whole app against [server], the way it runs.
///
/// The window is [size] logical pixels at a pixel ratio of 1. Text uses the
/// test font unless [realFonts] is set, which goldens need. Returns the
/// router, so tests can check where the app went.
Future<GoRouter> pumpLectale(
  WidgetTester tester,
  FakeHttpAdapter server, {
  Size size = const Size(768, 1024),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool realFonts = false,
  String initialLocation = '/',
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher
    ..platformBrightnessTestValue = brightness
    ..textScaleFactorTestValue = textScale
    ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      highContrast: highContrast,
    );
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final router = createRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  // A request that is still running is cancelled when the app goes away;
  // let that finish, so no timer outlives the test.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  final dio = Dio(BaseOptions(baseUrl: 'https://lectale.test/api'))
    ..httpClientAdapter = server;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        routerProvider.overrideWithValue(router),
      ],
      child: LectaleApp(themeFor: realFonts ? lectaleTheme : _testTheme),
    ),
  );
  await tester.pump();
  return router;
}

/// WCAG 2.2 success criterion 2.5.8: targets are at least 24 by 24 pixels.
const AccessibilityGuideline wcagTargetSizeGuideline =
    MinimumTapTargetGuideline(
      size: Size.square(24),
      link: 'https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum',
    );

/// Checks text contrast, labelled tap targets and the 24 by 24 pixel target
/// size on the current screen.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(wcagTargetSizeGuideline));
}

/// Types [text] into the address field.
Future<void> typeAddress(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump();
}

/// Presses Open course.
Future<void> pressOpenCourse(WidgetTester tester) async {
  final button = find.widgetWithText(DcButton, 'Open course');
  // At large text sizes the button sits below the fold; a person scrolls
  // to it first.
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  // Dio hands a request through several zero-length timers before it
  // reaches the adapter.
  await tester.pump(const Duration(milliseconds: 1));
}

/// The location the router is at.
String locationOf(GoRouter router) => router.state.uri.toString();

/// Like `testWidgets`, with the semantics tree switched on for the whole
/// test and released at its end, as the tester requires.
void testSemantics(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  final handle = tester.ensureSemantics();
  try {
    await body(tester);
  } finally {
    handle.dispose();
  }
});
