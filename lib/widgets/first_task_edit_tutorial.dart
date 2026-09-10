import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/app_theme.dart';
import '../app/sometime_icons.dart';
import 'pressable.dart';

class FirstTaskEditTutorial extends StatelessWidget {
  const FirstTaskEditTutorial({
    required this.showPin,
    required this.onDismiss,
    super.key,
  });

  final bool showPin;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.appColors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duration(context, AppMotion.open),
      curve: AppMotion.curve,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * -6),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.creationSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.activeBorder, width: 0.7),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 60),
                child: Semantics(
                  container: true,
                  label:
                      '${strings.firstTaskEditTutorialTitle}. ${strings.firstTaskEditTutorialBody(showPin: showPin)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.firstTaskEditTutorialTitle,
                        style: context.appTypography.sectionTitle.copyWith(
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.firstTaskEditTutorialBody(showPin: showPin),
                        style: context.appTypography.taskDescription.copyWith(
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TutorialTag(
                            icon: SometimeIcons.dotsSixVertical,
                            label: strings.move,
                          ),
                          _TutorialTag(
                            icon: SometimeIcons.pencilSimple,
                            label: strings.edit,
                          ),
                          if (showPin)
                            _TutorialTag(
                              icon: SometimeIcons.pushPin,
                              label: strings.tutorialPin,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Pressable(
                label: strings.gotIt,
                onPressed: onDismiss,
                radius: 10,
                builder: (context, _) => ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 92),
                  child: SizedBox(
                    height: AppSpace.touch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: Text(
                          strings.gotIt,
                          maxLines: 1,
                          softWrap: false,
                          style: context.appTypography.buttonLabel.copyWith(
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialTag extends StatelessWidget {
  const _TutorialTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colors.pill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.appTypography.controlLabel.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
