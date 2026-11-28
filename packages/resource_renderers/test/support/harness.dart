import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// WCAG 2.2 success criterion 2.5.8: targets are at least 24 by 24 pixels.
const AccessibilityGuideline wcagTargetSizeGuideline =
    MinimumTapTargetGuideline(
      size: Size.square(24),
      link: 'https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum',
    );

/// Checks text contrast, labelled tap targets and the 24 by 24 pixel target
/// size on the current screen.
Future<void> expectAccessible(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(wcagTargetSizeGuideline));
}

/// The text styles of content in tests: the test font, the theme's colors.
class TestStyles implements ContentStyles {
  /// Creates the styles for the theme above [context].
  TestStyles(BuildContext context) : _theme = DcTheme.of(context);

  final DcThemeData _theme;

  @override
  Locale? get locale => null;

  @override
  Color get link => _theme.colors.foreground;

  @override
  TextStyle get reading => TextStyle(
    fontFamily: 'FlutterTest',
    fontSize: 18,
    height: 30 / 18,
    color: _theme.colors.foreground,
    // Pinned like the app's reading style, so the dark theme's regular
    // weight (350) sits on the font's axis and a bare fontWeight can't win.
    fontVariations: [
      FontVariation('wght', _theme.typography.regular.value.toDouble()),
    ],
  );

  @override
  TextStyle title(int level) => TextStyle(
    fontFamily: 'FlutterTest',
    fontSize: 30 - (level - 1) * 2,
    color: _theme.colors.foreground,
    fontWeight: FontWeight.w600,
  );
}

/// A host over files held in memory. Records every read and every address
/// opened, so tests can prove what did and did not leave the app.
class FakeHost implements ResourceHost {
  /// Creates a host that serves [files] by `href` (for [ApiHref]) or by
  /// `file:<path>` (for [RepositoryFile]).
  FakeHost({Map<String, Uint8List>? files, Map<String, PreviewFolder>? folders})
    : files = files ?? {},
      folders = folders ?? {};

  /// The bytes by address.
  final Map<String, Uint8List> files;

  /// The folder listings by `href`.
  final Map<String, PreviewFolder> folders;

  /// What was read, oldest first.
  final List<ResourceTarget> reads = [];

  /// The `maxBytes` of each read, in order.
  final List<int?> maxBytesSeen = [];

  /// What was opened outside the app.
  final List<Uri> opened = [];

  /// When set, reads wait until it completes.
  Completer<void>? gate;

  /// When set, every read fails with it.
  Exception? failure;

  static String keyOf(ResourceTarget target) => switch (target) {
    ApiHref(:final href) => href,
    RepositoryFile(:final path) => 'file:$path',
  };

  @override
  Future<Uint8List> read(ResourceTarget target, {int? maxBytes}) async {
    reads.add(target);
    maxBytesSeen.add(maxBytes);
    await gate?.future;
    if (failure case final error?) {
      throw error;
    }
    final bytes = files[keyOf(target)];
    if (bytes == null) {
      throw StateError('404 ${keyOf(target)}');
    }
    if (maxBytes != null && bytes.length > maxBytes) {
      throw const ResourceTooLarge();
    }
    return bytes;
  }

  @override
  Future<PreviewFolder> listFolder(String href) async {
    final folder = folders[href];
    if (folder == null) {
      throw StateError('404 $href');
    }
    return folder;
  }

  @override
  Uri addressOf(ResourceTarget target) => Uri.parse(switch (target) {
    ApiHref(:final href) => 'https://lectale.test$href',
    RepositoryFile(:final path) =>
      'https://lectale.test/api/preview/1/sha/files/$path',
  });

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// The error view of tests: the error's text and a Try again button.
Widget testErrorBuilder(
  BuildContext context,
  Object error,
  VoidCallback retry,
) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text('Failed: $error'),
    DcButton(onPressed: retry, child: const Text('Try again')),
  ],
);

/// [theme] with the solid blocks of Flutter's test font instead of letters.
DcThemeData withTestFont(DcThemeData theme) => theme.copyWith(
  style: theme.style.copyWith(
    typography: theme.style.typography.copyWith(
      fontFamily: 'FlutterTest',
      monospaceFontFamily: 'FlutterTest',
    ),
  ),
);

/// Pumps a viewer built by [builder] in a 576 dp column on the page color.
///
/// The window is [width] wide at a pixel ratio of [pixelRatio].
Future<void> pumpViewer(
  WidgetTester tester,
  Widget Function(BuildContext context, ResourceEnvironment environment)
  builder, {
  FakeHost? host,
  Brightness brightness = Brightness.light,
  double width = 800,
  double pixelRatio = 1,
  int headingShift = 1,
}) async {
  tester.view
    ..physicalSize = Size(width * pixelRatio, 1200 * pixelRatio)
    ..devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  final data = withTestFont(DcThemeData(brightness: brightness));
  final fake = host ?? FakeHost();
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        DcLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: DcLocalizations.supportedLocales,
      pageRouteBuilder: <T>(settings, page) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => page(context),
      ),
      home: DcTheme(
        data: data,
        child: ColoredBox(
          color: data.colors.background,
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 576),
                child: Builder(
                  builder: (context) => builder(
                    context,
                    ResourceEnvironment(
                      host: fake,
                      errorBuilder: testErrorBuilder,
                      styles: TestStyles(context),
                      headingShift: headingShift,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Encodes a solid PNG of [width] by [height] pixels.
Future<Uint8List> makePng(WidgetTester tester, int width, int height) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const Color(0xFF753E5E),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Lets image header reads and decodes finish, which run outside the
/// tester's fake clock.
Future<void> settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

/// The count of widgets of type [T] in the tree, for "nothing was drawn".
int countOf<T extends Widget>(WidgetTester tester) =>
    find.byType(T).evaluate().length;

/// A render-tree check that no `RenderParagraph` holds [text].
bool paragraphHolds(WidgetTester tester, String text) => tester
    .renderObjectList<RenderParagraph>(find.byType(RichText))
    .any((paragraph) => paragraph.text.toPlainText().contains(text));

/// A PNG that is only a header: its signature and an IHDR claiming
/// [width] by [height]. It decodes to nothing, so a test that reaches the
/// decoder with it fails; the app must refuse it from the header alone.
Uint8List headerOnlyPng(int width, int height) {
  final bytes = ByteData(33);
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    bytes.setUint8(i, signature[i]);
  }
  bytes
    ..setUint32(8, 13)
    ..setUint32(12, 0x49484452)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes.buffer.asUint8List();
}
