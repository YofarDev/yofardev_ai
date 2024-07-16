import 'package:flutter/material.dart';

class GlowingLaser extends CustomPainter {
  final Color color;
  final double radius;

  GlowingLaser({
    this.color = Colors.red,
    this.radius = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 2);

    // Draw the outer glow
    final Paint paint = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
    canvas.drawCircle(center, radius * 4, paint);

    // Draw the middle glow
    paint.color = color.withOpacity(0.25);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
    canvas.drawCircle(center, radius * 1.5, paint);

    // // Draw the inner dot
    // paint.color = color.withOpacity(0.8);
    // paint.maskFilter = null;
    // canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
