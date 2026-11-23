import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/host.dart';
import 'package:resource_renderers/src/markdown/math_syntax.dart';
import 'package:resource_renderers/src/repository_path.dart';
import 'package:resource_renderers/src/widgets/content_image.dart';
import 'package:resource_renderers/src/widgets/inline_link.dart';

/// The visible and accessible text of [node], with an image's description in
/// place of the image.
String plainText(md.Node node) {
  if (node is md.Text) {
    return node.text;
  }
  if (node is md.Element) {
    if (node.tag == 'img') {
      return node.attributes['alt'] ?? '';
    }
    return (node.children ?? const <md.Node>[]).map(plainText).join();
  }
  return '';
}

/// Turns the inline nodes of Markdown into spans of a line of text.
///
/// Flutter Markdown builds paragraphs itself; this class serves the parts it
/// does not let the app shape: links that take keyboard focus, formulas, and
/// the content of headings and table cells. Every link goes through
/// [classifyLink] and every image through [classifyImage] before anything
/// can load or open (V4-SEC-03).
class InlineComposer {
  /// Creates a composer for a document at [basePath].
  InlineComposer({
    required this.context,
    required this.environment,
    required this.basePath,
    required this.onAnchor,
  });

  /// Where the theme is read from.
  final BuildContext context;

  /// The host that opens links and loads images.
  final ResourceEnvironment environment;

  /// The repository path of the Markdown file, which relative links and
  /// images resolve against.
  final String basePath;

  /// Scrolls to and focuses the heading with this id.
  final void Function(String id) onAnchor;

  DcThemeData get _theme => DcTheme.of(context);

  /// The style of inline code: Plex Mono, a little under the reading size,
  /// on Sand.
  TextStyle codeStyle(TextStyle around) => _theme.typography.code.copyWith(
    color: around.color,
    fontSize: (around.fontSize ?? 18) * 0.86,
    height: around.height,
    backgroundColor: _theme.colors.muted,
  );

  TextStyle get _hostStyle =>
      _theme.typography.small.copyWith(color: _theme.colors.mutedForeground);

  /// Spans for [nodes] in [style].
  List<InlineSpan> spans(List<md.Node>? nodes, TextStyle style) => [
    for (final node in nodes ?? const <md.Node>[]) ..._span(node, style),
  ];

  List<InlineSpan> _span(md.Node node, TextStyle style) {
    if (node is md.Text) {
      return [TextSpan(text: node.text, style: style)];
    }
    if (node is! md.Element) {
      return const [];
    }
    switch (node.tag) {
      case 'strong':
        return spans(
          node.children,
          style.copyWith(fontWeight: _theme.typography.semibold),
        );
      case 'em':
        return spans(
          node.children,
          style.copyWith(fontStyle: FontStyle.italic),
        );
      case 'del':
        return spans(
          node.children,
          style.copyWith(decoration: TextDecoration.lineThrough),
        );
      case 'code':
        return [TextSpan(text: node.textContent, style: codeStyle(style))];
      case 'br':
        return [TextSpan(text: '\n', style: style)];
      case 'a':
        return link(node, style);
      case 'img':
        return [image(node)];
      case mathTag:
        return [math(node, style)];
      default:
        return spans(node.children, style);
    }
  }

  /// The spans of a link: an interactive link when its target may be
  /// followed, else the text with the target after it (course.md §5).
  List<InlineSpan> link(md.Element element, TextStyle style) {
    final target = classifyLink(element.attributes['href'], basePath: basePath);
    var text = plainText(element).trim();
    final linkStyle = style.copyWith(color: environment.styles.link);
    switch (target) {
      case AnchorLink(:final id):
        return [
          _interactive(
            text.isEmpty ? id : text,
            text.isEmpty ? id : text,
            linkStyle,
            () => onAnchor(id),
          ),
        ];
      case RepositoryLink(:final path):
        text = text.isEmpty ? path : text;
        return [
          _interactive(
            text,
            ViewerCopy.fileLinkName(text),
            linkStyle,
            () => environment.host.open(
              environment.host.addressOf(RepositoryFile(path)),
            ),
          ),
        ];
      case ExternalLink(:final uri):
        text = text.isEmpty ? uri.host : text;
        return [
          _interactive(
            text,
            ViewerCopy.externalLinkName(text),
            linkStyle,
            () => environment.host.open(uri),
          ),
          // The host is always visible, so a link can't pass for another
          // site (threat 5.6).
          TextSpan(text: ' (${uri.host})', style: _hostStyle),
        ];
      case RefusedLink(:final shown):
        return [
          TextSpan(text: text.isEmpty ? shown : text, style: style),
          if (shown.isNotEmpty && text.isNotEmpty)
            TextSpan(text: ' $shown', style: _hostStyle),
        ];
    }
  }

  InlineSpan _interactive(
    String text,
    String label,
    TextStyle style,
    VoidCallback onPressed,
  ) => inlineLinkSpan(
    InlineLink(
      text: text,
      semanticLabel: label,
      onPressed: onPressed,
      style: style,
    ),
  );

  /// The widget of an image element. It is classified from the `src` as the
  /// author wrote it, before any URI parsing can normalize `..` away, so an
  /// attempted climb is refused and not quietly accepted.
  Widget imageWidget(md.Element element) => ContentImage(
    target: classifyImage(element.attributes['src'], basePath: basePath),
    alt: element.attributes['alt'] ?? '',
    environment: environment,
  );

  /// The span of an image element.
  InlineSpan image(md.Element element) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: imageWidget(element),
  );

  /// The span of an inline formula.
  InlineSpan math(md.Element element, TextStyle style) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: MathFormula(
      tex: element.textContent,
      display: element.attributes['display'] == 'true',
      style: style,
    ),
  );
}

/// A formula drawn with flutter_math_fork.
///
/// The TeX source is the accessible name, since the drawn glyphs have no
/// text of their own. A formula that doesn't parse shows its source in code
/// and says so ("Formula, as written").
class MathFormula extends StatelessWidget {
  /// Creates the formula.
  const MathFormula({
    required this.tex,
    required this.style,
    this.display = false,
    super.key,
  });

  /// The TeX source.
  final String tex;

  /// Whether to set it in display style.
  final bool display;

  /// The surrounding text style: size and color.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final fallbackStyle = theme.typography.code.copyWith(
      color: style.color,
      backgroundColor: theme.colors.muted,
    );
    final math = Math.tex(
      tex,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: TextStyle(color: style.color, fontSize: style.fontSize),
    );
    if (math.parseError != null) {
      return Semantics(
        label: '${ViewerCopy.formulaAsWritten}: $tex',
        excludeSemantics: true,
        child: Text(tex, style: fallbackStyle),
      );
    }
    // A formula wider than its line shrinks to fit rather than overflow;
    // display formulas scroll in their own region instead.
    final drawn = display
        ? math
        : FittedBox(fit: BoxFit.scaleDown, child: math);
    return Semantics(label: tex, excludeSemantics: true, child: drawn);
  }
}
