import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

import 'support/harness.dart';

const String _contentHref = '/api/preview/1/sha/content/lesson/item';

OutlineResource _resource(
  OutlineResourceKind kind, {
  String title = 'Figure',
  String? path,
  String? extension,
  String? url,
  String? embedUrl,
  OutlineResourceProvider? provider,
}) => OutlineResource(
  id: const ManifestId('item'),
  kind: kind,
  title: title,
  href: url == null && embedUrl == null ? _contentHref : null,
  path: path,
  fileExtension: extension,
  url: url,
  embedUrl: embedUrl,
  provider: provider,
);

Future<void> _pumpResource(
  WidgetTester tester,
  OutlineResource resource,
  FakeHost host,
) async {
  await pumpViewer(
    tester,
    (context, env) =>
        ResourceRendererRegistry.standard().build(context, resource, env),
    host: host,
  );
  await settleImages(tester);
}

Future<FakeHost> _pumpMarkdown(
  WidgetTester tester,
  String markdown, {
  FakeHost? host,
  String? hideLeadingTitle,
}) async {
  final fake = host ?? FakeHost();
  await pumpViewer(
    tester,
    (context, env) => MarkdownView(
      source: markdown,
      environment: env,
      hideLeadingTitle: hideLeadingTitle,
    ),
    host: fake,
  );
  await settleImages(tester);
  return fake;
}

void main() {
  group('image size policy: refused from the header, before any decode', () {
    for (final (name, width, height) in [
      ('20000 by 20000', 20000, 20000),
      ('a tall 1 by 20000', 1, 20000),
      ('a wide 20000 by 1', 20000, 1),
      ('4097 by 4097, over 16 megapixels', 4097, 4097),
    ]) {
      testWidgets('a Markdown image of $name shows the box', (tester) async {
        final host = FakeHost(
          files: {'file:fig.png': headerOnlyPng(width, height)},
        );

        await _pumpMarkdown(tester, '![Figure](fig.png)', host: host);

        expect(find.byType(Image), findsNothing);
        expect(find.text("This image can't be shown."), findsOneWidget);
      });

      testWidgets('an image resource of $name shows the box and Download', (
        tester,
      ) async {
        final host = FakeHost(
          files: {_contentHref: headerOnlyPng(width, height)},
        );

        await _pumpResource(
          tester,
          _resource(
            OutlineResourceKind.image,
            path: 'fig.png',
            extension: 'png',
          ),
          host,
        );

        expect(find.byType(Image), findsNothing);
        expect(find.text("This image can't be shown."), findsOneWidget);
        expect(find.text('Download'), findsOneWidget);
      });
    }

    test('an image just inside the limits passes the policy', () async {
      expect(
        await naturalImageSize(headerOnlyPng(8192, 1953)),
        const Size(8192, 1953),
      );
      expect(
        await naturalImageSize(headerOnlyPng(1, 8192)),
        const Size(1, 8192),
      );
    });

    test('naturalImageSize throws ImageTooLarge and ImageNotRaster', () async {
      await expectLater(
        naturalImageSize(headerOnlyPng(20000, 20000)),
        throwsA(isA<ImageTooLarge>()),
      );
      await expectLater(
        naturalImageSize(Uint8List.fromList('<svg/>'.codeUnits)),
        throwsA(isA<ImageNotRaster>()),
      );
    });
  });

  group('image byte limit', () {
    testWidgets('every image read passes the 10 MB limit', (tester) async {
      final png = await makePng(tester, 10, 10);
      final host = FakeHost(files: {'file:fig.png': png, _contentHref: png});

      await _pumpMarkdown(tester, '![Figure](fig.png)', host: host);
      await _pumpResource(
        tester,
        _resource(OutlineResourceKind.image, path: 'fig.png', extension: 'png'),
        host,
      );

      expect(host.maxBytesSeen, isNotEmpty);
      expect(
        host.maxBytesSeen.every((limit) => limit == maxImageBytes),
        isTrue,
      );
      expect(maxImageBytes, 10 * 1000 * 1000);
    });

    testWidgets('a Markdown image over the limit shows the box', (
      tester,
    ) async {
      final host = FakeHost(
        files: {'file:fig.png': Uint8List(maxImageBytes + 1)},
      );

      await _pumpMarkdown(tester, '![Figure](fig.png)', host: host);

      expect(find.byType(Image), findsNothing);
      expect(find.text("This image can't be shown."), findsOneWidget);
    });

    testWidgets('an image resource over the limit shows the box', (
      tester,
    ) async {
      final host = FakeHost(
        files: {_contentHref: Uint8List(maxImageBytes + 1)},
      );

      await _pumpResource(
        tester,
        _resource(OutlineResourceKind.image, path: 'fig.png', extension: 'png'),
        host,
      );

      expect(find.text("This image can't be shown."), findsOneWidget);
    });
  });

  group('SVG is never drawn', () {
    testWidgets('an image resource that is an SVG is a file card', (
      tester,
    ) async {
      final host = FakeHost(
        files: {_contentHref: Uint8List.fromList('<svg/>'.codeUnits)},
      );

      await _pumpResource(
        tester,
        _resource(
          OutlineResourceKind.image,
          path: 'diagrams/logo.svg',
          extension: 'svg',
        ),
        host,
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('logo.svg'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(host.reads, isEmpty, reason: 'a file card reads nothing');
    });

    testWidgets('SVG bytes behind a .png name are a file card', (tester) async {
      final host = FakeHost(
        files: {
          _contentHref: Uint8List.fromList(
            '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'
                .codeUnits,
          ),
        },
      );

      await _pumpResource(
        tester,
        _resource(
          OutlineResourceKind.image,
          path: 'logo.png',
          extension: 'png',
        ),
        host,
      );

      expect(find.byType(Image), findsNothing);
      expect(
        find.textContaining("Lectale can't show this type of file."),
        findsOneWidget,
      );
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('SVG bytes behind a .png name in Markdown show the box', (
      tester,
    ) async {
      final host = FakeHost(
        files: {'file:logo.png': Uint8List.fromList('<svg/>'.codeUnits)},
      );

      await _pumpMarkdown(tester, '![Logo](logo.png)', host: host);

      expect(find.byType(Image), findsNothing);
      expect(find.text("This image can't be shown."), findsOneWidget);
    });
  });

  group('malformed and hostile paths read nothing', () {
    for (final destination in [
      '%FF.png',
      '/%2e%2e/x.png',
      '%2e%2e/x.png',
      'a/%2e%2e/%2e%2e/x.png',
      '%E0%A4%A.png',
    ]) {
      testWidgets('image $destination', (tester) async {
        final host = await _pumpMarkdown(tester, '![x]($destination)');

        expect(host.reads, isEmpty);
        expect(find.byType(Image), findsNothing);
        expect(find.text("This image can't be shown."), findsOneWidget);
      });
    }

    testWidgets('a link to %FF.png is plain text and does not throw', (
      tester,
    ) async {
      final host = await _pumpMarkdown(tester, '[file](%FF.png)');

      expect(find.byType(InlineLink), findsNothing);
      expect(paragraphHolds(tester, 'file'), isTrue);
      expect(host.opened, isEmpty);
    });
  });

  group('links that must never be followed', () {
    for (final destination in [
      '&#106;avascript:alert(1)',
      '&#x6A;avascript:alert(1)',
      'javascript%3Aalert(1)',
      '<javascript:alert(1)>',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///etc/passwd',
      'http://example.org/a',
    ]) {
      testWidgets(destination, (tester) async {
        final host = await _pumpMarkdown(tester, '[click]($destination)');

        expect(find.byType(InlineLink), findsNothing);
        expect(paragraphHolds(tester, 'click'), isTrue);
        expect(host.opened, isEmpty);
        expect(host.reads, isEmpty);
      });
    }

    testWidgets('an http link shows its host as text', (tester) async {
      await _pumpMarkdown(tester, '[Reference](http://example.org/reference)');

      expect(paragraphHolds(tester, 'Reference example.org'), isTrue);
      expect(find.byType(InlineLink), findsNothing);
    });

    testWidgets('an https link shows its host in ASCII form', (tester) async {
      final host = await _pumpMarkdown(
        tester,
        '[Bücher](https://bücher.example/a)',
      );

      expect(paragraphHolds(tester, '(xn--bcher-kva.example)'), isTrue);
      await tester.tap(find.byType(InlineLink));
      await tester.pump();
      expect(host.opened.single.host, 'xn--bcher-kva.example');
    });

    testWidgets('a host with an underscore is text, not a link', (
      tester,
    ) async {
      await _pumpMarkdown(tester, '[x](https://exa_mple.org/)');

      expect(find.byType(InlineLink), findsNothing);
    });
  });

  group('provider labels', () {
    testWidgets('YouTube on its own host reads Watch on YouTube', (
      tester,
    ) async {
      await _pumpResource(
        tester,
        _resource(
          OutlineResourceKind.video,
          embedUrl: 'https://www.youtube.com/embed/abc',
          provider: OutlineResourceProvider.youtube,
        ),
        FakeHost(),
      );

      expect(find.text('Watch on YouTube'), findsOneWidget);
    });

    testWidgets('Vimeo on its own host reads Watch on Vimeo', (tester) async {
      await _pumpResource(
        tester,
        _resource(
          OutlineResourceKind.video,
          embedUrl: 'https://player.vimeo.com/video/1',
          provider: OutlineResourceProvider.vimeo,
        ),
        FakeHost(),
      );

      expect(find.text('Watch on Vimeo'), findsOneWidget);
    });

    for (final (provider, host) in [
      (OutlineResourceProvider.youtube, 'evil.example'),
      (OutlineResourceProvider.youtube, 'youtube.com.evil.example'),
      (OutlineResourceProvider.youtube, 'notyoutube.com'),
      (OutlineResourceProvider.vimeo, 'vimeo.evil.example'),
      (OutlineResourceProvider.vimeo, 'youtube.com'),
    ]) {
      testWidgets('${provider.name} on $host is a generic link card', (
        tester,
      ) async {
        await _pumpResource(
          tester,
          _resource(
            OutlineResourceKind.video,
            embedUrl: 'https://$host/watch',
            provider: provider,
          ),
          FakeHost(),
        );

        expect(find.text('Open link'), findsOneWidget);
        expect(find.textContaining('Watch on'), findsNothing);
        expect(find.text('Opens $host in your browser.'), findsOneWidget);
      });
    }
  });

  group('headings have unique ids', () {
    testWidgets('two headings with the same text both stay visible', (
      tester,
    ) async {
      await _pumpMarkdown(tester, '# Practice\n\ntext\n\n## Practice\n\nmore');

      expect(find.text('Practice'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('links reach each heading on its own', (tester) async {
      await _pumpMarkdown(
        tester,
        '[first](#practice) [second](#practice-1)\n\n'
        '${'Filler.\n\n' * 40}'
        '# Practice\n\n${'Filler.\n\n' * 40}## Practice\n\nEnd',
      );

      FocusNode focusedHeading() => FocusManager.instance.primaryFocus!;

      await tester.tap(find.text('first'));
      await tester.pump();
      final first = focusedHeading();
      final firstTop = tester.getTopLeft(find.text('Practice').first).dy;

      await tester.ensureVisible(find.text('second'));
      await tester.pump();
      await tester.tap(find.text('second'));
      await tester.pump();
      final second = focusedHeading();

      expect(identical(first, second), isFalse);
      expect(
        find.text('Practice').hitTestable(),
        findsOneWidget,
        reason: 'the second heading is on screen after its own link',
      );
      expect(firstTop, isNot(tester.getTopLeft(find.text('Practice').last).dy));
    });

    testWidgets('three of a kind get practice, practice-1 and practice-2', (
      tester,
    ) async {
      await _pumpMarkdown(
        tester,
        '[a](#practice-2)\n\n# Practice\n\n# Practice\n\n# Practice',
      );

      expect(find.text('Practice'), findsNWidgets(3));
      await tester.tap(find.text('a'));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
    });
  });

  group('a title the page already shows', () {
    testWidgets('the first heading is hidden when it repeats the title', (
      tester,
    ) async {
      await _pumpMarkdown(
        tester,
        '# Statistics 101\n\nIntro.\n\n## Statistics 101\n\nLater.',
        hideLeadingTitle: 'Statistics 101',
      );

      // The second, author-supplied heading with the same text stays.
      expect(find.text('Statistics 101'), findsOneWidget);
      expect(paragraphHolds(tester, 'Intro.'), isTrue);
    });

    testWidgets('a different first heading is never hidden', (tester) async {
      await _pumpMarkdown(
        tester,
        '# Welcome\n\nIntro.',
        hideLeadingTitle: 'Statistics 101',
      );

      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('a hidden heading keeps its anchor', (tester) async {
      await _pumpMarkdown(
        tester,
        '[top](#statistics-101)\n\n'
        '${'Filler.\n\n' * 40}# Statistics 101\n\nEnd',
        hideLeadingTitle: 'Statistics 101',
      );

      await tester.tap(find.text('top'));
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, isNotNull);
    });
  });
}
