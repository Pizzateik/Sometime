import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_strings.dart';
import '../app/app_theme.dart';
import '../app/sometime_icons.dart';
import '../services/app_haptics.dart';
import '../services/data_transfer.dart';
import '../widgets/pressable.dart';
import 'membership_card.dart';

class MembershipHero extends StatefulWidget {
  const MembershipHero({
    required this.displayName,
    required this.supportDate,
    required this.shapeAsset,
    required this.gradientAsset,
    super.key,
  });
  final String? displayName;
  final DateTime supportDate;
  final String shapeAsset, gradientAsset;
  @override
  State<MembershipHero> createState() => _MembershipHeroState();
}

class _MembershipHeroState extends State<MembershipHero> {
  final _boundary = GlobalKey();
  bool _revealed = false, _busy = false, _ready = false, _success = false;
  @override
  void didUpdateWidget(MembershipHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shapeAsset != oldWidget.shapeAsset ||
        widget.gradientAsset != oldWidget.gradientAsset) {
      _ready = false;
    }
  }

  Future<void> _save() async {
    if (!_ready || _busy) return;
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundaryContext = _boundary.currentContext;
      final boundary =
          boundaryContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) return;
      final image = await boundary.toImage(
        pixelRatio: 1024 / boundary.size.width,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || bytes == null) return;
      final result = await shareFile(
        context,
        bytes.buffer.asUint8List(),
        'sometime-membership.png',
        'image/png',
      );
      if (result.status == ShareResultStatus.success && mounted) {
        AppHaptics.medium();
        setState(() => _success = true);
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(context.strings.transferError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.strings.cancel),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TapRegion(
      onTapOutside: (_) => setState(() => _revealed = false),
      child: SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(
              label: context.strings.saveCard,
              excludeChildSemantics: false,
              onPressed: () => setState(() => _revealed = !_revealed),
              onLongPress: () => setState(() {
                _revealed = true;
                _success = false;
              }),
              builder: (context, state) => AnimatedScale(
                scale: _revealed ? 0.985 : 1,
                duration: AppMotion.duration(context, AppMotion.press),
                child: RepaintBoundary(
                  key: _boundary,
                  child: AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.color),
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: AppMotion.curve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.985,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: MembershipCard(
                      key: ValueKey(
                        '${widget.shapeAsset}|${widget.gradientAsset}',
                      ),
                      displayName: widget.displayName,
                      supportDate: widget.supportDate,
                      shapeAsset: widget.shapeAsset,
                      gradientAsset: widget.gradientAsset,
                      shadow: false,
                      onReady: () {
                        _ready = true;
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: IgnorePointer(
                ignoring: !_revealed,
                child: AnimatedOpacity(
                  opacity: _revealed ? 1 : 0,
                  duration: AppMotion.duration(context, AppMotion.color),
                  child: AnimatedScale(
                    scale: _revealed ? 1 : 0.85,
                    duration: AppMotion.duration(context, AppMotion.color),
                    child: IconButton(
                      tooltip: _success
                          ? context.strings.transferSuccess
                          : context.strings.saveCard,
                      onPressed: _busy ? null : _save,
                      icon: Icon(
                        _success
                            ? SometimeIcons.check
                            : SometimeIcons.downloadSimple,
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
  );
}
