$path='lib/models/task_details.dart'
$s=Get-Content $path -Raw
$s=$s.Replace('enum RecurrenceType', @"
enum ReminderRule {
  none('None'), atTime('At time'), tenMinutes('10 min before'),
  thirtyMinutes('30 min before'), oneHour('1 hour before'),
  oneDay('1 day before'), morning('Morning of'),
  twoDays('2 days before'), oneWeek('1 week before');

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

enum RecurrenceType
"@)
$s=$s.Replace('this.recurrence,','this.recurrence,'+"`n    this.reminder = ReminderRule.none,")
$s=$s.Replace('final RecurrenceRule? recurrence;',@"
final RecurrenceRule? recurrence;
  final ReminderRule reminder;

  ReminderRule get effectiveReminder => date != null &&
      ReminderRule.options(minutes != null).contains(reminder)
      ? reminder : ReminderRule.none;

  DateTime? reminderTime({ReminderSettings settings = const ReminderSettings()}) {
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
    final local = DateTime(day.year, day.month, day.day - days,
        time ~/ 60, time % 60);
    final offset = switch (rule) {
      ReminderRule.tenMinutes => 10,
      ReminderRule.thirtyMinutes => 30,
      ReminderRule.oneHour => 60,
      _ => 0,
    };
    return local.subtract(Duration(minutes: offset));
  }
"@)
$s=$s.Replace('recurrence: recurrence,',"recurrence: recurrence,`n    reminder: reminder,")
$s=$s.Replace('TaskDetails(description: description, date: date, minutes: minutes);','TaskDetails(description: description, date: date, minutes: minutes, reminder: reminder);')
$s=$s.Replace("'description': description,","'description': description,`n    'reminder': effectiveReminder.name,")
$s=$s.Replace('description: description,'+"`r`n      date:","description: description,`n      reminder: ReminderRule.values.where((rule) => rule.name == value['reminder']).firstOrNull ?? ReminderRule.none,`n      date:")
Set-Content $path $s
$path='lib/models/todo.dart'; $s=Get-Content $path -Raw
$s=$s.Replace('this.routineId,',"this.routineId,`n    this.isPinned = false,")
$s=$s.Replace('final String? routineId;',"final String? routineId;`n  final bool isPinned;")
$s=$s.Replace('routineId: routineId,',"routineId: routineId,`n    isPinned: isPinned,")
$s=$s.Replace('TaskDetails? details,',"TaskDetails? details,`n    bool? isPinned,")
$s=$s.Replace('details: details ?? this.details,',"details: details ?? this.details,")
# Only the update method accepts an optional pin state.
$start=$s.IndexOf('  Todo update('); $end=$s.IndexOf('  Map<String, Object?> toJson()', $start)
$part=$s.Substring($start,$end-$start).Replace('isPinned: isPinned,','isPinned: isPinned ?? this.isPinned,')
$s=$s.Substring(0,$start)+$part+$s.Substring($end)
$s=$s.Replace("'routineId': routineId,","'routineId': routineId,`n    'isPinned': isPinned,")
$s=$s.Replace("routineId: json['routineId'] as String?,","routineId: json['routineId'] as String?,`n      isPinned: json['isPinned'] == true,")
Set-Content $path $s
$path='lib/state/todo_controller.dart'; $s=Get-Content $path -Raw
$s=$s.Replace('routineId: series,',"routineId: series,`n            isPinned: expected.isPinned,")
$s=$s.Replace('  Future<void> retrySave()',@"
  void setPinned(String spaceId, String todoId, bool value) {
    _updateSpace(spaceId, (todos) => [
      for (final todo in todos)
        if (todo.id == todoId && !todo.isComplete)
          todo.update(title: todo.title, group: todo.group,
              sortOrder: todo.sortOrder, isPinned: value)
        else todo,
    ]);
  }

  Future<void> completeFromNotification(String spaceId, String todoId) async {
    final todo = spaceById(spaceId).todos.where((t) => t.id == todoId).firstOrNull;
    if (todo == null || todo.isComplete) return;
    toggleTodo(spaceId, todoId);
    _finishCompletion(spaceId, spaceById(spaceId).todos.firstWhere((t) => t.id == todoId));
    await flush();
  }

  Future<void> flush() async {
    await _persist();
    if (_saveFailed) throw StateError('The task state could not be saved.');
  }

  Future<void> retrySave()
"@)
Set-Content $path $s
