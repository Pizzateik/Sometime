import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class DissolvingTodo extends StatelessWidget {
  const DissolvingTodo({required this.child, required this.onEnd, super.key});
  final Widget child;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, const Duration(milliseconds: 240)),
    onEnd: onEnd,
    child: child,
    builder: (context, value, child) => CustomPaint(
      foregroundPainter: _DissolvePainter(value, context.appColors.secondary),
      child: Opacity(
        opacity: 1 - value,
        child: Transform.translate(
          offset: Offset(0, value * 6),
          child: Transform.scale(scale: 1 - value * 0.04, child: child),
        ),
      ),
    ),
  );
}

class _DissolvePainter extends CustomPainter {
  const _DissolvePainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: math.sin(progress * math.pi) * 0.45);
    for (var i = 0; i < 12; i++) {
      final x = size.width * (i + 0.5) / 12 + math.sin(i * 2) * progress * 9;
      final y =
          size.height * (0.25 + (i % 3) * 0.25) + math.cos(i) * progress * 10;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 2.5 * (1 - progress),
          height: 2.5 * (1 - progress),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DissolvePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
