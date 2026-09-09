import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/app_theme.dart';
import 'pressable.dart';

class SpaceManagementTutorial extends StatelessWidget {
  const SpaceManagementTutorial({
    required this.onDismiss,
    this.arrowTargetBounds,
    this.measurementKey,
    super.key,
  });

  final VoidCallback onDismiss;
  final Rect? arrowTargetBounds;
  final Key? measurementKey;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.appColors;
    return Stack(
      key: measurementKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SpaceTutorialArrowPainter(
                color: colors.secondary.withValues(alpha: 0.68),
                targetBounds: arrowTargetBounds,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Container(
            decoration: BoxDecoration(
              color: colors.creationSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.activeBorder, width: 0.7),
              boxShadow: Theme.of(context).brightness == Brightness.light
                  ? [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 60),
                    child: Semantics(
                      container: true,
                      label:
                          '${strings.spaceManagementTutorialTitle}. ${strings.spaceManagementTutorialBody}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.spaceManagementTutorialTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.spaceManagementTutorialBody,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colors.secondary,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Pressable(
                    label: strings.gotIt,
                    onPressed: onDismiss,
                    radius: 10,
                    builder: (context, _) => ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 92),
                      child: SizedBox(
                        height: AppSpace.touch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: Text(
                              strings.gotIt,
                              maxLines: 1,
                              softWrap: false,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpaceTutorialArrowPainter extends CustomPainter {
  const _SpaceTutorialArrowPainter({required this.color, this.targetBounds});

  final Color color;
  final Rect? targetBounds;

  @override
  void paint(Canvas canvas, Size size) {
    final targetBounds = this.targetBounds;
    if (targetBounds == null) return;
    const targetPadding = 8.0;
    const pathClearance = 2.0;
    final forbiddenBounds = targetBounds.inflate(targetPadding);
    final end = Offset(
      forbiddenBounds.center.dx.clamp(12.0, math.max(12.0, size.width - 12.0)),
      forbiddenBounds.bottom + pathClearance,
    );
    final leftRoom = math.max(0.0, end.dx - 28);
    final rightRoom = math.max(0.0, size.width - 28 - end.dx);
    final bend = math.min(64.0, math.max(leftRoom, rightRoom));
    final start = Offset(
      end.dx + (rightRoom >= leftRoom ? bend : -bend),
      math.max(30.0, end.dy + 18),
    );
    final verticalDistance = start.dy - end.dy;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx,
        start.dy - verticalDistance * 0.42,
        end.dx,
        end.dy + verticalDistance * 0.32,
        end.dx,
        end.dy,
      );
    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const dash = 3.0;
    const gap = 5.0;
    const arrowheadLength = 8.0;
    final shaftLength = math.max(0.0, metric.length - arrowheadLength);
    for (
      var distance = 0.0;
      distance + dash <= shaftLength;
      distance += dash + gap
    ) {
      canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
    }
    final tangent = metric.getTangentForOffset(metric.length);
    if (tangent == null) return;
    final arrowDirection = tangent.vector / tangent.vector.distance;
    final perpendicular = Offset(-arrowDirection.dy, arrowDirection.dx);
    final tip = tangent.position;
    final arrowheadBase = tip - arrowDirection * arrowheadLength;
    final arrowhead = Path()
      ..moveTo(
        (arrowheadBase + perpendicular * 4.5).dx,
        (arrowheadBase + perpendicular * 4.5).dy,
      )
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
        (arrowheadBase - perpendicular * 4.5).dx,
        (arrowheadBase - perpendicular * 4.5).dy,
      );
    canvas.drawPath(arrowhead, paint);
  }

  @override
  bool shouldRepaint(_SpaceTutorialArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.targetBounds != targetBounds;
}
