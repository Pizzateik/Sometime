import 'package:flutter/foundation.dart';

enum ReminderRule {
  none('None'),
  atTime('At time'),
  tenMinutes('10 min before'),
  thirtyMinutes('30 min before'),
  oneHour('1 hour before'),
  oneDay('1 day before'),
  morning('Morning of'),
  twoDays('2 days before'),
  oneWeek('1 week before');

  const ReminderRule(this.label);
  final String label;

  static List<ReminderRule> options(bool hasTime) => hasTime
      ? [none, atTime, tenMinutes, thirtyMinutes, oneHour, oneDay]
      : [none, morning, oneDay, twoDays, oneWeek];
}

class ReminderSettings {
  const ReminderSettings({this.morningMinutes = 9 * 60});
  final int morningMinutes;
}

enum RecurrenceType { weekly, monthly, yearly }

@immutable
class RecurrenceRule {
  const RecurrenceRule({
    required this.type,
    this.weekdays = const [1],
    this.monthDay = 1,
    this.yearMonth = 1,
    this.yearDay = 1,
  });

  final RecurrenceType type;
  final List<int> weekdays;
  final int monthDay;
  final int yearMonth;
  final int yearDay;

  static DateTime _clampedDate(int year, int month, int day) =>
      DateTime(year, month, day.clamp(1, DateTime(year, month + 1, 0).day));

  // Use calendar dates to keep the rule stable across daylight saving changes.
  DateTime nextAfter(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    switch (type) {
      case RecurrenceType.weekly:
        final activeDays = weekdays.isEmpty ? [date.weekday] : weekdays;
        for (var offset = 1; offset <= 7; offset++) {
          final next = DateTime(date.year, date.month, date.day + offset);
          if (activeDays.contains(next.weekday)) return next;
        }
        return DateTime(date.year, date.month, date.day + 7);
      case RecurrenceType.monthly:
        final candidate = _clampedDate(date.year, date.month, monthDay);
        return candidate.isAfter(date)
            ? candidate
            : _clampedDate(date.year, date.month + 1, monthDay);
      case RecurrenceType.yearly:
        final candidate = _clampedDate(date.year, yearMonth, yearDay);
        return candidate.isAfter(date)
            ? candidate
            : _clampedDate(date.year + 1, yearMonth, yearDay);
    }
  }

  Map<String, Object> toJson() => {
    'type': type.name,
    'weekdays': weekdays,
    'monthDay': monthDay,
    'yearMonth': yearMonth,
    'yearDay': yearDay,
  };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    final type = RecurrenceType.values.where(
      (value) => value.name == json['type'],
    );
    final days = json['weekdays'];
    final monthDay = json['monthDay'];
    final month = json['yearMonth'];
    final day = json['yearDay'];
    if (type.isEmpty ||
        days is! List ||
        days.isEmpty ||
        days.any((value) => value is! int || value < 1 || value > 7) ||
        monthDay is! int ||
        monthDay < 1 ||
        monthDay > 31 ||
        month is! int ||
        month < 1 ||
        month > 12 ||
        day is! int ||
        day < 1 ||
        day > DateTime(2000, month + 1, 0).day) {
      throw const FormatException('The routine data is not valid.');
    }
    return RecurrenceRule(
      type: type.single,
      weekdays: List<int>.unmodifiable(
        days.cast<int>().toSet().toList()..sort(),
      ),
      monthDay: monthDay,
      yearMonth: month,
      yearDay: day,
    );
  }
}

@immutable
class TaskDetails {
  const TaskDetails({
    this.description = '',
    this.date,
    this.minutes,
    this.recurrence,
    this.reminder = ReminderRule.none,
  });

  final String description;
  final DateTime? date;
  final int? minutes;
  final RecurrenceRule? recurrence;
  final ReminderRule reminder;

  ReminderRule get effectiveReminder =>
      date != null && ReminderRule.options(minutes != null).contains(reminder)
      ? reminder
      : ReminderRule.none;

  DateTime? reminderTime({
    ReminderSettings settings = const ReminderSettings(),
  }) {
    final rule = effectiveReminder;
    if (rule == ReminderRule.none) return null;
    final day = date!;
    final time = minutes ?? settings.morningMinutes;
    final days = switch (rule) {
      ReminderRule.oneDay => 1,
      ReminderRule.twoDays => 2,
      ReminderRule.oneWeek => 7,
      _ => 0,
    };
    final local = DateTime(
      day.year,
      day.month,
      day.day - days,
      time ~/ 60,
      time % 60,
    );
    final offset = switch (rule) {
      ReminderRule.tenMinutes => 10,
      ReminderRule.thirtyMinutes => 30,
      ReminderRule.oneHour => 60,
      _ => 0,
    };
    return local.subtract(Duration(minutes: offset));
  }

  bool get isScheduled => date != null || minutes != null;

  // A time without a date uses the task creation date for stable sorting.
  DateTime sortTime(DateTime createdAt) {
    final day = date ?? createdAt;
    return DateTime(
      day.year,
      day.month,
      day.day,
      (minutes ?? 0) ~/ 60,
      (minutes ?? 0) % 60,
    );
  }

  TaskDetails onDate(DateTime value) => TaskDetails(
    description: description,
    date: value,
    minutes: minutes,
    recurrence: recurrence,
    reminder: reminder,
  );

  TaskDetails withoutRecurrence() => TaskDetails(
    description: description,
    date: date,
    minutes: minutes,
    reminder: reminder,
  );

  Map<String, Object?> toJson() => {
    'description': description,
    'reminder': effectiveReminder.name,
    'date': date?.toIso8601String(),
    'minutes': minutes,
    'recurrence': recurrence?.toJson(),
  };

  factory TaskDetails.fromJson(Object? value) {
    if (value == null) return const TaskDetails();
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The task details are not valid.');
    }
    final description = value['description'];
    final rawDate = value['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final minutes = value['minutes'];
    final recurrence = value['recurrence'];
    if (description is! String ||
        (rawDate != null && date == null) ||
        (minutes != null &&
            (minutes is! int || minutes < 0 || minutes >= 1440)) ||
        (recurrence != null && recurrence is! Map<String, dynamic>)) {
      throw const FormatException('The task details are not valid.');
    }
    return TaskDetails(
      description: description,
      reminder:
          ReminderRule.values
              .where((rule) => rule.name == value['reminder'])
              .firstOrNull ??
          ReminderRule.none,
      date: date == null ? null : DateTime(date.year, date.month, date.day),
      minutes: minutes as int?,
      recurrence: recurrence == null
          ? null
          : RecurrenceRule.fromJson(recurrence as Map<String, dynamic>),
    );
  }
}
