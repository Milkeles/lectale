import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A region that scrolls sideways and takes keyboard focus, so the arrow
/// keys scroll it and Tab leaves it (`docs/ux/inventory.md`, Keyboard: a
/// scroll region without controls of its own).
///
/// Code, wide tables and display formulas use it. The gold focus ring shows
/// around the visible window when focus arrived by keyboard. The region is
/// one focusable node named [semanticLabel], whose description is its
/// content.
class FocusScrollRegion extends StatefulWidget {
  /// Creates the region around [child], named [semanticLabel].
  const FocusScrollRegion({
    required this.semanticLabel,
    required this.child,
    super.key,
  });

  /// What the region is, such as "Code" or "Table".
  final String semanticLabel;

  /// The content, as wide as it needs to be.
  final Widget child;

  @override
  State<FocusScrollRegion> createState() => _FocusScrollRegionState();
}

class _FocusScrollRegionState extends State<FocusScrollRegion> {
  final ScrollController _controller = ScrollController();
  bool _focused = false;
  bool _keyboard =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    if (mounted) {
      setState(() => _keyboard = mode == FocusHighlightMode.traditional);
    }
  }

  /// Left and Right scroll by a line-height step, Home and End jump to the
  /// ends; every other key keeps its meaning (Up and Down scroll the page).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_controller.hasClients) {
      return KeyEventResult.ignored;
    }
    final position = _controller.position;
    final key = event.logicalKey;
    final double target;
    if (key == LogicalKeyboardKey.arrowRight) {
      target = position.pixels + _step;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      target = position.pixels - _step;
    } else if (key == LogicalKeyboardKey.home) {
      target = position.minScrollExtent;
    } else if (key == LogicalKeyboardKey.end) {
      target = position.maxScrollExtent;
    } else {
      return KeyEventResult.ignored;
    }
    _controller.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return KeyEventResult.handled;
  }

  static const double _step = 40;

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DcTheme.of(context).style;
    return DcFocusRing(
      visible: _focused && _keyboard,
      borderRadius: BorderRadius.circular(style.radiusMedium),
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        // The focus node sits inside the scroll view, so the arrow keys'
        // scroll action finds this view from the focused element.
        child: Focus(
          // The region's own node carries the name and the focus flag, so a
          // screen reader announces "Code, python" and not a line of code.
          includeSemantics: false,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: Semantics(
            container: true,
            focusable: true,
            focused: _focused,
            label: widget.semanticLabel,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
