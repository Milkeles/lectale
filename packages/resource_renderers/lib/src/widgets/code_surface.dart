import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:resource_renderers/src/widgets/focus_scroll_region.dart';

/// Code or data on a Sand surface: Plex Mono, never wrapped, in a region the
/// keyboard can scroll. With [lineNumbers] a gutter counts the lines.
///
/// The gutter is hidden from assistive technology, so a screen reader reads
/// the code and not a column of numbers.
class CodeSurface extends StatelessWidget {
  /// Creates the surface for [code], named [semanticLabel] for assistive
  /// technology.
  const CodeSurface({
    required this.code,
    required this.semanticLabel,
    this.lineNumbers = false,
    this.header,
    super.key,
  });

  /// The text, without a final newline.
  final String code;

  /// What the region is called, such as "Code, python".
  final String semanticLabel;

  /// Whether to show a line-number gutter.
  final bool lineNumbers;

  /// A slim row attached above the code, inside the same surface: the
  /// language and Copy.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final text = theme.typography.code.copyWith(color: theme.colors.foreground);
    final count = '\n'.allMatches(code).length + 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(style.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          FocusScrollRegion(
            semanticLabel: semanticLabel,
            child: Padding(
              padding: EdgeInsets.all(style.space(3)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lineNumbers) ...[
                    ExcludeSemantics(
                      child: Text(
                        List.generate(count, (i) => '${i + 1}').join('\n'),
                        textAlign: TextAlign.end,
                        style: text.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    SizedBox(width: style.space(4)),
                  ],
                  Text(code, softWrap: false, style: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
