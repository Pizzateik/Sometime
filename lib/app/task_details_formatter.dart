import 'package:flutter/material.dart';

import '../models/task_details.dart';
import 'app_strings.dart';

String routineLabel(BuildContext context, RecurrenceRule rule) {
  final localizations = MaterialLocalizations.of(context);
  final strings = context.strings;
  final days = strings.weekdayInitials;
  return switch (rule.type) {
    RecurrenceType.weekly =>
      '${strings.weekly} · ${rule.weekdays.map((day) => days[day - 1]).join(', ')}',
    RecurrenceType.monthly => '${strings.monthly} · ${rule.monthDay}.',
    RecurrenceType.yearly =>
      '${strings.yearly} · ${localizations.formatShortMonthDay(DateTime(2000, rule.yearMonth, rule.yearDay))}',
  };
}

String taskDetailsLabel(BuildContext context, TaskDetails details) {
  final localizations = MaterialLocalizations.of(context);
  return [
    if (details.date != null) localizations.formatShortMonthDay(details.date!),
    if (details.minutes != null)
      localizations.formatTimeOfDay(
        TimeOfDay(hour: details.minutes! ~/ 60, minute: details.minutes! % 60),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    if (details.recurrence != null)
      '↻ ${routineLabel(context, details.recurrence!)}',
  ].join(' · ');
}
