import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../app/sometime_icons.dart';
import '../app/task_details_formatter.dart';
import '../models/task_details.dart';

class TaskMetadataPill extends StatelessWidget {
  const TaskMetadataPill({
    required this.details,
    required this.isPinned,
    super.key,
  });

  static const _iconSize = 14.0;
  static const _iconBoxSize = 16.0;
  static const _iconTextGap = 4.0;
  static const _groupGap = 8.0;

  final TaskDetails details;
  final bool isPinned;

  bool get _showPin =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && isPinned;

  List<({IconData icon, String text, String semantics, bool active})> _metadata(
    BuildContext context,
  ) {
    final localizations = MaterialLocalizations.of(context);
    final entries =
        <({IconData icon, String text, String semantics, bool active})>[
          if (details.date != null)
            (
              icon: SometimeIcons.calendar,
              text: localizations.formatShortMonthDay(details.date!),
              semantics: localizations.formatShortMonthDay(details.date!),
              active: false,
            ),
          if (details.minutes != null)
            (
              icon: SometimeIcons.clock,
              text: localizations.formatTimeOfDay(
                TimeOfDay(
                  hour: details.minutes! ~/ 60,
                  minute: details.minutes! % 60,
                ),
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
              semantics: localizations.formatTimeOfDay(
                TimeOfDay(
                  hour: details.minutes! ~/ 60,
                  minute: details.minutes! % 60,
                ),
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
              active: false,
            ),
          if (details.effectiveReminder != ReminderRule.none)
            (
              icon: SometimeIcons.bell,
              text: context.strings.reminderName(
                details.effectiveReminder.index,
              ),
              semantics: context.strings.reminderName(
                details.effectiveReminder.index,
              ),
              active: false,
            ),
          if (details.recurrence != null)
            (
              icon: SometimeIcons.arrowsClockwise,
              text: routineLabel(context, details.recurrence!),
              semantics: routineLabel(context, details.recurrence!),
              active: false,
            ),
          if (_showPin)
            (
              icon: SometimeIcons.pushPinActive,
              text: '',
              semantics: context.strings.pinnedToNotifications,
              active: true,
            ),
        ];
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata(context);
    if (metadata.isEmpty) return const SizedBox.shrink();
    final semantics = metadata.map((entry) => entry.semantics).join(', ');
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: context.appColors.pill,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < metadata.length; index++) ...[
              if (index > 0) const SizedBox(width: _groupGap),
              Flexible(
                fit: FlexFit.loose,
                child: _MetadataGroup(
                  entry: metadata[index],
                  flexibleText: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataGroup extends StatelessWidget {
  const _MetadataGroup({required this.entry, required this.flexibleText});

  final ({IconData icon, String text, String semantics, bool active}) entry;
  final bool flexibleText;

  @override
  Widget build(BuildContext context) {
    final color = entry.active
        ? context.appColors.focus
        : context.appColors.secondary;
    final text = Text(
      entry.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w400),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: TaskMetadataPill._iconBoxSize,
          child: Center(
            child: Icon(
              entry.icon,
              size: TaskMetadataPill._iconSize,
              color: color,
            ),
          ),
        ),
        if (entry.text.isNotEmpty) ...[
          const SizedBox(width: TaskMetadataPill._iconTextGap),
          if (flexibleText) Flexible(child: text) else text,
        ],
      ],
    );
  }
}
