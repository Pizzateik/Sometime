import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/sometime_icons.dart';
import '../services/app_haptics.dart';
import 'pressable.dart';

class PinAction extends StatefulWidget {
  const PinAction({
    required this.label,
    required this.title,
    required this.isPinned,
    required this.color,
    required this.onPressed,
    this.onSuccess,
    super.key,
  });

  final String label;
  final String title;
  final bool isPinned;
  final Color color;
  final Future<bool> Function()? onPressed;
  final ValueChanged<bool>? onSuccess;

  @override
  State<PinAction> createState() => _PinActionState();
}

class _PinActionState extends State<PinAction>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 360);

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: _duration,
  )..addStatusListener(_animationStatusChanged);
  OverlayEntry? _capsule;
  bool _busy = false;
  bool? _targetPinned;

  @override
  void didUpdateWidget(PinAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_targetPinned != null && widget.isPinned != _targetPinned) {
      _animation.stop();
      _removeCapsule();
      if (mounted) {
        setState(() {
          _busy = false;
          _targetPinned = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _removeCapsule();
    _animation.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final action = widget.onPressed;
    if (_busy || action == null) return;
    final targetPinned = !widget.isPinned;
    setState(() => _busy = true);

    bool succeeded = false;
    try {
      succeeded = await action();
    } finally {
      if (mounted && !succeeded) setState(() => _busy = false);
    }
    if (!mounted || !succeeded) return;

    _play(targetPinned);
    if (targetPinned) {
      AppHaptics.medium();
    } else {
      AppHaptics.selection();
    }
    widget.onSuccess?.call(targetPinned);
  }

  void _play(bool targetPinned) {
    _removeCapsule();
    _targetPinned = targetPinned;
    _animation.duration = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 180)
        : _duration;
    _animation.forward(from: 0);
    if (targetPinned && !MediaQuery.disableAnimationsOf(context)) {
      _showCapsule();
    }
  }

  void _animationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _removeCapsule();
      if (mounted) {
        setState(() {
          _busy = false;
          _targetPinned = null;
        });
      }
    } else if (status == AnimationStatus.dismissed) {
      _removeCapsule();
    }
  }

  void _showCapsule() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final renderObject = context.findRenderObject();
    if (overlay == null ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return;
    }

    final origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final capsuleWidth = math.min(220.0, math.max(0.0, screenWidth - 24));
    final maxLeft = math.max(12.0, screenWidth - capsuleWidth - 12);
    final left = (origin.center.dx - capsuleWidth / 2)
        .clamp(12.0, maxLeft)
        .toDouble();
    final travel = origin.top + origin.height + 10;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final progress = _animation.value;
          final fade = ((progress - 0.52) / 0.48).clamp(0.0, 1.0);
          final vertical = Curves.easeInOutCubic.transform(progress);
          return Positioned(
            left: left,
            top: origin.top - 8 - travel * vertical,
            width: capsuleWidth,
            child: IgnorePointer(
              child: Opacity(
                opacity: 1 - Curves.easeIn.transform(fade),
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: 1 - progress * 0.08,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _PinCapsule(title: widget.title),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _capsule = entry;
    overlay.insert(entry);
  }

  void _removeCapsule() {
    _capsule?.remove();
    _capsule = null;
  }

  IconData _icon(double progress) {
    final targetPinned = _targetPinned;
    if (targetPinned == null) {
      return widget.isPinned
          ? SometimeIcons.pushPinActive
          : SometimeIcons.pushPin;
    }
    if (progress < 0.42) {
      return targetPinned ? SometimeIcons.pushPin : SometimeIcons.pushPinActive;
    }
    return targetPinned ? SometimeIcons.pushPinActive : SometimeIcons.pushPin;
  }

  double _scale(double progress) {
    final targetPinned = _targetPinned;
    if (targetPinned == null) return 1;
    if (MediaQuery.disableAnimationsOf(context)) {
      final response = math.sin(progress * math.pi);
      return targetPinned ? 1 + response * 0.04 : 1 - response * 0.025;
    }
    if (targetPinned && progress < 0.5) {
      return _between(1, 1.2, Curves.easeOutCubic.transform(progress / 0.5));
    }
    if (!targetPinned && progress < 0.5) {
      return _between(1, 0.94, Curves.easeOutCubic.transform(progress / 0.5));
    }
    return _between(
      targetPinned ? 1.2 : 0.94,
      1,
      Curves.easeInOutCubic.transform((progress - 0.5) / 0.5),
    );
  }

  double _rotation(double progress) {
    final targetPinned = _targetPinned;
    if (targetPinned == null || MediaQuery.disableAnimationsOf(context)) {
      return 0;
    }
    if (targetPinned && progress < 0.5) {
      return _between(
        -math.pi / 18,
        math.pi / 60,
        Curves.easeInOutCubic.transform(progress / 0.5),
      );
    }
    if (!targetPinned && progress < 0.5) {
      return _between(0, -0.04, Curves.easeOutCubic.transform(progress / 0.5));
    }
    return _between(
      targetPinned ? math.pi / 60 : -0.04,
      0,
      Curves.easeInOutCubic.transform((progress - 0.5) / 0.5),
    );
  }

  double _between(double start, double end, double progress) =>
      start + (end - start) * progress;

  @override
  Widget build(BuildContext context) => Pressable(
    label: widget.label,
    hapticOnTap: false,
    onPressed: _busy || widget.onPressed == null
        ? null
        : () => unawaited(_activate()),
    builder: (context, state) => SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => Transform.rotate(
            angle: _rotation(_animation.value),
            alignment: Alignment.center,
            child: Transform.scale(
              scale: _scale(_animation.value),
              child: Icon(
                _icon(_animation.value),
                size: 21,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PinCapsule extends StatelessWidget {
  const _PinCapsule({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final shortTitle = title.characters.take(26).toString();
    return Material(
      color: context.appColors.surface,
      elevation: 4,
      shadowColor: context.appColors.shadow.withValues(alpha: 0.2),
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              SometimeIcons.pushPinActive,
              size: 15,
              color: context.appColors.accent,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                shortTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.controlLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
