import 'package:flutter/material.dart';

abstract final class MembershipAssets {
  static const _lightForeground = <int>{
    1,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    13,
    15,
    16,
  };
  static Color foreground(String asset) =>
      _lightForeground.contains(gradients.indexOf(asset) + 1)
      ? Colors.white
      : Colors.black;
  static const shapes = [
    'assets/masks/MemberCard_GradientMask_01.svg',
    'assets/masks/MemberCard_GradientMask_02.svg',
    'assets/masks/MemberCard_GradientMask_03.svg',
  ];

  static final gradients = List<String>.unmodifiable([
    for (var index = 1; index <= 16; index++)
      'assets/gradients/image-mesh-gradient($index).webp',
  ]);
}
