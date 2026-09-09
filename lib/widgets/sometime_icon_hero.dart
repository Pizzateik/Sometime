import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_config.dart';
import '../services/app_haptics.dart';
import 'svg_asset_mask.dart';

enum _IconAnimation { wiggle, spin }

class SometimeIconHero extends StatefulWidget {
  const SometimeIconHero({
    this.dimension = 180,
    this.decorative = false,
    this.semanticLabel,
    super.key,
  });

  final double dimension;
  final bool decorative;
  final String? semanticLabel;

  @override
  State<SometimeIconHero> createState() => _SometimeIconHeroState();
}

class _SometimeIconHeroState extends State<SometimeIconHero>
    with SingleTickerProviderStateMixin {
  static const _tapWindow = Duration(milliseconds: 1800);
  static const _wiggleDuration = Duration(milliseconds: 260);
  static const _spinDuration = Duration(milliseconds: 420);
  static const _wiggleAngle = 0.1;
  static const _spinOvershoot = 0.12;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: _wiggleDuration,
  );
  Timer? _tapResetTimer;
  int _tapCount = 0;
  _IconAnimation? _animation;

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    AppHaptics.selection();
    _tapResetTimer?.cancel();
    _tapCount++;

    if (_tapCount == 3) {
      _tapCount = 0;
      _play(_IconAnimation.spin);
      return;
    }

    _tapResetTimer = Timer(_tapWindow, () => _tapCount = 0);
    _play(_IconAnimation.wiggle);
  }

  void _play(_IconAnimation animation) {
    _animation = animation;
    _animationController
      ..stop()
      ..duration = animation == _IconAnimation.spin
          ? _spinDuration
          : _wiggleDuration
      ..forward(from: 0);
  }

  double _rotation(double progress) {
    final animation = _animation;
    if (animation == null) return 0;

    if (MediaQuery.disableAnimationsOf(context)) {
      return 0.025 * math.sin(progress * math.pi);
    }

    return switch (animation) {
      _IconAnimation.wiggle => _wiggleRotation(progress),
      _IconAnimation.spin => _spinRotation(progress),
    };
  }

  double _wiggleRotation(double progress) {
    if (progress < 0.22) {
      return _between(
        0,
        _wiggleAngle,
        Curves.easeOutCubic.transform(progress / 0.22),
      );
    }
    if (progress < 0.62) {
      return _between(
        _wiggleAngle,
        -_wiggleAngle,
        Curves.easeInOutCubic.transform((progress - 0.22) / 0.4),
      );
    }
    return _between(
      -_wiggleAngle,
      0,
      Curves.easeOutCubic.transform((progress - 0.62) / 0.38),
    );
  }

  double _spinRotation(double progress) {
    if (progress >= 1) return 0;
    if (progress < 0.72) {
      return _between(
        0,
        2 * math.pi,
        Curves.easeOutCubic.transform(progress / 0.72),
      );
    }
    if (progress < 0.84) {
      return _between(
        2 * math.pi,
        2 * math.pi + _spinOvershoot,
        Curves.easeInOut.transform((progress - 0.72) / 0.12),
      );
    }
    return _between(
      2 * math.pi + _spinOvershoot,
      2 * math.pi,
      Curves.easeOutBack.transform((progress - 0.84) / 0.16),
    );
  }

  double _between(double start, double end, double progress) =>
      start + (end - start) * progress;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: widget.dimension,
      child: SvgAssetMask(
        asset: 'assets/Own Assets/Setting_IconShape_Mask.svg',
        child: ColoredBox(
          color: AppConfig.iconBackground,
          child: Padding(
            padding: EdgeInsets.all(widget.dimension / 6),
            child: SvgPicture.asset(AppConfig.iconForeground),
          ),
        ),
      ),
    );
    final animatedIcon = AnimatedBuilder(
      animation: _animationController,
      child: icon,
      builder: (context, child) {
        final progress = _animationController.value;
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        final response = reducedMotion ? math.sin(progress * math.pi) : 0.0;
        return Opacity(
          opacity: 1 - response * 0.03,
          child: Transform.scale(
            scale: 1 + response * 0.012,
            child: Transform.rotate(
              angle: _rotation(progress),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
    Widget result = Semantics(
      label: widget.semanticLabel,
      image: true,
      onTap: widget.decorative ? null : _handleTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _handleTap,
        child: animatedIcon,
      ),
    );
    if (widget.decorative) result = ExcludeSemantics(child: result);
    return result;
  }
}
