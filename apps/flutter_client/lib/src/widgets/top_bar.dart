import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/widgets/lectale_mark.dart';

/// The bar at the top of every screen: the mark and the wordmark.
///
/// With [onHome] the whole bar is one link, named [homeLabel], that opens the
/// start screen. Without it the bar is plain text, as on the start screen
/// itself, where a link to the current page would do nothing. The mark is
/// decorative: the wordmark or [homeLabel] names the bar.
///
/// Built from litse-ui foundations only, so it can move into litse-ui,
/// which has no app bar.
class TopBar extends StatelessWidget {
  /// Creates the bar.
  const TopBar({
    required this.wordmark,
    required this.markColor,
    this.homeLabel,
    this.onHome,
    super.key,
  }) : assert(
         (onHome == null) == (homeLabel == null),
         'A home link needs both onHome and homeLabel.',
       );

  /// The product name, set beside the mark.
  final String wordmark;

  /// The color of the mark, from the app's brand role.
  final Color markColor;

  /// The accessible name of the link, such as "Lectale home".
  final String? homeLabel;

  /// Opens the start screen; null makes the bar plain text.
  final VoidCallback? onHome;

  /// The mark's size. The mark is a vector path, so it is drawn at exactly
  /// this size and no bitmap is decoded.
  static const double markSize = 28;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final colors = theme.colors;
    final style = theme.style;
    // As a link the label below names the bar, so the wordmark is not read
    // again on top of it.
    final isLink = onHome != null;
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: style.space(2),
      children: [
        LectaleMark(color: markColor, size: markSize),
        ExcludeSemantics(
          excluding: isLink,
          child: Text(
            wordmark,
            style: theme.typography.title.copyWith(
              color: colors.foreground,
              fontWeight: theme.typography.medium,
            ),
          ),
        ),
      ],
    );
    final padding = EdgeInsets.symmetric(vertical: style.space(2));
    final minHeight = style.controlHeights.medium;

    if (onHome == null) {
      return Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: brand,
          ),
        ),
      );
    }
    final radius = BorderRadius.circular(style.radiusMedium);
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        // A link is only as wide as its content, so the rest of the bar
        // does not act as a target.
        widthFactor: 1,
        child: MergeSemantics(
          child: Semantics(
            link: true,
            label: homeLabel,
            // No semanticLabel on the pressable: that would hide its focus
            // state from assistive technology.
            child: DcPressable(
              onPressed: onHome,
              isButton: false,
              builder: (context, states, _) => DcFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: brand,
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
