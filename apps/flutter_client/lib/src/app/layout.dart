import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';

/// Window widths where the layout changes (`docs/ux/inventory.md`,
/// Breakpoints). They are set by the reading text, not by device names.
abstract final class Breakpoints {
  /// Under this width the gutter is compact and controls stack.
  static const double compact = 600;

  /// The reading size in dp at 100 percent text, the unit of the 32 em
  /// reading column.
  static const double readingEm = 18;

  /// The window width where the wide layout begins: gutter, 272 dp pane,
  /// gutter, a 32 em text column and a closing gutter. 956 dp at 100 percent
  /// text, 1532 dp at 200 percent.
  static double wide(BuildContext context) {
    final em = MediaQuery.textScalerOf(context).scale(readingEm);
    final gutter = DcTheme.of(context).style.space(8);
    return gutter + 272 + gutter + 32 * em + gutter;
  }
}

/// The space between the window edge and the page content: 18 dp under
/// 600 dp, 36 dp from there.
double pageGutter(BuildContext context) {
  final style = DcTheme.of(context).style;
  return MediaQuery.sizeOf(context).width < Breakpoints.compact
      ? style.space(4)
      : style.space(8);
}

/// Whether the window is at the wide threshold.
bool isWideWindow(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.wide(context);
