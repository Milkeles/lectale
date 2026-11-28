import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';

/// An underlined link that sits inside a line of text, takes keyboard focus
/// and shows the gold focus ring.
///
/// Flutter's text recognizers are pointer-only, so links in course text are
/// widgets placed in the line with `WidgetSpan` (WCAG 2.1.1, 2.4.7). The
/// hit area is at least 24 dp tall (2.5.8). [semanticLabel] carries where
/// the link goes, such as "{text}, opens in your browser".
class InlineLink extends StatelessWidget {
  /// Creates a link that shows [text] and runs [onPressed].
  const InlineLink({
    required this.text,
    required this.semanticLabel,
    required this.onPressed,
    required this.style,
    super.key,
  });

  /// The visible text.
  final String text;

  /// The accessible name; starts with [text] (WCAG 2.5.3).
  final String semanticLabel;

  /// Follows the link.
  final VoidCallback onPressed;

  /// The text style, already in the link color.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DcTheme.of(context).style.radiusSmall);
    // A 2 dp inset keeps the focus ring off the text that follows the link.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MergeSemantics(
        child: Semantics(
          link: true,
          label: semanticLabel,
          child: DcPressable(
            onPressed: onPressed,
            isButton: false,
            mouseCursor: SystemMouseCursors.click,
            builder: (context, states, _) => DcFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: ExcludeSemantics(
                  child: Text(
                    text,
                    style: style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: style.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A link's place in a line of text: a [WidgetSpan] that stays on the
/// baseline of the words around it.
InlineSpan inlineLinkSpan(InlineLink link) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: link,
);
