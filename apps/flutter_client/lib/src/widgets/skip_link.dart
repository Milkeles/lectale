import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';

/// A link that jumps keyboard and screen-reader users past the top bar to
/// the page's main content (WCAG 2.2 2.4.1 Bypass Blocks, A11Y-001).
///
/// It stays out of sight until it takes focus, then appears with the focus
/// ring. Activating it moves focus to [target]. Built from litse-ui
/// foundations only, so it can move into litse-ui, which has no skip link.
class SkipLink extends StatefulWidget {
  /// Creates a skip link that shows [label] and moves focus to [target].
  const SkipLink({required this.label, required this.target, super.key});

  /// The link text, such as "Skip to main content".
  final String label;

  /// The focus node of the main content.
  final FocusNode target;

  @override
  State<SkipLink> createState() => _SkipLinkState();
}

class _SkipLinkState extends State<SkipLink> {
  // Far enough above the window to clear any text size.
  static const double _hiddenOffset = -400;

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final colors = theme.colors;
    final style = theme.style;
    final radius = BorderRadius.circular(style.radiusMedium);
    // The move is outside the pressable on purpose: a pressable's hit area
    // stays where it was laid out, so moving only its content would leave an
    // invisible target over the top bar.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Transform.translate(
        // Offscreen until focused; focus still reaches it.
        offset: _focused ? Offset.zero : const Offset(0, _hiddenOffset),
        // One node that is a focusable link named by its visible text.
        child: MergeSemantics(
          child: Semantics(
            link: true,
            child: DcPressable(
              onPressed: widget.target.requestFocus,
              isButton: false,
              builder: (context, states, _) => DcFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: radius,
                    border: Border.all(color: colors.border),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: style.controlHeights.medium,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: style.space(4),
                        vertical: style.space(2.5),
                      ),
                      child: Text(
                        widget.label,
                        style: theme.typography.label.copyWith(
                          color: colors.cardForeground,
                        ),
                      ),
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
