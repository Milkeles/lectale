import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:resource_renderers/src/markdown/inline_composer.dart';
import 'package:resource_renderers/src/widgets/code_surface.dart';
import 'package:resource_renderers/src/widgets/focus_scroll_region.dart';

/// A heading of the document. It is a heading for assistive technology at
/// its shifted level, and an anchor target: a `#link` scrolls to it and
/// moves focus to it, without making it a Tab stop.
class MarkdownHeading extends StatelessWidget {
  /// Creates the heading for [element] at [level] (1 to 6, already shifted).
  const MarkdownHeading({
    required this.element,
    required this.level,
    required this.style,
    required this.composer,
    required this.anchorKey,
    required this.focusNode,
    this.hidden = false,
    super.key,
  });

  /// Whether the heading repeats a title the page already shows. It is then
  /// drawn as nothing and left out of the semantics, but keeps its anchor.
  final bool hidden;

  /// The heading's parsed content.
  final md.Element element;

  /// The level after the shift.
  final int level;

  /// The style for the level, from the content styles.
  final TextStyle style;

  /// Builds the inline content.
  final InlineComposer composer;

  /// Lets a link find this heading.
  final GlobalKey anchorKey;

  /// Receives focus from an anchor link.
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final space = DcTheme.of(context).style.space(3);
    if (hidden) {
      return KeyedSubtree(
        key: anchorKey,
        child: Focus(
          focusNode: focusNode,
          skipTraversal: true,
          includeSemantics: false,
          child: const SizedBox.shrink(),
        ),
      );
    }
    return KeyedSubtree(
      key: anchorKey,
      child: Padding(
        padding: EdgeInsets.only(top: space),
        child: Semantics(
          container: true,
          header: true,
          headingLevel: level,
          child: Focus(
            focusNode: focusNode,
            skipTraversal: true,
            child: Text.rich(
              TextSpan(children: composer.spans(element.children, style)),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// A fenced or indented code block in Markdown: Plex Mono on Sand, never
/// wrapped, in a region the keyboard can scroll.
class MarkdownCodeBlock extends StatelessWidget {
  /// Creates the block for [code], written in [language] when named.
  const MarkdownCodeBlock({required this.code, this.language = '', super.key});

  /// The source text without its final newline.
  final String code;

  /// The language named after the opening fence, or empty.
  final String language;

  @override
  Widget build(BuildContext context) => CodeSurface(
    code: code,
    semanticLabel: language.isEmpty ? 'Code' : 'Code, $language',
  );
}

/// A table: header cells in semibold, rows divided by a line, drawn in a
/// scroll region that takes focus so the arrow keys scroll it.
class MarkdownTable extends StatelessWidget {
  /// Creates the table for the parsed [table] element.
  const MarkdownTable({
    required this.table,
    required this.composer,
    required this.style,
    super.key,
  });

  /// The `table` element with its `thead` and `tbody`.
  final md.Element table;

  /// Builds the content of each cell.
  final InlineComposer composer;

  /// The text style of body cells.
  final TextStyle style;

  static const double _maxCellWidth = 320;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final spacing = theme.style;
    final rows = <TableRow>[];
    for (final section
        in table.children?.whereType<md.Element>() ?? const <md.Element>[]) {
      final header = section.tag == 'thead';
      for (final row
          in section.children?.whereType<md.Element>() ??
              const <md.Element>[]) {
        rows.add(
          TableRow(
            children: [
              for (final cell
                  in row.children?.whereType<md.Element>() ??
                      const <md.Element>[])
                Semantics(
                  container: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxCellWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.space(3),
                        vertical: spacing.space(2),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: composer.spans(
                            cell.children,
                            header
                                ? style.copyWith(
                                    fontWeight: theme.typography.semibold,
                                  )
                                : style,
                          ),
                        ),
                        style: style,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }
    return FocusScrollRegion(
      semanticLabel: 'Table',
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(
          horizontalInside: BorderSide(color: theme.colors.border),
          bottom: BorderSide(color: theme.colors.border),
        ),
        children: rows,
      ),
    );
  }
}

/// A formula on lines of its own, centred when it fits and scrollable when
/// it doesn't.
class MarkdownMathBlock extends StatelessWidget {
  /// Creates the block for [tex].
  const MarkdownMathBlock({required this.tex, required this.style, super.key});

  /// The TeX source.
  final String tex;

  /// The surrounding text style: size and color.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FocusScrollRegion(
        semanticLabel: 'Formula',
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: DcTheme.of(context).style.space(2),
              ),
              child: MathFormula(tex: tex, display: true, style: style),
            ),
          ),
        ),
      ),
    );
  }
}
