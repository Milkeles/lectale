import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays out the lesson footer from the real widths of its buttons.
///
/// `next` is the primary action; `previous` is optional. When both full
/// labels fit on one line with `gap` between them, Previous sits at the start
/// edge and Next at the end. Otherwise they stack, Next first, `stackGap`
/// apart. Stacked buttons keep their own width, except on a phone
/// (`stretch`), where they fill the column. A lone Next follows the same
/// rule.
///
/// The choice is made by measuring each child's intrinsic width in the
/// current theme, so light and dark, and any text size, always pick the same
/// layout for the same labels (`docs/ux/screens/reader.md` §8).
class StepFooter extends MultiChildRenderObjectWidget {
  /// Creates the footer.
  StepFooter({
    required Widget next,
    required this.gap,
    required this.stackGap,
    required this.stretch,
    Widget? previous,
    super.key,
  }) : super(children: [next, ?previous]);

  /// The least space between Previous and Next side by side.
  final double gap;

  /// The space between stacked buttons.
  final double stackGap;

  /// Whether stacked or lone buttons fill the column.
  final bool stretch;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderStepFooter(
    gap: gap,
    stackGap: stackGap,
    stretch: stretch,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderStepFooter renderObject,
  ) {
    renderObject
      ..gap = gap
      ..stackGap = stackGap
      ..stretch = stretch
      ..textDirection = Directionality.of(context);
  }
}

class _FooterParentData extends ContainerBoxParentData<RenderBox> {
  // Only the inherited offset is used.
}

/// The render object of [StepFooter].
class RenderStepFooter extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FooterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FooterParentData> {
  /// Creates the render object.
  RenderStepFooter({
    required double gap,
    required double stackGap,
    required bool stretch,
    required TextDirection textDirection,
  }) {
    _gap = gap;
    _stackGap = stackGap;
    _stretch = stretch;
    _textDirection = textDirection;
  }

  double _gap = 0;
  double _stackGap = 0;
  bool _stretch = false;
  TextDirection _textDirection = TextDirection.ltr;

  /// The least gap side by side.
  double get gap => _gap;
  set gap(double value) {
    if (value != _gap) {
      _gap = value;
      markNeedsLayout();
    }
  }

  /// The gap between stacked buttons.
  double get stackGap => _stackGap;
  set stackGap(double value) {
    if (value != _stackGap) {
      _stackGap = value;
      markNeedsLayout();
    }
  }

  /// Whether buttons fill the column when stacked.
  bool get stretch => _stretch;
  set stretch(bool value) {
    if (value != _stretch) {
      _stretch = value;
      markNeedsLayout();
    }
  }

  /// The reading direction.
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value != _textDirection) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterParentData) {
      child.parentData = _FooterParentData();
    }
  }

  RenderBox get _next => firstChild!;
  RenderBox? get _previous => childAfter(_next);

  /// Whether the two buttons fit side by side in [width].
  bool _sideBySide(double width) {
    final previous = _previous;
    if (previous == null) {
      return false;
    }
    final needed =
        previous.getMaxIntrinsicWidth(double.infinity) +
        _gap +
        _next.getMaxIntrinsicWidth(double.infinity);
    return needed <= width;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final previous = _previous;
    final rtl = _textDirection == TextDirection.rtl;
    if (_sideBySide(width)) {
      previous!.layout(const BoxConstraints(), parentUsesSize: true);
      _next.layout(const BoxConstraints(), parentUsesSize: true);
      final height = math.max(previous.size.height, _next.size.height);
      (previous.parentData! as _FooterParentData).offset = Offset(
        rtl ? width - previous.size.width : 0,
        (height - previous.size.height) / 2,
      );
      (_next.parentData! as _FooterParentData).offset = Offset(
        rtl ? 0 : width - _next.size.width,
        (height - _next.size.height) / 2,
      );
      size = constraints.constrain(Size(width, height));
      return;
    }
    // Stacked, or a lone button: Next first.
    var y = 0.0;
    for (final child in [_next, ?previous]) {
      child.layout(
        _stretch
            ? BoxConstraints.tightFor(width: width)
            : BoxConstraints(maxWidth: width),
        parentUsesSize: true,
      );
      (child.parentData! as _FooterParentData).offset = Offset(
        rtl ? width - child.size.width : 0,
        y,
      );
      y += child.size.height + _stackGap;
    }
    size = constraints.constrain(Size(width, y - _stackGap));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _next.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    var total = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      total += child.getMaxIntrinsicHeight(width);
    }
    return total;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _next.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _next.getMaxIntrinsicWidth(height);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      Size(constraints.maxWidth, 0);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
