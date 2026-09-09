import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashedDividerPainter(context.appColors.outline),
      ),
    );
  }
}

class _DashedDividerPainter extends CustomPainter {
  const _DashedDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset((x + dash).clamp(0.0, size.width), 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}
