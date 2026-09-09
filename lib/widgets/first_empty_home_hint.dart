import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class FirstEmptyHomeHint extends StatelessWidget {
  const FirstEmptyHomeHint({
    required this.label,
    required this.textAnimation,
    required this.arrowAnimation,
    required this.buttonRect,
    super.key,
  });

  final String label;
  final Animation<double> textAnimation;
  final Animation<double> arrowAnimation;
  final Rect? buttonRect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _HintLayout(
          size: constraints.biggest,
          buttonRect: buttonRect,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: layout.textLeft,
              top: layout.textTop,
              width: layout.textWidth,
              child: FadeTransition(
                opacity: textAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(textAnimation),
                  child: Semantics(
                    label: label,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (layout.arrowStart != null && layout.arrowEnd != null)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: arrowAnimation,
                    builder: (context, _) => CustomPaint(
                      painter: _DottedArrowPainter(
                        start: layout.arrowStart!,
                        end: layout.arrowEnd!,
                        color: colors.secondary.withValues(alpha: 0.68),
                        progress: arrowAnimation.value,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HintLayout {
  _HintLayout({required Size size, required Rect? buttonRect}) {
    final target = buttonRect == null
        ? Offset(size.width * 0.78, size.height * 0.84)
        : Offset(
            buttonRect.left - 8,
            buttonRect.top + buttonRect.height * 0.45,
          );
    final gap = (size.height * 0.22).clamp(112.0, 180.0).toDouble();
    final textWidth = math.min(210.0, math.max(0.0, size.width - 48));
    final halfTextWidth = textWidth / 2;
    final textX = (target.dx - 116).clamp(
      halfTextWidth + 16,
      math.max(halfTextWidth + 16, size.width - halfTextWidth - 16),
    );
    final maxTextY = math.max(0.0, target.dy - 72);
    final minTextY = math.min(size.height * 0.48, maxTextY);
    final textY = (target.dy - gap).clamp(minTextY, maxTextY);
    final textCenter = Offset(textX.toDouble(), textY.toDouble());

    this.textWidth = textWidth;
    textLeft = textCenter.dx - halfTextWidth;
    textTop = textCenter.dy - 12;
    if (buttonRect == null) {
      arrowStart = null;
      arrowEnd = null;
    } else {
      arrowStart = Offset(
        textCenter.dx + halfTextWidth * 0.24,
        textCenter.dy + 16,
      );
      arrowEnd = target;
    }
  }

  late final double textWidth;
  late final double textLeft;
  late final double textTop;
  late final Offset? arrowStart;
  late final Offset? arrowEnd;
}

class _DottedArrowPainter extends CustomPainter {
  const _DottedArrowPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.progress,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + (end.dx - start.dx) * 0.72,
        start.dy + (end.dy - start.dy) * 0.28,
        end.dx - (end.dx - start.dx).abs() * 0.55,
        end.dy - (end.dy - start.dy) * 0.28,
        end.dx,
        end.dy,
      );
    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) return;
    final length = metric.length * progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const dash = 3.0;
    const gap = 5.0;
    for (var distance = 0.0; distance < length; distance += dash + gap) {
      canvas.drawPath(
        metric.extractPath(distance, math.min(distance + dash, length)),
        paint,
      );
    }

    if (progress < 0.98 || length == 0) return;
    final tangent = metric.getTangentForOffset(metric.length);
    if (tangent == null) return;
    final tangentLength = tangent.vector.distance;
    if (tangentLength == 0) return;
    final direction = tangent.vector / tangentLength;
    final perpendicular = Offset(-direction.dy, direction.dx);
    final tip = tangent.position;
    final left = tip - direction * 8 + perpendicular * 4.5;
    final right = tip - direction * 8 - perpendicular * 4.5;
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(tip, right, paint);
  }

  @override
  bool shouldRepaint(_DottedArrowPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress;
}
