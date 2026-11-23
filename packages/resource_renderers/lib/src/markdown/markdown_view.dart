import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/markdown/inline_composer.dart';
import 'package:resource_renderers/src/markdown/markdown_blocks.dart';
import 'package:resource_renderers/src/markdown/math_syntax.dart';
import 'package:resource_renderers/src/repository_path.dart';

/// Course Markdown as widgets, without HTML.
///
/// Raw HTML is not parsed into elements: the parser keeps it as text, so
/// `<script>` shows as the characters it is made of. Every link and image is
/// classified before it can open or load ([classifyLink], [classifyImage]):
/// repository files go through the host's files route, other hosts' images
/// never load, SVG and `data:` never draw, and unsafe schemes such as
/// `javascript:` render as plain text. No webview, iframe or object URL is
/// involved (V4-SEC-03, threat 5.6).
///
/// [basePath] is the repository path of the Markdown file, `README.md` for
/// the overview; relative links and images resolve against its folder.
/// Headings shift down by `environment.headingShift` levels.
class MarkdownView extends StatefulWidget {
  /// Creates the view of [source].
  const MarkdownView({
    required this.source,
    required this.environment,
    this.basePath = '',
    this.hideLeadingTitle,
    super.key,
  });

  /// The Markdown text.
  final String source;

  /// The host, error view and text styles.
  final ResourceEnvironment environment;

  /// The repository path of the file, for relative links and images.
  final String basePath;

  /// A title the page already shows. When the document's first heading is
  /// exactly this text it is not drawn again; its anchor stays, so links to
  /// it still work. Other headings are never hidden.
  final String? hideLeadingTitle;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _Anchor {
  final GlobalKey key = GlobalKey();
  final FocusNode node = FocusNode(skipTraversal: true);
}

class _MarkdownViewState extends State<MarkdownView> {
  final Map<String, _Anchor> _anchors = {};

  @override
  void dispose() {
    for (final anchor in _anchors.values) {
      anchor.node.dispose();
    }
    super.dispose();
  }

  _Anchor _anchorFor(String id) => _anchors.putIfAbsent(id, _Anchor.new);

  void _goTo(String id) {
    final anchor = _anchors[id] ?? _anchors[id.toLowerCase()];
    final target = anchor?.key.currentContext;
    if (anchor == null || target == null) {
      return;
    }
    // Instant, as the spec asks: no scroll animation.
    Scrollable.ensureVisible(target);
    anchor.node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final colors = theme.colors;
    final style = theme.style;
    final env = widget.environment;
    final reading = env.styles.reading;
    final composer = InlineComposer(
      context: context,
      environment: env,
      basePath: widget.basePath,
      onAnchor: _goTo,
    );

    final builders = <String, MarkdownElementBuilder>{
      for (var level = 1; level <= 6; level++)
        'h$level': _HeadingBuilder(
          level: level,
          environment: env,
          composer: composer,
          anchorFor: _anchorFor,
          hideLeadingTitle: widget.hideLeadingTitle,
        ),
      'a': _LinkBuilder(composer, reading),
      'img': _ImageBuilder(composer),
      mathTag: _MathBuilder(composer, reading),
      mathBlockTag: _MathBlockBuilder(reading),
      tableTag: _TableBuilder(composer, reading),
      'pre': _CodeBlockBuilder(),
    };

    return MarkdownBody(
      data: widget.source,
      extensionSet: lectaleExtensionSet(),
      fitContent: false,
      builders: builders,
      checkboxBuilder: (checked) => Padding(
        padding: EdgeInsetsDirectional.only(end: style.space(1)),
        child: Icon(
          checked ? LucideIcons.squareCheck : LucideIcons.square,
          size: 18,
          color: colors.foreground,
          semanticLabel: checked ? 'Done' : 'Not done',
        ),
      ),
      styleSheet: MarkdownStyleSheet(
        p: reading,
        pPadding: EdgeInsets.zero,
        a: reading.copyWith(color: env.styles.link),
        code: composer.codeStyle(reading),
        em: reading.copyWith(fontStyle: FontStyle.italic),
        strong: reading.copyWith(fontWeight: theme.typography.semibold),
        del: reading.copyWith(decoration: TextDecoration.lineThrough),
        blockquote: reading,
        blockquotePadding: EdgeInsets.all(style.space(3)),
        blockquoteDecoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(style.radiusSmall),
        ),
        checkbox: reading,
        listBullet: reading,
        listIndent: style.space(5),
        listBulletPadding: EdgeInsets.only(right: style.space(2)),
        blockSpacing: reading.fontSize! * 0.9,
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
        tableBody: reading,
        tableHead: reading,
        tableCellsPadding: EdgeInsets.zero,
        tableColumnWidth: const FlexColumnWidth(),
      ),
    );
  }
}

class _HeadingBuilder extends MarkdownElementBuilder {
  _HeadingBuilder({
    required this.level,
    required this.environment,
    required this.composer,
    required this.anchorFor,
    this.hideLeadingTitle,
  });

  final String? hideLeadingTitle;
  final int level;
  final ResourceEnvironment environment;
  final InlineComposer composer;
  final _Anchor Function(String id) anchorFor;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final shifted = (level + environment.headingShift).clamp(1, 6);
    final id = element.generatedId ?? '';
    final anchor = anchorFor(id.isEmpty ? '#${identityHashCode(element)}' : id);
    final repeatsTitle =
        hideLeadingTitle != null &&
        element.attributes[firstHeadingAttribute] == 'true' &&
        element.textContent.trim() == hideLeadingTitle!.trim();
    return MarkdownHeading(
      hidden: repeatsTitle,
      element: element,
      level: shifted,
      style: environment.styles.title(shifted),
      composer: composer,
      anchorKey: anchor.key,
      focusNode: anchor.node,
    );
  }
}

class _ImageBuilder extends MarkdownElementBuilder {
  _ImageBuilder(this.composer);

  final InlineComposer composer;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => composer.imageWidget(element);
}

class _LinkBuilder extends MarkdownElementBuilder {
  _LinkBuilder(this.composer, this.reading);

  final InlineComposer composer;
  final TextStyle reading;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(
      style: parentStyle ?? reading,
      children: composer.link(element, parentStyle ?? reading),
    ),
  );
}

class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder(this.composer, this.reading);

  final InlineComposer composer;
  final TextStyle reading;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(children: [composer.math(element, parentStyle ?? reading)]),
  );
}

class _MathBlockBuilder extends MarkdownElementBuilder {
  _MathBlockBuilder(this.reading);

  final TextStyle reading;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => MarkdownMathBlock(tex: element.textContent, style: reading);
}

class _TableBuilder extends MarkdownElementBuilder {
  _TableBuilder(this.composer, this.reading);

  final InlineComposer composer;
  final TextStyle reading;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final table = element.children?.whereType<md.Element>().firstOrNull;
    if (table == null) {
      return const SizedBox.shrink();
    }
    return MarkdownTable(table: table, composer: composer, style: reading);
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final name = code?.attributes['class'] ?? '';
    return MarkdownCodeBlock(
      code: element.textContent.replaceAll(RegExp(r'\n$'), ''),
      language: name.startsWith('language-')
          ? name.substring('language-'.length)
          : '',
    );
  }
}
