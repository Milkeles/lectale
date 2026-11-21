import 'package:flutter/widgets.dart';

/// The Ribbon Cut mark: a page with a bookmark cut into its top edge.
///
/// Drawn from the same path as `docs/ux/brand/logo-01-ribbon-cut-mulberry.svg`
/// (64-unit grid), so the app needs no SVG parser for a single shape. The
/// mark is decorative and excluded from semantics; the wordmark beside it
/// names the bar.
class LectaleMark extends StatelessWidget {
  /// Creates the mark at [size] logical pixels in [color].
  const LectaleMark({required this.color, required this.size, super.key});

  /// The fill, from the app's brand role, so dark and high-contrast themes
  /// keep the mark legible.
  final Color color;

  /// Width and height of the square the mark is drawn in.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _MarkPainter(color)),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  // M8 4H20V36L28 28L36 36V4C47 4 56 13 56 24V60H8Z
  static final Path _path = Path()
    ..moveTo(8, 4)
    ..lineTo(20, 4)
    ..lineTo(20, 36)
    ..lineTo(28, 28)
    ..lineTo(36, 36)
    ..lineTo(36, 4)
    ..cubicTo(47, 4, 56, 13, 56, 24)
    ..lineTo(56, 60)
    ..lineTo(8, 60)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 64, size.height / 64)
      ..drawPath(_path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
