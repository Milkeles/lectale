import 'dart:async';
import 'dart:convert';

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

import 'support/harness.dart';

OutlineResource _resource(
  OutlineResourceKind kind, {
  String id = 'item',
  String title = 'Item',
  String? href = '/api/preview/1/sha/content/lesson/item',
  String? path,
  String? extension,
  String? mediaType,
  int? sizeBytes,
  String? url,
  String? embedUrl,
  OutlineResourceProvider? provider,
  bool? download,
  int? maxEntries,
}) => OutlineResource(
  id: ManifestId(id),
  kind: kind,
  title: title,
  href: href,
  path: path,
  fileExtension: extension,
  mediaType: mediaType,
  sizeBytes: sizeBytes,
  url: url,
  embedUrl: embedUrl,
  provider: provider,
  download: download,
  maxEntries: maxEntries,
);

Uint8List _text(String text) => Uint8List.fromList(utf8.encode(text));

Future<FakeHost> _pump(
  WidgetTester tester,
  OutlineResource resource, {
  FakeHost? host,
}) async {
  final fake = host ?? FakeHost();
  await pumpViewer(
    tester,
    (context, env) =>
        ResourceRendererRegistry.standard().build(context, resource, env),
    host: fake,
  );
  await tester.pump();
  return fake;
}

void main() {
  group('registry', () {
    test('maps each kind to a renderer and resolves auto', () {
      final registry = ResourceRendererRegistry.standard();
      OutlineResourceKind kindOf(OutlineResource r) => resolveKind(r);

      expect(
        kindOf(_resource(OutlineResourceKind.auto, extension: 'md')),
        OutlineResourceKind.markdown,
      );
      expect(
        kindOf(_resource(OutlineResourceKind.auto, extension: 'CSV')),
        OutlineResourceKind.text,
      );
      expect(
        kindOf(_resource(OutlineResourceKind.auto, extension: 'py')),
        OutlineResourceKind.code,
      );
      expect(
        kindOf(_resource(OutlineResourceKind.auto, extension: 'png')),
        OutlineResourceKind.image,
      );
      expect(
        kindOf(_resource(OutlineResourceKind.auto, extension: 'ipynb')),
        OutlineResourceKind.notebook,
      );
      expect(
        kindOf(_resource(OutlineResourceKind.auto, mediaType: 'image/svg+xml')),
        OutlineResourceKind.file,
      );
      expect(
        kindOf(
          _resource(OutlineResourceKind.auto, mediaType: 'application/pdf'),
        ),
        OutlineResourceKind.pdf,
      );
      expect(
        registry.rendererFor(_resource(OutlineResourceKind.markdown)),
        isNotNull,
      );
    });

    test('a new kind is one entry and nothing else', () {
      var built = 0;
      final registry = ResourceRendererRegistry({
        OutlineResourceKind.audio: ResourceRenderer(
          build: (context, resource, env) {
            built++;
            return const SizedBox();
          },
        ),
      }, fallback: ResourceRendererRegistry.standard().fallback);

      final renderer = registry.rendererFor(
        _resource(OutlineResourceKind.audio),
      );
      expect(identical(renderer, registry.fallback), isFalse);
      expect(built, 0);
    });

    test('the Download bar applies only to kinds with a viewer', () {
      final registry = ResourceRendererRegistry.standard();

      expect(
        registry.offersBarDownload(_resource(OutlineResourceKind.markdown)),
        isTrue,
      );
      expect(
        registry.offersBarDownload(
          _resource(OutlineResourceKind.markdown, download: false),
        ),
        isFalse,
      );
      expect(
        registry.offersBarDownload(
          _resource(OutlineResourceKind.markdown),
          courseShowsDownloads: false,
        ),
        isFalse,
      );
      for (final kind in [
        OutlineResourceKind.pdf,
        OutlineResourceKind.notebook,
        OutlineResourceKind.folder,
        OutlineResourceKind.video,
      ]) {
        expect(registry.offersBarDownload(_resource(kind)), isFalse);
      }
    });
  });

  group('file card', () {
    testWidgets('a PDF shows name, type, size, reason and a working '
        'Download', (tester) async {
      final host = await _pump(
        tester,
        _resource(
          OutlineResourceKind.pdf,
          title: 'Slides',
          path: 'slides/week1.pdf',
          sizeBytes: 2300000,
        ),
      );

      expect(find.text('week1.pdf'), findsOneWidget);
      expect(find.text('PDF, 2.3 MB'), findsOneWidget);
      expect(
        find.text("Lectale can't show PDF files in this version."),
        findsOneWidget,
      );
      await tester.tap(find.text('Download PDF'));
      await tester.pump();

      expect(host.opened.single.path, '/api/preview/1/sha/content/lesson/item');
    });

    testWidgets('a notebook shows the download card for now', (tester) async {
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.notebook,
          path: 'labs/one.ipynb',
          extension: 'ipynb',
        ),
      );

      expect(find.text('one.ipynb'), findsOneWidget);
      expect(find.text('Notebook'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('an unknown type says so and offers Download', (tester) async {
      await _pump(tester, _resource(OutlineResourceKind.file, path: 'a.bin'));

      expect(
        find.textContaining("Lectale can't show this type of file."),
        findsOneWidget,
      );
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('a resource with nothing to open says so', (tester) async {
      await _pump(tester, _resource(OutlineResourceKind.pdf, href: null));

      expect(find.text('This item has no file to open.'), findsOneWidget);
      expect(find.text('Download'), findsNothing);
    });

    testWidgets('the card is accessible', (tester) async {
      await _pump(
        tester,
        _resource(OutlineResourceKind.pdf, path: 'a.pdf', sizeBytes: 1200),
      );

      await expectAccessible(tester);
    });
  });

  group('link card', () {
    testWidgets('a YouTube video opens the embed address after a tap', (
      tester,
    ) async {
      final host = await _pump(
        tester,
        _resource(
          OutlineResourceKind.video,
          href: null,
          title: 'Lecture 1',
          embedUrl: 'https://www.youtube.com/embed/abc',
          provider: OutlineResourceProvider.youtube,
        ),
      );

      expect(
        find.text('Opens www.youtube.com in your browser.'),
        findsOneWidget,
      );
      expect(host.opened, isEmpty);
      await tester.tap(find.text('Watch on YouTube'));
      await tester.pump();

      expect(host.opened, [Uri.parse('https://www.youtube.com/embed/abc')]);
    });

    testWidgets('an external link opens its address', (tester) async {
      final host = await _pump(
        tester,
        _resource(
          OutlineResourceKind.external2,
          href: null,
          url: 'https://example.org/page',
        ),
      );

      await tester.tap(find.text('Open link'));
      await tester.pump();

      expect(host.opened, [Uri.parse('https://example.org/page')]);
    });

    testWidgets('a javascript address is never offered', (tester) async {
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.external2,
          href: null,
          url: 'javascript:alert(1)',
        ),
      );

      expect(find.text('Open link'), findsNothing);
      expect(find.text('This item has no file to open.'), findsOneWidget);
    });
  });

  group('text viewer', () {
    testWidgets('prose wraps in the reading style', (tester) async {
      final host = FakeHost(
        files: {
          '/api/preview/1/sha/content/lesson/item': _text('Plain words.'),
        },
      );
      await _pump(
        tester,
        _resource(OutlineResourceKind.text, extension: 'txt'),
        host: host,
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('Plain words.'));
      expect(text.style!.fontSize, 18);
      expect(text.softWrap, isNull);
    });

    testWidgets('a data file keeps its columns, unwrapped, in a scroll '
        'region', (tester) async {
      final handle = tester.ensureSemantics();
      final host = FakeHost(
        files: {'/api/preview/1/sha/content/lesson/item': _text('a,b\n1,2\n')},
      );
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.text,
          extension: 'csv',
          path: 'data/x.csv',
        ),
        host: host,
      );
      await tester.pump();

      expect(tester.widget<Text>(find.text('a,b\n1,2')).softWrap, isFalse);
      expect(find.bySemanticsLabel(RegExp('^Data, x.csv')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a file over 512 KB becomes a card with Download', (
      tester,
    ) async {
      final host = FakeHost(
        files: {
          '/api/preview/1/sha/content/lesson/item': Uint8List(512 * 1024 + 1),
        },
      );
      await _pump(
        tester,
        _resource(OutlineResourceKind.text, path: 'big.txt'),
        host: host,
      );
      await tester.pump();

      expect(find.text('This file is too large to show here.'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('a failure shows in place and Try again loads again', (
      tester,
    ) async {
      final host = FakeHost(
        files: {'/api/preview/1/sha/content/lesson/item': _text('Back again')},
      )..failure = Exception('offline');
      await _pump(
        tester,
        _resource(OutlineResourceKind.text, extension: 'txt'),
        host: host,
      );
      await tester.pump();

      expect(find.textContaining('Failed: Exception: offline'), findsOneWidget);
      host.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Back again'), findsOneWidget);
      expect(host.reads, hasLength(2));
    });

    testWidgets('loading shows skeleton lines announced as Loading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final host = FakeHost(
        files: {'/api/preview/1/sha/content/lesson/item': _text('x')},
      )..gate = Completer<void>();
      await pumpViewer(
        tester,
        (context, env) => ResourceRendererRegistry.standard().build(
          context,
          _resource(OutlineResourceKind.text),
          env,
        ),
        host: host,
      );

      expect(find.byType(DcSkeleton), findsWidgets);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      host.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(DcSkeleton), findsNothing);
      handle.dispose();
    });
  });

  group('code viewer', () {
    testWidgets('shows line numbers, the language and a Copy button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final host = FakeHost(
        files: {
          '/api/preview/1/sha/content/lesson/item': _text(
            'a = 1\nb = 2\nc = 3\n',
          ),
        },
      );
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.code,
          extension: 'py',
          path: 'src/main.py',
        ),
        host: host,
      );
      await tester.pump();

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('1\n2\n3'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Code, Python')), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('a = 1\nb = 2\nc = 3')).softWrap,
        false,
      );
      handle.dispose();
    });

    testWidgets('Copy puts the code on the clipboard and says Copied', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final host = FakeHost(
        files: {'/api/preview/1/sha/content/lesson/item': _text('x = 1\n')},
      );
      await _pump(
        tester,
        _resource(OutlineResourceKind.code, extension: 'py'),
        host: host,
      );
      await tester.pump();

      expect(find.text('Copied'), findsNothing);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump();

      expect(copied, 'x = 1');
      expect(find.text('Copied'), findsOneWidget);
    });
  });

  group('image viewer', () {
    Future<FakeHost> pumpImage(
      WidgetTester tester, {
      int width = 1600,
      double pixelRatio = 2,
    }) async {
      final png = await makePng(tester, width, 800);
      final host = FakeHost(
        files: {'/api/preview/1/sha/content/lesson/item': png},
      );
      await pumpViewer(
        tester,
        (context, env) => ResourceRendererRegistry.standard().build(
          context,
          _resource(OutlineResourceKind.image, title: 'A chart'),
          env,
        ),
        host: host,
        pixelRatio: pixelRatio,
      );
      await settleImages(tester);
      return host;
    }

    testWidgets('decodes at the displayed size, and zoom re-decodes only '
        'what is shown', (tester) async {
      await pumpImage(tester);

      var image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).width, 1152);
      expect(tester.getSize(find.byType(Image)).width, 576);

      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      image = tester.widget<Image>(find.byType(Image));
      expect(tester.getSize(find.byType(Image)).width, 864);
      expect((image.image as ResizeImage).width, 1728);

      await tester.tap(find.bySemanticsLabel('Reset zoom'));
      await tester.pump();
      expect(tester.getSize(find.byType(Image)).width, 576);
    });

    testWidgets('a small image is not stretched', (tester) async {
      await pumpImage(tester, width: 200, pixelRatio: 1);

      expect(tester.getSize(find.byType(Image)).width, 200);
    });

    testWidgets('has three labelled zoom controls with tooltips', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpImage(tester, pixelRatio: 1);

      for (final label in ['Zoom in', 'Zoom out', 'Reset zoom']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(find.widgetWithText(DcTooltip, ''), findsNothing);
      }
      expect(
        find.byWidgetPredicate(
          (widget) => widget is DcTooltip && widget.message == 'Zoom out',
        ),
        findsOneWidget,
      );
      for (final button in tester.widgetList<DcButton>(find.byType(DcButton))) {
        expect(button.semanticLabel, isNotNull);
      }
      handle.dispose();
    });

    testWidgets('zoom out and reset are disabled at the fitted size', (
      tester,
    ) async {
      await pumpImage(tester, pixelRatio: 1);

      final buttons = tester
          .widgetList<DcButton>(find.byType(DcButton))
          .toList();
      expect(buttons[0].onPressed, isNotNull);
      expect(buttons[1].onPressed, isNull);
      expect(buttons[2].onPressed, isNull);
    });

    testWidgets('bytes that are not an image show the failure box with '
        'Download', (tester) async {
      final host = FakeHost(
        files: {
          '/api/preview/1/sha/content/lesson/item': _text('not an image'),
        },
      );
      await _pump(
        tester,
        _resource(OutlineResourceKind.image, title: 'A chart'),
        host: host,
      );
      await settleImages(tester);

      // Not a raster image: the file card, never the decoder.
      expect(find.byType(Image), findsNothing);
      expect(
        find.textContaining("Lectale can't show this type of file."),
        findsOneWidget,
      );
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('the viewer is accessible', (tester) async {
      await pumpImage(tester, pixelRatio: 1);

      await expectAccessible(tester);
    });
  });

  group('folder viewer', () {
    PreviewFolderEntry file(String name, {int size = 1200, String? href}) =>
        PreviewFolderEntry(
          name: name,
          type: PreviewFolderEntryType.file,
          size: size,
          href: href,
        );

    testWidgets('lists entries in order, indents by path and downloads '
        'files', (tester) async {
      final host = FakeHost(
        folders: {
          '/api/preview/1/sha/folders/lesson/item': PreviewFolder(
            entries: [
              const PreviewFolderEntry(
                name: 'sub',
                type: PreviewFolderEntryType.directory,
                size: 0,
              ),
              file(
                'sub/a.csv',
                href: '/api/preview/1/sha/files/data/sub/a.csv',
              ),
              file('b.txt', size: 40),
            ],
          ),
        },
      );
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.folder,
          href: '/api/preview/1/sha/folders/lesson/item',
        ),
        host: host,
      );
      await tester.pump();

      expect(find.text('Folder'), findsOneWidget);
      expect(find.text('1 KB'), findsOneWidget);
      expect(find.text('40 B'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('a.csv')).dx,
        greaterThan(tester.getTopLeft(find.text('sub')).dx),
      );
      // A directory has no action; a file with an href has its own.
      expect(find.text('Download'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(
        host.opened.single.path,
        '/api/preview/1/sha/files/data/sub/a.csv',
      );
    });

    testWidgets('an empty folder says so', (tester) async {
      final host = FakeHost(
        folders: {
          '/api/preview/1/sha/folders/lesson/item': const PreviewFolder(
            entries: [],
          ),
        },
      );
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.folder,
          href: '/api/preview/1/sha/folders/lesson/item',
        ),
        host: host,
      );
      await tester.pump();

      expect(find.text('This folder is empty.'), findsOneWidget);
    });

    testWidgets('says when the list was cut at the cap', (tester) async {
      final host = FakeHost(
        folders: {
          '/api/preview/1/sha/folders/lesson/item': PreviewFolder(
            entries: [file('a.txt'), file('b.txt')],
          ),
        },
      );
      await _pump(
        tester,
        _resource(
          OutlineResourceKind.folder,
          href: '/api/preview/1/sha/folders/lesson/item',
          maxEntries: 2,
        ),
        host: host,
      );
      await tester.pump();

      expect(
        find.text('Lectale shows up to 2 items from this folder.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a markdown resource renders through the registry', (
    tester,
  ) async {
    final host = FakeHost(
      files: {
        '/api/preview/1/sha/content/lesson/item': _text(
          '# Title\n\nHello [world](https://example.org).',
        ),
      },
    );
    await _pump(
      tester,
      _resource(OutlineResourceKind.markdown, path: 'lessons/one.md'),
      host: host,
    );
    await tester.pump();

    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(InlineLink), findsOneWidget);
  });
}
