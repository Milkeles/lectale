import 'package:markdown/markdown.dart' as md;

/// The tag of a formula inside a line of text.
const String mathTag = 'lectale-math';

/// The tag of a formula that has lines of its own.
const String mathBlockTag = 'lectale-math-block';

/// The tag of a table, wrapped so the renderer can draw it in a scroll
/// region that takes keyboard focus.
const String tableTag = 'lectale-table';

/// Inline LaTeX: `$x^2$`, and `$$x^2$$` inside a line, which is set as a
/// display formula.
///
/// The rules are pandoc's, so prices don't turn into formulas: the opening
/// `$` is not followed by a space, the closing one is not preceded by a space
/// and not followed by a digit. `\$` is a dollar sign.
class MathInlineSyntax extends md.InlineSyntax {
  /// Creates the syntax.
  MathInlineSyntax()
    : super(
        r'(?<![\\$])(?:\$\$((?:\\.|[^$\\])+?)\$\$|\$(?![\s$])((?:\\.|[^$\\\n])*?)(?<![\s\\])\$(?![\d$]))',
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final display = match[1] != null;
    final tex = (match[1] ?? match[2])!.trim();
    parser.addNode(
      md.Element.text(mathTag, tex)..attributes['display'] = '$display',
    );
    return true;
  }
}

/// A formula between `$$` lines:
///
/// ```text
/// $$
/// \int_0^1 x\,dx
/// $$
/// ```
class MathBlockSyntax extends md.BlockSyntax {
  /// Creates the syntax.
  const MathBlockSyntax();

  static final RegExp _start = RegExp(r'^ {0,3}\$\$(.*)$');

  @override
  RegExp get pattern => _start;

  @override
  md.Node parse(md.BlockParser parser) {
    final first = _start.firstMatch(parser.current.content)!.group(1)!.trim();
    parser.advance();
    final lines = <String>[];
    if (first.endsWith(r'$$')) {
      lines.add(first.substring(0, first.length - 2));
    } else {
      if (first.isNotEmpty) {
        lines.add(first);
      }
      while (!parser.isDone) {
        final line = parser.current.content;
        parser.advance();
        final end = line.trimRight();
        if (end.endsWith(r'$$')) {
          lines.add(end.substring(0, end.length - 2));
          break;
        }
        lines.add(line);
      }
    }
    return md.Element.text(mathBlockTag, lines.join('\n').trim());
  }
}

/// Wraps every table in a [tableTag] element and leaves its content as it
/// was parsed.
class ScrollTableSyntax extends md.TableSyntax {
  /// Creates the syntax.
  const ScrollTableSyntax();

  @override
  md.Node? parse(md.BlockParser parser) {
    final table = super.parse(parser);
    return table == null ? null : md.Element(tableTag, [table]);
  }
}

/// Counts the headings of each document being parsed, so every heading gets
/// its own id: the first `Practice` is `practice`, the next `practice-1`
/// (GitHub's rule). Keyed by the parser's document, which is new for every
/// parse.
final Expando<Map<String, int>> _headingCounts = Expando('heading counts');

/// The attribute that marks the first heading of a document.
const String firstHeadingAttribute = 'data-first-heading';

md.Element _uniqueHeading(md.BlockParser parser, md.Element heading) {
  final counts = _headingCounts[parser.document] ??= <String, int>{};
  if (counts.isEmpty) {
    heading.attributes[firstHeadingAttribute] = 'true';
  }
  final base = heading.generatedId ?? '';
  final seen = counts[base] = (counts[base] ?? 0) + 1;
  if (seen > 1) {
    heading.generatedId = '$base-${seen - 1}';
  }
  return heading;
}

/// An ATX heading (`# Title`) with an id that is unique in its document.
class UniqueHeaderSyntax extends md.HeaderWithIdSyntax {
  /// Creates the syntax.
  const UniqueHeaderSyntax();

  @override
  md.Node parse(md.BlockParser parser) =>
      _uniqueHeading(parser, super.parse(parser) as md.Element);
}

/// A setext heading (`Title` over `===`) with an id that is unique in its
/// document.
class UniqueSetextHeaderSyntax extends md.SetextHeaderWithIdSyntax {
  /// Creates the syntax.
  const UniqueSetextHeaderSyntax();

  @override
  md.Node parse(md.BlockParser parser) =>
      _uniqueHeading(parser, super.parse(parser) as md.Element);
}

/// A raw HTML block, kept as visible text in a code block.
///
/// Flutter Markdown drops block-level text that has no element around it, so
/// an HTML block would vanish without a trace. This turns it into a code
/// block of its own characters: nothing is parsed as markup, and nothing is
/// silently hidden (V4-SEC-03, README-003).
class VisibleHtmlBlockSyntax extends md.HtmlBlockSyntax {
  /// Creates the syntax.
  const VisibleHtmlBlockSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    final text = parseChildLines(parser)
        .map((line) => line.content)
        .join('\n')
        .trimRight();
    return md.Element('pre', [md.Element.text('code', text)]);
  }
}

/// GitHub-flavoured Markdown with the app's math and table syntaxes.
///
/// Raw HTML is never parsed into elements: inline tags stay text in the
/// parser, and block HTML becomes a code block of its own characters
/// ([VisibleHtmlBlockSyntax]), so `<script>` shows as what it is made of
/// (V4-SEC-03).
md.ExtensionSet lectaleExtensionSet() {
  final github = md.ExtensionSet.gitHubFlavored;
  return md.ExtensionSet(
    [
      const VisibleHtmlBlockSyntax(),
      const MathBlockSyntax(),
      const ScrollTableSyntax(),
      // These give each heading an id, which `#links` scroll to.
      const UniqueHeaderSyntax(),
      const UniqueSetextHeaderSyntax(),
      ...github.blockSyntaxes.where((syntax) => syntax is! md.TableSyntax),
    ],
    [MathInlineSyntax(), ...github.inlineSyntaxes],
  );
}
