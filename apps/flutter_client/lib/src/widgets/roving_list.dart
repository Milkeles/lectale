import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A list that is one tab stop with roving focus: Tab enters it on the
/// selected row, Up and Down move, Home and End jump, Enter or Space opens,
/// and Tab leaves it (`docs/ux/inventory.md`, Keyboard: every screen).
///
/// Contents and "In this lesson" use it. Rows that are not [isNavigable],
/// such as module headings, are skipped by the keys. A pointer can tap any
/// navigable row, so everything a pointer does a keyboard does.
class RovingList extends StatefulWidget {
  /// Creates the list of [itemCount] rows drawn by [itemBuilder].
  const RovingList({
    required this.itemCount,
    required this.selectedIndex,
    required this.itemBuilder,
    required this.onActivate,
    this.isNavigable,
    this.focusNode,
    this.revealIndex,
    super.key,
  });

  /// How many rows there are.
  final int itemCount;

  /// The row that is open now. Tab enters the list here.
  final int selectedIndex;

  /// Draws row `index`. `active` is true for the row the keyboard is on,
  /// while the list has focus from the keyboard: draw the focus ring then.
  final Widget Function(BuildContext context, int index, {required bool active})
  itemBuilder;

  /// Opens row `index`.
  final ValueChanged<int> onActivate;

  /// Whether row `index` can be reached by the keys and tapped. Defaults to
  /// every row.
  final bool Function(int index)? isNavigable;

  /// The list's focus node, so a screen can move focus into it.
  final FocusNode? focusNode;

  /// A row to scroll into view, instantly and only if it is out of view,
  /// when the list first appears (the ribbon row, on a lesson change).
  final int? revealIndex;

  @override
  State<RovingList> createState() => _RovingListState();
}

class _RovingListState extends State<RovingList> {
  late final FocusNode _ownNode = FocusNode(debugLabel: 'roving list');
  late int _active = widget.selectedIndex;
  bool _ring = false;
  final Map<int, GlobalKey> _keys = {};

  FocusNode get _node => widget.focusNode ?? _ownNode;

  bool _navigable(int index) => widget.isNavigable?.call(index) ?? true;

  @override
  void initState() {
    super.initState();
    _node.onKeyEvent = _onKey;
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
    _ring =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final reveal = widget.revealIndex;
    if (reveal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reveal(reveal);
        }
      });
    }
  }

  @override
  void didUpdateWidget(RovingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.onKeyEvent = null;
      _node.onKeyEvent = _onKey;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex && !_node.hasFocus) {
      _active = widget.selectedIndex;
    }
  }

  // The ring shows for keyboard focus only, as every control draws it.
  void _onHighlightMode(FocusHighlightMode mode) {
    if (mounted) {
      setState(() => _ring = mode == FocusHighlightMode.traditional);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    widget.focusNode?.onKeyEvent = null;
    _ownNode.dispose();
    super.dispose();
  }

  int? _step(int from, int delta) {
    var index = from + delta;
    while (index >= 0 && index < widget.itemCount) {
      if (_navigable(index)) {
        return index;
      }
      index += delta;
    }
    return null;
  }

  void _reveal(int index) {
    final context = _keys[index]?.currentContext;
    final viewport = context == null
        ? null
        : Scrollable.maybeOf(context)?.context.findRenderObject();
    // A list in a route that is still being built has nothing to scroll yet.
    final ready = viewport is RenderBox && viewport.hasSize;
    if (context != null && ready) {
      // Instant, and only as far as needed to keep the row in view.
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  void _moveTo(int? index) {
    if (index == null) {
      return;
    }
    setState(() => _active = index);
    _reveal(index);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveTo(_step(_active, 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveTo(_step(_active, -1));
    } else if (key == LogicalKeyboardKey.home) {
      _moveTo(_step(-1, 1));
    } else if (key == LogicalKeyboardKey.end) {
      _moveTo(_step(widget.itemCount, -1));
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      if (_navigable(_active)) {
        widget.onActivate(_active);
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      // The rows carry the focus semantics: the focused row is the node a
      // screen reader announces, not an unnamed wrapper around the list.
      includeSemantics: false,
      onFocusChange: (focused) {
        setState(() {
          if (focused) {
            _active = widget.selectedIndex;
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.itemCount; i++)
            KeyedSubtree(
              key: _keys.putIfAbsent(i, GlobalKey.new),
              child: _navigable(i)
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // The row's own semantics carry the tap action.
                      excludeFromSemantics: true,
                      onTap: () {
                        setState(() => _active = i);
                        widget.onActivate(i);
                      },
                      child: widget.itemBuilder(
                        context,
                        i,
                        active: _ring && _node.hasFocus && i == _active,
                      ),
                    )
                  : widget.itemBuilder(context, i, active: false),
            ),
        ],
      ),
    );
  }
}
