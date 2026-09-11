import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class RecognizedTextField extends StatefulWidget {
  const RecognizedTextField({
    required this.controller,
    required this.ranges,
    required this.textStyle,
    required this.highlightColor,
    required this.child,
    this.highlightKey,
    super.key,
  });

  final TextEditingController controller;
  final List<TextRange> ranges;
  final TextStyle textStyle;
  final Color highlightColor;
  final Widget child;
  final Key? highlightKey;

  @override
  State<RecognizedTextField> createState() => _RecognizedTextFieldState();
}

class _RecognizedTextFieldState extends State<RecognizedTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late List<TextRange> _paintedRanges;
  bool _contractsToRight = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _paintedRanges = List.of(widget.ranges);
    _animation = AnimationController(
      vsync: this,
      duration: AppMotion.recognitionWave,
      reverseDuration: AppMotion.recognitionDismiss,
      value: widget.ranges.isEmpty ? 0 : 1,
    )..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _animation
      ..duration = _reduceMotion
          ? AppMotion.reducedFeedback
          : AppMotion.recognitionWave
      ..reverseDuration = _reduceMotion
          ? AppMotion.reducedFeedback
          : AppMotion.recognitionDismiss;
  }

  @override
  void didUpdateWidget(RecognizedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_rangesEqual(oldWidget.ranges, widget.ranges)) return;
    if (widget.ranges.isEmpty) {
      _contractsToRight = true;
      _animation.reverse(from: 1);
      return;
    }
    _contractsToRight = false;
    _paintedRanges = List.of(widget.ranges);
    _animation.forward(from: 0);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.ranges.isNotEmpty) {
      return;
    }
    setState(() => _paintedRanges = const []);
  }

  static bool _rangesEqual(List<TextRange> first, List<TextRange> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _animation
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) => CustomPaint(
                  key: widget.highlightKey,
                  painter: RecognizedTextHighlightPainter(
                    text: widget.controller.text,
                    ranges: _paintedRanges,
                    style: widget.textStyle,
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    color: widget.highlightColor,
                    progress: _animation.value,
                    curve: AppMotion.recognitionRevealCurve,
                    contractsToRight: _contractsToRight,
                    reduceMotion: _reduceMotion,
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

@visibleForTesting
class RecognizedTextHighlightPainter extends CustomPainter {
  const RecognizedTextHighlightPainter({
    required this.text,
    required this.ranges,
    required this.style,
    required this.textDirection,
    required this.textScaler,
    required this.color,
    required this.progress,
    required this.curve,
    required this.contractsToRight,
    required this.reduceMotion,
  });

  final String text;
  final List<TextRange> ranges;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Color color;
  final double progress;
  final Curve curve;
  final bool contractsToRight;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || ranges.isEmpty || progress <= 0 || size.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    final value = curve.transform(progress.clamp(0.0, 1.0));
    for (final range in ranges) {
      if (range.start < 0 || range.end > text.length || range.isCollapsed) {
        continue;
      }
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
        boxHeightStyle: BoxHeightStyle.tight,
      );
      for (final box in boxes) {
        final rect = Rect.fromLTRB(
          box.left,
          box.top,
          box.right,
          box.bottom,
        ).inflate(2).intersect(Offset.zero & size);
        if (rect.isEmpty) continue;
        _paintBox(canvas, rect, value);
      }
    }
  }

  void _paintBox(Canvas canvas, Rect rect, double value) {
    final radius = Radius.circular(5);
    if (reduceMotion) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color.withValues(alpha: color.a * value),
      );
      return;
    }
    if (contractsToRight) {
      final clip = Rect.fromLTRB(
        rect.left + rect.width * (1 - value),
        rect.top,
        rect.right,
        rect.bottom,
      );
      canvas.save();
      canvas.clipRect(clip);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color.withValues(alpha: color.a * value),
      );
      canvas.restore();
      return;
    }
    final clip = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width * value,
      rect.height,
    );
    canvas.save();
    canvas.clipRect(clip);
    final featherStart = (1 - 8 / clip.width).clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color, color, color.withValues(alpha: 0)],
        stops: [0, featherStart, 1],
      ).createShader(clip);
    if (value >= 0.995) paint.shader = null;
    if (value >= 0.995) paint.color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RecognizedTextHighlightPainter oldDelegate) =>
      oldDelegate.text != text ||
      !_sameRanges(oldDelegate.ranges, ranges) ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.contractsToRight != contractsToRight ||
      oldDelegate.reduceMotion != reduceMotion;

  static bool _sameRanges(List<TextRange> first, List<TextRange> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
