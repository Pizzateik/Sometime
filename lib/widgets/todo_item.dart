import 'dart:async';

import '../app/sometime_icons.dart';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../app/task_details_formatter.dart';
import '../models/todo.dart';
import '../services/app_haptics.dart';
import 'pin_action.dart';
import 'pressable.dart';
import 'task_metadata_pill.dart';

class TodoItem extends StatefulWidget {
  const TodoItem({
    required this.todo,
    required this.onToggle,
    this.active = false,
    this.dragging = false,
    this.deleteHovered = false,
    this.spaceSwitchArmed = false,
    this.spaceSwitchProgress = 0,
    this.onActivate,
    this.onDeactivate,
    this.onEdit,
    this.onPin,
    this.tutorialLink,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
    super.key,
  });
  final Todo todo;
  final VoidCallback onToggle;
  final bool active, dragging, deleteHovered, spaceSwitchArmed;
  final double spaceSwitchProgress;
  final VoidCallback? onActivate,
      onDeactivate,
      onEdit,
      onDragStarted,
      onDragEnd;
  final Future<bool> Function()? onPin;
  final LayerLink? tutorialLink;
  final ValueChanged<Offset>? onDragUpdate;

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> with TickerProviderStateMixin {
  late final _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _deleteWiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  final editKey = GlobalKey();
  bool editPointer = false;
  Timer? _pinPulseTimer;
  bool _pinPulse = false;

  @override
  void didUpdateWidget(TodoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.todo.isComplete && widget.todo.isComplete) {
      AppHaptics.completion();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _celebration.forward(from: 0);
      }
    } else if (!widget.todo.isComplete) {
      _celebration.reset();
    }
    if (!oldWidget.deleteHovered && widget.deleteHovered) {
      _deleteWiggle.repeat();
    } else if (oldWidget.deleteHovered && !widget.deleteHovered) {
      _deleteWiggle.stop();
      _deleteWiggle.reset();
    }
  }

  @override
  void dispose() {
    _pinPulseTimer?.cancel();
    _celebration.dispose();
    _deleteWiggle.dispose();
    super.dispose();
  }

  void _pinSucceeded(bool pinned) {
    if (!pinned || !mounted) return;
    _pinPulseTimer?.cancel();
    setState(() => _pinPulse = true);
    _pinPulseTimer = Timer(const Duration(milliseconds: 130), () {
      if (mounted) setState(() => _pinPulse = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final todo = widget.todo;
    final active = widget.active;
    final dragging = widget.dragging;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onToggle = widget.onToggle;
    final onDeactivate = widget.onDeactivate;
    final onActivate = widget.onActivate;
    final onEdit = widget.onEdit;
    final onDragStarted = widget.onDragStarted;
    final onDragUpdate = widget.onDragUpdate;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final switchProgress = widget.spaceSwitchArmed && reduceMotion
        ? 0.7
        : widget.spaceSwitchProgress.clamp(0.0, 1.0);
    final item = Listener(
      onPointerDown: (event) {
        final box = editKey.currentContext?.findRenderObject();
        editPointer =
            box is RenderBox &&
            (box.localToGlobal(Offset.zero) & box.size).contains(
              event.position,
            );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: active
            ? (details) {
                if (editPointer) return;
                onDragStarted?.call();
                onDragUpdate?.call(details.globalPosition);
              }
            : null,
        onHorizontalDragStart: active
            ? (details) {
                if (editPointer) return;
                onDragStarted?.call();
                onDragUpdate?.call(details.globalPosition);
              }
            : null,
        child: Pressable(
          label: todo.title,
          isButton: false,
          hapticOnTap: false,
          checked: todo.isComplete,
          onPressed: active ? onDeactivate : onToggle,
          onLongPress: todo.isComplete ? null : onActivate,
          excludeChildSemantics: false,
          scale: 0.98,
          radius: 12,
          builder: (context, state) => TweenAnimationBuilder<double>(
            tween: Tween(
              begin: todo.isComplete ? 1 : 0,
              end: todo.isComplete ? 1 : 0,
            ),
            duration: AppMotion.duration(
              context,
              const Duration(milliseconds: 240),
            ),
            curve: Curves.easeOut,
            builder: (context, progress, _) => AnimatedBuilder(
              animation: _deleteWiggle,
              builder: (context, child) => Transform.rotate(
                angle: widget.deleteHovered
                    ? math.sin(_deleteWiggle.value * math.pi * 2) * 0.006
                    : 0,
                child: child,
              ),
              child: AnimatedScale(
                scale: _pinPulse ? 0.98 : 1,
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 100),
                ),
                curve: Curves.easeOutCubic,
                child: Transform.scale(
                  scale: dragging && dark ? 1.025 : 1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.duration(
                          context,
                          const Duration(milliseconds: 150),
                        ),
                        decoration: active || dragging
                            ? BoxDecoration(
                                color: _pinPulse
                                    ? Color.alphaBlend(
                                        colors.accent.withValues(alpha: 0.04),
                                        colors.taskSurface,
                                      )
                                    : dragging && dark
                                    ? Color.alphaBlend(
                                        colors.ink.withValues(alpha: 0.035),
                                        colors.taskSurface,
                                      )
                                    : colors.taskSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: widget.deleteHovered
                                    ? Border.all(
                                        color: context.appColors.destructive,
                                        width: 1.2,
                                      )
                                    : Border.all(
                                        color: _pinPulse
                                            ? Color.lerp(
                                                colors.activeBorder,
                                                colors.accent,
                                                0.3,
                                              )!
                                            : colors.activeBorder,
                                        width: 0.7,
                                      ),
                                boxShadow: dragging && dark
                                    ? [
                                        BoxShadow(
                                          color: colors.shadow.withValues(
                                            alpha: 0.22,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : dark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: colors.shadow.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                              )
                            : null,
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: AppSpace.touch,
                              height: 40,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: AppMotion.duration(
                                    context,
                                    AppMotion.color,
                                  ),
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween(begin: 0.82, end: 1.0)
                                              .animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: AppMotion.curve,
                                                ),
                                              ),
                                          child: child,
                                        ),
                                      ),
                                  child: active
                                      ? Icon(
                                          SometimeIcons.dotsSixVertical,
                                          key: ValueKey(
                                            'move-handle-${todo.id}',
                                          ),
                                          size: 22,
                                          color: colors.secondary,
                                        )
                                      : AnimatedBuilder(
                                          key: ValueKey('checkbox-${todo.id}'),
                                          animation: _celebration,
                                          builder: (context, _) => CustomPaint(
                                            size: const Size.square(21),
                                            painter: _CompletionPainter(
                                              progress: progress,
                                              celebration: _celebration.value,
                                              outline: colors.outline,
                                              fill: colors.accent,
                                              check: colors.onAccent,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CompletionTitle(
                                    title: todo.title,
                                    progress: progress,
                                    style: typography.taskTitle.copyWith(
                                      color: Color.lerp(
                                        colors.text,
                                        colors.secondary,
                                        progress,
                                      ),
                                    ),
                                  ),
                                  if (todo.details.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        todo.details.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: typography.taskDescription,
                                      ),
                                    ),
                                  if (taskDetailsLabel(
                                        context,
                                        todo.details,
                                      ).isNotEmpty ||
                                      (todo.isPinned &&
                                          !kIsWeb &&
                                          defaultTargetPlatform ==
                                              TargetPlatform.android))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: TaskMetadataPill(
                                        details: todo.details,
                                        isPinned: todo.isPinned,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            AnimatedSize(
                              duration: AppMotion.duration(
                                context,
                                AppMotion.color,
                              ),
                              curve: AppMotion.curve,
                              child: AnimatedSwitcher(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.color,
                                ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    ),
                                child: active
                                    ? SizedBox(
                                        key: ValueKey('edit-area-${todo.id}'),
                                        child: SizedBox(
                                          key: editKey,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Pressable(
                                                key: ValueKey(
                                                  'edit-task-${todo.id}',
                                                ),
                                                label:
                                                    '${context.strings.edit}: ${todo.title}',
                                                onPressed: onEdit,
                                                builder: (context, state) =>
                                                    SizedBox(
                                                      width: AppSpace.touch,
                                                      height: 40,
                                                      child: Icon(
                                                        SometimeIcons
                                                            .pencilSimple,
                                                        size: 19,
                                                        color: colors.secondary,
                                                      ),
                                                    ),
                                              ),
                                              if (!kIsWeb &&
                                                  defaultTargetPlatform ==
                                                      TargetPlatform.android &&
                                                  widget.onPin != null)
                                                PinAction(
                                                  label: todo.isPinned
                                                      ? context.strings.unpin
                                                      : context.strings.pin,
                                                  title: todo.title,
                                                  isPinned: todo.isPinned,
                                                  color: todo.isPinned
                                                      ? colors.focus
                                                      : colors.secondary,
                                                  onPressed: widget.onPin,
                                                  onSuccess: _pinSucceeded,
                                                ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('edit-area-empty'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.deleteHovered &&
                          (widget.spaceSwitchArmed || switchProgress > 0))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Transform.scale(
                              scale: 0.985 + switchProgress * 0.015,
                              child: CustomPaint(
                                key: ValueKey('space-switch-border-${todo.id}'),
                                painter: _SpaceSwitchBorderPainter(
                                  progress: switchProgress,
                                  stripe: colors.focus,
                                  contrast: colors.outline,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tutorialLink = widget.tutorialLink;
    return tutorialLink == null
        ? item
        : CompositedTransformTarget(link: tutorialLink, child: item);
  }
}

class _SpaceSwitchBorderPainter extends CustomPainter {
  const _SpaceSwitchBorderPainter({
    required this.progress,
    required this.stripe,
    required this.contrast,
  });

  final double progress;
  final Color stripe;
  final Color contrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    final visibility = Curves.easeOutCubic.transform(
      (progress * 4).clamp(0.0, 1.0),
    );
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final inner = outer.deflate(3);
    final border = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);
    canvas.save();
    canvas.clipPath(border);
    canvas.drawRRect(
      outer,
      Paint()..color = contrast.withValues(alpha: 0.3 * visibility),
    );
    const spacing = 11.0;
    final phase = (progress * spacing * 2) % spacing;
    final paint = Paint()
      ..color = stripe.withValues(alpha: 0.58 * visibility)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    for (
      var x = -size.height - spacing + phase;
      x < size.width + spacing;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, size.height + spacing),
        Offset(x + size.height + spacing * 2, -spacing),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpaceSwitchBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.stripe != stripe ||
      oldDelegate.contrast != contrast;
}

class _CompletionPainter extends CustomPainter {
  const _CompletionPainter({
    required this.progress,
    this.celebration = 0,
    required this.outline,
    required this.fill,
    required this.check,
  });

  final double progress;
  final double celebration;
  final Color outline;
  final Color fill;
  final Color check;

  @override
  void paint(Canvas canvas, Size size) {
    if (celebration > 0 && celebration < 1) {
      final center = size.center(Offset.zero);
      canvas.drawCircle(
        center,
        11 + celebration * 17,
        Paint()
          ..color = fill.withValues(alpha: (1 - celebration) * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      for (var i = 0; i < 7; i++) {
        final angle = i * math.pi * 2 / 7 - math.pi / 2;
        final distance = 10 + celebration * (14 + i % 3 * 3);
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * distance;
        canvas.drawCircle(
          point,
          1.4 * (1 - celebration * 0.4),
          Paint()
            ..color = (i.isEven ? fill : outline).withValues(
              alpha: (1 - celebration) * 0.65,
            ),
        );
      }
    }
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(5),
    );
    if (progress > 0) {
      canvas.drawRRect(
        shape,
        Paint()..color = fill.withValues(alpha: progress),
      );
      final checkPath = Path()
        ..moveTo(size.width * 0.27, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.68)
        ..lineTo(size.width * 0.75, size.height * 0.34);
      final metric = checkPath.computeMetrics().firstOrNull;
      if (metric != null) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * progress),
          Paint()
            ..color = check
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      return;
    }

    final path = Path()..addRRect(shape);
    final paint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 4.5) {
        canvas.drawPath(
          metric.extractPath(start, (start + 2).clamp(0.0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CompletionPainter oldDelegate) =>
      oldDelegate.celebration != celebration ||
      oldDelegate.progress != progress ||
      oldDelegate.outline != outline ||
      oldDelegate.fill != fill ||
      oldDelegate.check != check;
}

class _CompletionTitle extends StatelessWidget {
  const _CompletionTitle({
    required this.title,
    required this.progress,
    required this.style,
  });
  final String title;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _StrikePainter(
      title,
      style,
      progress,
      Directionality.of(context),
      MediaQuery.textScalerOf(context),
    ),
    child: Text(title, style: style),
  );
}

class _StrikePainter extends CustomPainter {
  const _StrikePainter(
    this.title,
    this.style,
    this.progress,
    this.direction,
    this.scaler,
  );
  final String title;
  final TextStyle style;
  final double progress;
  final TextDirection direction;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final lines = painter.computeLineMetrics();
    final total = lines.fold<double>(0, (sum, line) => sum + line.width);
    var remaining = total * progress;
    final paint = Paint()
      ..color = style.color!
      ..strokeWidth = 1.2;
    for (final line in lines) {
      final width = remaining.clamp(0.0, line.width);
      final y = line.baseline - line.ascent * 0.35;
      canvas.drawLine(
        Offset(line.left, y),
        Offset(line.left + width, y),
        paint,
      );
      remaining -= line.width;
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_StrikePainter oldDelegate) =>
      oldDelegate.title != title ||
      oldDelegate.style != style ||
      oldDelegate.progress != progress ||
      oldDelegate.direction != direction ||
      oldDelegate.scaler != scaler;
}
