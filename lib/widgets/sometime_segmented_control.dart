import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../services/app_haptics.dart';
import 'pressable.dart';

class SometimeSegmentedControl<T> extends StatefulWidget {
  const SometimeSegmentedControl({
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  State<SometimeSegmentedControl<T>> createState() =>
      _SometimeSegmentedControlState<T>();
}

class _SometimeSegmentedControlState<T>
    extends State<SometimeSegmentedControl<T>> {
  bool _dragging = false;

  void _select(T value) {
    if (value == widget.value) return;
    AppHaptics.selection();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final index = widget.values.indexOf(widget.value);
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        onPointerDown: (_) => setState(() => _dragging = true),
        onPointerUp: (_) => setState(() => _dragging = false),
        onPointerCancel: (_) => setState(() => _dragging = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            setState(() => _dragging = true);
            final width = constraints.maxWidth / widget.values.length;
            _select(
              widget.values[(details.localPosition.dx / width).floor().clamp(
                0,
                widget.values.length - 1,
              )],
            );
          },
          onHorizontalDragUpdate: (details) {
            final width = constraints.maxWidth / widget.values.length;
            _select(
              widget.values[(details.localPosition.dx / width).floor().clamp(
                0,
                widget.values.length - 1,
              )],
            );
          },
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          child: AnimatedScale(
            scale: 1,
            duration: AppMotion.duration(context, AppMotion.press),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.pill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: Alignment(
                        -1 + (2 * index / (widget.values.length - 1)),
                        0,
                      ),
                      duration: AppMotion.duration(context, AppMotion.color),
                      curve: AppMotion.curve,
                      child: FractionallySizedBox(
                        heightFactor: 1,
                        widthFactor: 1 / widget.values.length,
                        child: AnimatedScale(
                          scale: _dragging ? 1.05 : 1,
                          duration: AppMotion.duration(
                            context,
                            AppMotion.press,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.strongSelection,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final item in widget.values)
                        Expanded(
                          child: Pressable(
                            label: widget.label(item),
                            selected: item == widget.value,
                            hapticOnTap: false,
                            onPressed: () => _select(item),
                            scale: 1,
                            radius: 10,
                            builder: (context, state) => Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.color,
                                ),
                                style: Theme.of(context).textTheme.labelLarge!
                                    .copyWith(
                                      color: item == widget.value
                                          ? colors.onStrongSelection
                                          : colors.secondary,
                                    ),
                                child: Text(
                                  widget.label(item),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
