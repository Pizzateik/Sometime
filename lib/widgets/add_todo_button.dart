import '../app/sometime_icons.dart';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import 'pressable.dart';
import 'sometime_action_icon.dart';

class AddTodoButton extends StatelessWidget {
  const AddTodoButton({
    required this.onPressed,
    this.dragging = false,
    this.deleteHovered = false,
    super.key,
  });

  static const width = 56.0;
  static const height = 56.0;
  static const deleteWidth = 138.0;
  static const radius = 17.0;

  final VoidCallback onPressed;
  final bool dragging;
  final bool deleteHovered;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final buttonColor = colors.accent;
    final buttonInk = colors.onAccent;
    final targetWidth = dragging ? deleteWidth : width;
    return AnimatedScale(
      scale: deleteHovered ? 1.07 : 1,
      duration: AppMotion.duration(context, AppMotion.press),
      curve: AppMotion.curve,
      child: Pressable(
        label: dragging
            ? '${context.strings.delete} ${context.strings.newTask}'
            : context.strings.newTask,
        onPressed: dragging ? null : onPressed,
        radius: radius,
        scale: 0.96,
        builder: (context, state) => AnimatedContainer(
          width: targetWidth,
          height: height,
          duration: AppMotion.duration(context, AppMotion.color),
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: dragging
                ? Color.alphaBlend(
                    context.appColors.destructive.withValues(alpha: 0.16),
                    colors.background,
                  )
                : state.hovered
                ? Color.lerp(buttonColor, colors.background, 0.1)
                : buttonColor,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: Theme.of(context).brightness == Brightness.light
                ? [
                    BoxShadow(
                      color: colors.ink.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: dragging ? 0 : 1,
                duration: AppMotion.duration(context, AppMotion.press),
                child: AnimatedRotation(
                  turns: dragging ? 0.12 : 0,
                  alignment: Alignment.center,
                  duration: AppMotion.duration(context, AppMotion.press),
                  child: AnimatedScale(
                    scale: dragging ? 0.7 : 1,
                    alignment: Alignment.center,
                    duration: AppMotion.duration(context, AppMotion.press),
                    child: SometimeActionIconBox(
                      glyph: SometimeActionGlyph.plus,
                      color: buttonInk,
                      size: 26,
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: dragging ? 1 : 0,
                duration: AppMotion.duration(context, AppMotion.color),
                child: AnimatedScale(
                  scale: dragging ? 1 : 0.82,
                  duration: AppMotion.duration(context, AppMotion.color),
                  curve: AppMotion.curve,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: deleteWidth,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.strings.delete,
                            style: context.appTypography.dangerLabel.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(
                            SometimeIcons.trash,
                            color: context.appColors.destructive,
                            size: 23,
                          ),
                        ],
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
}
