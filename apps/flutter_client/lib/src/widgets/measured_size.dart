import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reports the size of [child] after each layout in which it changed.
///
/// The Contents bar and the top bar change height with the text size, and
/// the sticky bar and the pane are positioned from those heights. The
/// callback runs after the frame, so it may call `setState`.
class MeasuredSize extends SingleChildRenderObjectWidget {
  /// Creates the widget.
  const MeasuredSize({
    required this.onChanged,
    required Widget super.child,
    super.key,
  });

  /// Called with the new size.
  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasuredSize(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMeasuredSize renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

/// The render object of [MeasuredSize].
class RenderMeasuredSize extends RenderProxyBox {
  /// Creates the render object.
  RenderMeasuredSize(this.onChanged);

  /// Called with the new size.
  ValueChanged<Size> onChanged;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final reported = size;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) {
          onChanged(reported);
        }
      });
    }
  }
}
