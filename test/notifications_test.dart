import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app_theme.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_storage.dart';
import 'package:todo_app/state/theme_controller.dart';
import 'package:todo_app/state/todo_controller.dart';

import 'support/memory_todo_storage.dart';

void main() {
  test(
    'Date-only reminders use local calendar days and a configurable morning',
    () {
      for (final entry in {
        ReminderRule.morning: 0,
        ReminderRule.oneDay: 1,
        ReminderRule.twoDays: 2,
        ReminderRule.oneWeek: 7,
      }.entries) {
        final details = TaskDetails(
          date: DateTime(2027, 1, 1),
          reminder: entry.key,
        );
        expect(details.reminderTime(), DateTime(2027, 1, 1 - entry.value, 9));
        expect(
          details.reminderTime(
            settings: const ReminderSettings(morningMinutes: 600),
          ),
          DateTime(2027, 1, 1 - entry.value, 10),
        );
        expect(TaskDetails.fromJson(details.toJson()).reminder, entry.key);
      }
    },
  );

  test('Timed reminders and invalid time-only rules', () {
    for (final entry in {
      ReminderRule.atTime: 0,
      ReminderRule.tenMinutes: 10,
      ReminderRule.thirtyMinutes: 30,
      ReminderRule.oneHour: 60,
    }.entries) {
      expect(
        TaskDetails(
          date: DateTime(2026, 9, 12),
          minutes: 1110,
          reminder: entry.key,
        ).reminderTime(),
        DateTime(2026, 9, 12, 18, 30 - entry.value),
      );
    }
    expect(
      const TaskDetails(
        minutes: 600,
        reminder: ReminderRule.atTime,
      ).reminderTime(),
      isNull,
    );
    expect(
      TaskDetails(
        date: DateTime(2026),
        reminder: ReminderRule.atTime,
      ).effectiveReminder,
      ReminderRule.none,
    );
    expect(
      TaskDetails(
        date: DateTime(2026, 3, 30),
        reminder: ReminderRule.oneDay,
      ).reminderTime(),
      DateTime(2026, 3, 29, 9),
    );
  });

  test(
    'Notification completion retains the routine reminder and pin',
    () async {
      final storage = MemoryTodoStorage();
      final controller = TodoController(
        storage: storage,
        clock: () => DateTime(2026, 9, 7, 8),
      );
      await controller.initialize();
      final space = controller.spaces.first.id;
      final id = controller.addTodo(
        space,
        TodoDraft(
          title: 'Workout',
          group: TodoGroup.today,
          details: TaskDetails(
            date: DateTime(2026, 9, 7),
            minutes: 450,
            reminder: ReminderRule.thirtyMinutes,
            recurrence: const RecurrenceRule(
              type: RecurrenceType.weekly,
              weekdays: [1, 3, 5],
            ),
          ),
        ),
      );
      controller.setPinned(space, id, true);
      await controller.completeFromNotification(space, id);
      final completed = controller
          .spaceById(space)
          .todos
          .firstWhere((t) => t.id == id);
      final next = controller
          .spaceById(space)
          .todos
          .firstWhere((t) => t.routineId == id && t.id != id);
      expect(completed.completedAt, DateTime(2026, 9, 7, 8));
      expect(completed.completedPending, isFalse);
      expect(next.isPinned, isTrue);
      expect(next.details.reminderTime(), DateTime(2026, 9, 9, 7));
      controller.deleteTodo(space, next.id);
      controller.undoDeletion();
      final restored = controller
          .spaceById(space)
          .todos
          .firstWhere((t) => t.id == next.id);
      expect(restored.isPinned, isTrue);
      expect(restored.details.reminder, ReminderRule.thirtyMinutes);
      await controller.flush();
      final saved = LocalTodoStorage.decode(
        LocalTodoStorage.encode((await storage.load())!),
      );
      expect(
        saved.spaces.first.todos.firstWhere((t) => t.id == next.id).isPinned,
        isTrue,
      );
      controller.dispose();
    },
  );

  test('Custom seed persists independently of style and mode', () async {
    final storage = MemoryTodoStorage();
    final controller = ThemeController(storage: storage);
    await controller.setSeedColor(const Color(0xFFDA36A7));
    await controller.setStyle(AppearanceStyle.materialYou);
    await controller.setMode(AppearanceMode.dark);
    final reloaded = ThemeController(storage: storage);
    await reloaded.initialize();
    expect(reloaded.seedColor, const Color(0xFFDA36A7));
    expect(reloaded.style, AppearanceStyle.materialYou);
    expect(reloaded.mode, AppearanceMode.dark);
    controller.dispose();
    reloaded.dispose();
  });

  test(
    'Material palettes retain text and button contrast for unusual seeds',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
      }

      for (final seed in [
        Colors.black,
        Colors.white,
        Colors.yellow,
        Colors.cyan,
        Colors.pink,
      ]) {
        for (final brightness in Brightness.values) {
          final colors = AppPalette.fromScheme(
            sometimeColorScheme(brightness, seed: seed),
          );
          expect(
            contrast(colors.text, colors.background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(colors.text, colors.creationSurface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(colors.onAccent, colors.accent),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(colors.onSelected, colors.selected),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    },
  );
}
