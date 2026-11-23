import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_renderers/resource_renderers.dart';

import 'support/harness.dart';

Future<FakeHost> _pump(
  WidgetTester tester,
  String markdown, {
  String basePath = 'README.md',
  FakeHost? host,
}) async {
  final fake = host ?? FakeHost();
  await pumpViewer(
    tester,
    (context, env) =>
        MarkdownView(source: markdown, environment: env, basePath: basePath),
    host: fake,
  );
  await settleImages(tester);
  return fake;
}

void main() {
  group('raw HTML is text, never markup (V4-SEC-03)', () {
    testWidgets('<script> shows as visible characters', (tester) async {
      final host = await _pump(
        tester,
        'Before\n\n<script>alert(1)</script>\n\nAfter',
      );

      expect(paragraphHolds(tester, '<script>alert(1)</script>'), isTrue);
      expect(host.reads, isEmpty);
      expect(host.opened, isEmpty);
    });

    testWidgets('<img onerror> shows as text and loads nothing', (
      tester,
    ) async {
      final host = await _pump(
        tester,
        'Look <img src="https://tracker.example/x.png" onerror="alert(1)"> here',
      );

      expect(paragraphHolds(tester, '<img src='), isTrue);
      expect(paragraphHolds(tester, 'onerror="alert(1)"'), isTrue);
      expect(find.byType(Image), findsNothing);
      expect(host.reads, isEmpty);
    });

    testWidgets('<iframe> shows as text and loads nothing', (tester) async {
      final host = await _pump(
        tester,
        '<iframe src="https://evil.example/frame"></iframe>',
      );

      expect(paragraphHolds(tester, '<iframe src='), isTrue);
      expect(host.reads, isEmpty);
      expect(host.opened, isEmpty);
    });

    testWidgets('inline tags show as text', (tester) async {
      await _pump(tester, 'A <b>bold</b> and <a href="x">link</a> claim');

      expect(paragraphHolds(tester, '<b>bold</b>'), isTrue);
      expect(find.byType(InlineLink), findsNothing);
    });
  });

  group('unsafe links are plain text and never followed', () {
    const bad = <String>[
      'javascript:alert(1)',
      'JavaScript:alert(1)',
      'JAVASCRIPT:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'DaTa:text/html;base64,PHNjcmlwdD4=',
      'vbscript:msgbox(1)',
      'VBScript:msgbox(1)',
    ];

    for (final target in bad) {
      testWidgets(target, (tester) async {
        final host = await _pump(tester, '[click me]($target)');

        expect(find.byType(InlineLink), findsNothing);
        expect(paragraphHolds(tester, 'click me'), isTrue);
        await tester.tapAt(tester.getCenter(find.textContaining('click me')));
        await tester.pump();
        expect(host.opened, isEmpty);
        expect(host.reads, isEmpty);
      });
    }

    testWidgets('whitespace and control characters before the colon', (
      tester,
    ) async {
      // Angle brackets let the destination hold characters a bare one can't.
      for (final target in [
        '<java\tscript:alert(1)>',
        '<java\nscript:alert(1)>',
        '< javascript:alert(1)>',
        '<\tjavascript:alert(1)>',
        '<java\u0000script:alert(1)>',
        '<\u0001javascript:alert(1)>',
      ]) {
        final host = await _pump(tester, '[click me]($target)');

        expect(find.byType(InlineLink), findsNothing, reason: target);
        expect(host.opened, isEmpty, reason: target);
        expect(host.reads, isEmpty, reason: target);
      }
    });

    testWidgets('the target is shown after the text, in small type', (
      tester,
    ) async {
      await _pump(tester, '[click me](javascript:alert(1))');

      expect(paragraphHolds(tester, 'click me javascript:alert(1)'), isTrue);
    });

    testWidgets('a path outside the repository is plain text', (tester) async {
      final host = await _pump(tester, '[secret](../../secret.md)');

      expect(find.byType(InlineLink), findsNothing);
      expect(paragraphHolds(tester, 'secret ../../secret.md'), isTrue);
      expect(host.opened, isEmpty);
    });
  });

  group('images load only through the files route', () {
    testWidgets('a remote image is not fetched and shows the box', (
      tester,
    ) async {
      final host = await _pump(
        tester,
        '![A chart of results](https://tracker.example/x.png)',
      );

      expect(host.reads, isEmpty);
      expect(find.byType(Image), findsNothing);
      expect(find.text("This image can't be shown."), findsOneWidget);
      expect(find.textContaining('A chart of results'), findsOneWidget);
      expect(find.textContaining('tracker.example'), findsOneWidget);
    });

    testWidgets('an http image, a data image and an SVG are not fetched', (
      tester,
    ) async {
      for (final source in [
        '![a](http://tracker.example/x.png)',
        '![b](data:image/png;base64,iVBORw0KGgo=)',
        '![c](figures/logo.svg)',
        '![d](//tracker.example/x.png)',
        '![e](blob:https://example.org/uuid)',
      ]) {
        final host = await _pump(tester, source);

        expect(host.reads, isEmpty, reason: source);
        expect(find.byType(Image), findsNothing, reason: source);
        expect(
          find.text("This image can't be shown."),
          findsOneWidget,
          reason: source,
        );
      }
    });

    testWidgets('an image outside the repository is not requested', (
      tester,
    ) async {
      final host = await _pump(tester, '![x](../../x.png)');

      expect(host.reads, isEmpty);
      expect(find.text("This image can't be shown."), findsOneWidget);
    });

    testWidgets('a repository image loads through the files route, decoded at '
        'the size it is shown', (tester) async {
      final png = await makePng(tester, 1600, 800);
      final host = FakeHost(files: {'file:docs/img/fig.png': png});

      await pumpViewer(
        tester,
        (context, env) => MarkdownView(
          source: '![Figure](img/fig.png)',
          environment: env,
          basePath: 'docs/guide.md',
        ),
        host: host,
        pixelRatio: 2,
      );
      await settleImages(tester);

      expect(host.reads, [const RepositoryFile('docs/img/fig.png')]);
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as ResizeImage;
      // 576 dp column at a pixel ratio of 2: never the 1600 px original.
      expect(provider.width, 1152);
      expect(tester.getSize(find.byType(Image)).width, 576);
      expect(find.bySemanticsLabel('Figure'), findsOneWidget);
    });

    testWidgets('a missing repository image shows the box, not a broken '
        'glyph', (tester) async {
      final host = await _pump(tester, '![Figure](img/missing.png)');
      await settleImages(tester);

      expect(host.reads, [const RepositoryFile('img/missing.png')]);
      expect(find.text("This image can't be shown."), findsOneWidget);
      expect(find.textContaining('Figure'), findsOneWidget);
      expect(find.textContaining('missing.png'), findsOneWidget);
    });

    testWidgets('an image without a description names its file', (
      tester,
    ) async {
      await _pump(tester, '![](img/missing.png)');
      await settleImages(tester);

      expect(
        find.textContaining('Image without description: missing.png'),
        findsOneWidget,
      );
    });
  });

  testWidgets('nothing in the viewer builds an object URL', (tester) async {
    // The host interface has no way to hand bytes to the browser: viewers
    // read bytes and draw them, or pass an address to open().
    final host = await _pump(tester, '[a](https://example.org)\n\n![b](c.png)');
    await settleImages(tester);

    expect(host.opened.where((uri) => uri.scheme == 'blob'), isEmpty);
    expect(host.reads.whereType<ApiHref>(), isEmpty);
  });
}
