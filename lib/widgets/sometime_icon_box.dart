import 'package:flutter/widgets.dart';

class SometimeIconBox extends StatelessWidget {
  const SometimeIconBox({
    required this.icon,
    required this.size,
    required this.color,
    this.dimension = 32,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;
  final double dimension;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimension,
    child: Align(
      alignment: Alignment.center,
      child: Icon(icon, size: size, color: color),
    ),
  );
}
