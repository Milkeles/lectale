import 'package:flutter/widgets.dart';

/// The bookmark ribbon: the memorable element of Lectale
/// (`docs/ux/token-plan.md`). It is 8 dp wide and as tall as the row it
/// marks, with the logo's swallowtail cut into its lower end.
///
/// It is decoration for the eye only. The row it marks says "current" or
/// "last opened" in its accessible name, so nothing depends on seeing it.
/// Gold is the theme's `primary`; pass it in.
class Ribbon extends StatelessWidget {
  /// Creates the ribbon in [color].
  const Ribbon({required this.color, super.key});

  /// The ribbon's color, the theme's `primary`.
  final Color color;

  /// The ribbon's width in dp.
  static const double width = 8;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      child: CustomPaint(painter: _RibbonPainter(color)),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final notch = size.width;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - notch)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => oldDelegate.color != color;
}
