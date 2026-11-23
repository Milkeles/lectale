import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resource_renderers/resource_renderers.dart';

import 'support/harness.dart';

Future<FakeHost> _pump(
  WidgetTester tester,
  String markdown, {
  String basePath = 'README.md',
  int headingShift = 1,
  FakeHost? host,
}) async {
  final fake = host ?? FakeHost();
  await pumpViewer(
    tester,
    (context, env) =>
        MarkdownView(source: markdown, environment: env, basePath: basePath),
    host: fake,
    headingShift: headingShift,
  );
  await settleImages(tester);
  return fake;
}

void main() {
  testWidgets('headings shift down by the environment shift', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, '# One\n\n## Two\n\nText');

    expect(tester.getSemantics(find.text('One')).headingLevel, 2);
    expect(tester.getSemantics(find.text('Two')).headingLevel, 3);
    handle.dispose();
  });

  testWidgets('heading levels clamp at 6', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, '##### Five\n\n###### Six', headingShift: 2);

    expect(tester.getSemantics(find.text('Five')).headingLevel, 6);
    expect(tester.getSemantics(find.text('Six')).headingLevel, 6);
    handle.dispose();
  });

  testWidgets('an anchor link scrolls to its heading and focuses it', (
    tester,
  ) async {
    await _pump(
      tester,
      '[Jump](#later-section)\n\n${'Filler paragraph.\n\n' * 60}'
      '## Later section\n\nEnd',
    );

    expect(find.text('Later section').hitTestable(), findsNothing);
    await tester.tap(find.text('Jump'));
    await tester.pump();

    expect(find.text('Later section').hitTestable(), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is Focus && widget.focusNode == focused,
        ),
        matching: find.text('Later section'),
      ),
      findsOneWidget,
    );
  });

  group('links', () {
    testWidgets('an external link shows its host and opens in the browser', (
      tester,
    ) async {
      final host = await _pump(
        tester,
        'See [the docs](https://example.org/a).',
      );

      expect(paragraphHolds(tester, '(example.org)'), isTrue);
      await tester.tap(find.text('the docs'));
      await tester.pump();

      expect(host.opened, [Uri.parse('https://example.org/a')]);
    });

    testWidgets('a repository link opens its files-route address', (
      tester,
    ) async {
      final host = await _pump(
        tester,
        '[the data](data/x.csv)',
        basePath: 'docs/guide.md',
      );

      await tester.tap(find.text('the data'));
      await tester.pump();

      expect(host.opened.single.path, endsWith('/files/docs/data/x.csv'));
    });

    testWidgets('links are named by their text and where they go', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, '[web](https://example.org) [file](a.md)');

      expect(
        find.bySemanticsLabel('web, opens in your browser'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('file, opens the file in your browser'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Tab reaches each link in order and Enter opens it', (
      tester,
    ) async {
      final host = await _pump(
        tester,
        'First [one](https://one.example) then [two](https://two.example).',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(host.opened, [Uri.parse('https://two.example')]);
    });

    testWidgets('a link is at least 24 dp tall', (tester) async {
      await _pump(tester, '[one](https://one.example)');

      expect(
        tester.getSize(find.byType(InlineLink)).height,
        greaterThanOrEqualTo(24),
      );
    });
  });

  group('formulas', () {
    testWidgets('inline and display LaTeX render, named by their source', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        'Energy is \$E = mc^2\$ here.\n\n\$\$\\int_0^1 x\\,dx\$\$',
      );

      expect(find.byType(Math), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp(r'E = mc\^2')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'int_0\^1 x')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a block between dollar-dollar lines renders as a formula', (
      tester,
    ) async {
      await _pump(tester, 'Before\n\n\$\$\na^2 + b^2 = c^2\n\$\$\n\nAfter');

      expect(find.byType(Math), findsOneWidget);
      expect(paragraphHolds(tester, 'After'), isTrue);
    });

    testWidgets('prices are not formulas', (tester) async {
      await _pump(tester, r'It costs $5 and then $6 more.');

      expect(find.byType(Math), findsNothing);
      expect(paragraphHolds(tester, r'$5 and then $6'), isTrue);
    });

    testWidgets('a formula that does not parse shows its source', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, r'Broken $\frac{1}{$ here');

      expect(
        find.bySemanticsLabel(RegExp('Formula, as written')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('blocks', () {
    testWidgets('a code block is unwrapped and a focusable scroll region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, '```python\n${'x' * 200} = 1\n```');

      expect(find.bySemanticsLabel(RegExp('^Code, python')), findsOneWidget);
      expect(
        tester.widget<Text>(find.textContaining('xxxx')).softWrap,
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find
            .ancestor(
              of: find.bySemanticsLabel(RegExp('^Code, python')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.pixels, greaterThan(0));
      handle.dispose();
    });

    testWidgets('a table renders its cells in a scroll region', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        '| Name | Score |\n|---|---|\n| Ada | 10 |\n| Grace | 12 |',
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Grace'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Table')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('lists, quotes and task items render', (tester) async {
      await _pump(tester, '- one\n- two\n\n> quoted\n\n- [x] done\n- [ ] todo');

      expect(paragraphHolds(tester, 'one'), isTrue);
      expect(paragraphHolds(tester, 'quoted'), isTrue);
      expect(paragraphHolds(tester, 'todo'), isTrue);
    });
  });

  testWidgets('markdown is accessible: contrast, labels and targets', (
    tester,
  ) async {
    await _pump(
      tester,
      '# Title\n\nSome text with a [link](https://example.org) and `code`.\n\n'
      '- item\n\n```\ncode block\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |',
    );

    await expectAccessible(tester);
  });

  testWidgets('markdown is accessible in the dark theme', (tester) async {
    await pumpViewer(
      tester,
      (context, env) => MarkdownView(
        source: '# Title\n\nText with a [link](https://example.org).',
        environment: env,
      ),
      brightness: Brightness.dark,
    );

    await expectAccessible(tester);
  });
}
