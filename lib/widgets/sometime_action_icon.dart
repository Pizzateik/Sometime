import 'package:flutter/material.dart';

enum SometimeActionGlyph { plus, arrowUp }

class SometimeActionIconBox extends StatelessWidget {
  const SometimeActionIconBox({
    required this.glyph,
    required this.size,
    required this.color,
    this.dimension = 32,
    super.key,
  });

  final SometimeActionGlyph glyph;
  final double size;
  final Color color;
  final double dimension;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimension,
    child: Center(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SometimeActionIconPainter(glyph: glyph, color: color),
        ),
      ),
    ),
  );
}

class _SometimeActionIconPainter extends CustomPainter {
  const _SometimeActionIconPainter({required this.glyph, required this.color});

  static const _viewBox = 256.0;
  static const _stroke = 16.0;

  final SometimeActionGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = _stroke * scale;

    switch (glyph) {
      case SometimeActionGlyph.plus:
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        final arm = 96 * scale;
        final radius = Radius.circular(strokeWidth / 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              center.dx - arm,
              center.dy - strokeWidth / 2,
              center.dx + arm,
              center.dy + strokeWidth / 2,
            ),
            radius,
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              center.dx - strokeWidth / 2,
              center.dy - arm,
              center.dx + strokeWidth / 2,
              center.dy + arm,
            ),
            radius,
          ),
          paint,
        );
      case SometimeActionGlyph.arrowUp:
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final path = Path()
          ..moveTo(center.dx, 24 * scale)
          ..lineTo(center.dx, 232 * scale)
          ..moveTo(40 * scale, 112 * scale)
          ..lineTo(center.dx, 24 * scale)
          ..lineTo(216 * scale, 112 * scale);
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SometimeActionIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
