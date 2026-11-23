import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';

/// Tells `builder` whether a pointer is over its row, so a row that can be
/// opened looks like it can: it takes a light Sand fill under the pointer.
///
/// Hover is a cue for pointer users only; keyboard focus has its own ring and
/// touch has none, so nothing depends on it.
class HoverFill extends StatefulWidget {
  /// Creates the wrapper.
  const HoverFill({required this.builder, super.key});

  /// Builds the row; `hovered` is true while a pointer is over it.
  final Widget Function(BuildContext context, {required bool hovered}) builder;

  @override
  State<HoverFill> createState() => _HoverFillState();
}

class _HoverFillState extends State<HoverFill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, hovered: _hovered),
  );
}

/// The fill of a row that can be opened but is not the one on screen.
Color hoverColor(DcThemeData theme) =>
    theme.colors.muted.withValues(alpha: 0.6);
