import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgAssetMask extends StatefulWidget {
  const SvgAssetMask({required this.asset, required this.child, super.key});
  final String asset;
  final Widget child;
  @override
  State<SvgAssetMask> createState() => _SvgAssetMaskState();
}

class _SvgAssetMaskState extends State<SvgAssetMask> {
  ui.Image? _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final picture = await vg.loadPicture(SvgAssetLoader(widget.asset), null);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(800 / picture.size.width, 800 / picture.size.height);
    canvas.drawPicture(picture.picture);
    final scaled = recorder.endRecording();
    final image = await scaled.toImage(800, 800);
    scaled.dispose();
    picture.picture.dispose();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _image = image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image == null
      ? const SizedBox.square(dimension: 180)
      : ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => ImageShader(
            _image!,
            TileMode.clamp,
            TileMode.clamp,
            (Matrix4.identity()..scaleByDouble(
                  bounds.width / 800,
                  bounds.height / 800,
                  1,
                  1,
                ))
                .storage,
          ),
          child: widget.child,
        );
}
