import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_config.dart';
import '../app/app_strings.dart';
import 'membership_assets.dart';

class MembershipCard extends StatelessWidget {
  const MembershipCard({
    required this.displayName,
    required this.supportDate,
    required this.shapeAsset,
    required this.gradientAsset,
    this.onReady,
    this.shadow = true,
    super.key,
  });

  final String? displayName;
  final DateTime supportDate;
  final String shapeAsset;
  final String gradientAsset;
  final VoidCallback? onReady;
  final bool shadow;
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : strings.you;
    final nameLength = name.characters.length;
    final nameFontSize = nameLength <= 4
        ? 42.0
        : (42 - ((nameLength - 4).clamp(0, 6) * 1.5)).toDouble();
    final since = strings.supporterSince(supportDate);
    final semantics = strings.supporterCardSemantics(name, supportDate);

    return Semantics(
      label: semantics,
      image: true,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConfig.membershipCardRadius),
            boxShadow: !shadow
                ? null
                : [
                    BoxShadow(
                      color: Theme.of(context).shadowColor
                          .withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConfig.membershipCardRadius),
            child: ColoredBox(
              color: AppConfig.membershipCream,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: _MaskedGradient(
                      shapeAsset: shapeAsset,
                      gradientAsset: gradientAsset,
                      onReady: onReady,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'SOMETIME',
                              style: TextStyle(
                                color: MembershipAssets.foreground(
                                  gradientAsset,
                                ),
                                fontFamily: 'Geist',
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.85,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SvgPicture.asset(
                              AppConfig.iconForeground,
                              width: 22,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: TextStyle(
                                color: const Color(0xFF181814),
                                fontFamily: 'Parisienne',
                                fontFamilyFallback: const [
                                  'Noto Sans CJK JP',
                                  'Noto Sans JP',
                                  'Hiragino Sans',
                                  'Hiragino Kaku Gothic ProN',
                                  'sans-serif',
                                ],
                                fontSize: nameFontSize,
                                height: 0.96,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            since.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF66625C),
                              fontFamily: 'Geist',
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaskedGradient extends StatefulWidget {
  const _MaskedGradient({
    required this.shapeAsset,
    required this.gradientAsset,
    this.onReady,
  });

  final String shapeAsset;
  final String gradientAsset;
  final VoidCallback? onReady;

  @override
  State<_MaskedGradient> createState() => _MaskedGradientState();
}

class _MaskedGradientState extends State<_MaskedGradient> {
  int _generation = 0;
  ui.Image? _gradient;
  ui.Image? _mask;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MaskedGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shapeAsset != widget.shapeAsset ||
        oldWidget.gradientAsset != widget.gradientAsset) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    ui.Image? gradient;
    ui.Image? mask;
    try {
      final gradientData = await rootBundle.load(widget.gradientAsset);
      final codec = await ui.instantiateImageCodec(
        gradientData.buffer.asUint8List(),
        targetWidth: 1024,
        targetHeight: 1024,
      );
      try {
        gradient = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      final picture = await vg.loadPicture(
        SvgAssetLoader(widget.shapeAsset),
        null,
      );
      try {
        mask = await picture.picture.toImage(1024, 1024);
      } finally {
        picture.picture.dispose();
      }
      if (!mounted || generation != _generation) return;
      final oldGradient = _gradient;
      final oldMask = _mask;
      setState(() {
        _gradient = gradient;
        _mask = mask;
      });
      gradient = null;
      mask = null;
      oldGradient?.dispose();
      oldMask?.dispose();
      widget.onReady?.call();
    } catch (_) {
      // Keep the card text when an image cannot load.
    } finally {
      gradient?.dispose();
      mask?.dispose();
    }
  }

  @override
  void dispose() {
    _gradient?.dispose();
    _mask?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gradient == null || _mask == null) return const SizedBox.shrink();
    return CustomPaint(painter: _MaskPainter(_gradient!, _mask!));
  }
}

class _MaskPainter extends CustomPainter {
  const _MaskPainter(this.gradient, this.mask);

  final ui.Image gradient;
  final ui.Image mask;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final imageRect = Rect.fromLTWH(
      0,
      0,
      gradient.width.toDouble(),
      gradient.height.toDouble(),
    );
    canvas.saveLayer(rect, Paint());
    canvas.drawImageRect(gradient, imageRect, rect, Paint());
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
    canvas.drawImageRect(
      mask,
      Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
      rect,
      Paint(),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) =>
      gradient != oldDelegate.gradient || mask != oldDelegate.mask;
}
