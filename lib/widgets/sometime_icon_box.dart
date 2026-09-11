import 'package:flutter/widgets.dart';

class SometimeIconBox extends StatelessWidget {
  const SometimeIconBox({
    required this.icon,
    required this.size,
    required this.color,
    this.dimension = 32,
    this.opticalOffset = Offset.zero,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;
  final double dimension;
  final Offset opticalOffset;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimension,
    child: Center(
      child: SizedBox.square(
        dimension: size,
        child: Transform.translate(
          offset: opticalOffset,
          child: Icon(icon, size: size, color: color),
        ),
      ),
    ),
  );
}
