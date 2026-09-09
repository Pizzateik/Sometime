import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';
import 'package:todo_app/services/backup_data.dart';
import 'package:todo_app/services/data_transfer.dart';
import 'package:todo_app/services/widget_bridge.dart';
import 'package:todo_app/state/settings_controller.dart';
import 'package:todo_app/state/theme_controller.dart';
import 'package:todo_app/state/todo_controller.dart';

import 'support/memory_todo_storage.dart';

void main() {
  final now = DateTime(2026, 9, 6, 10);
  final task = Todo(
    id: 'a',
    title: 'Äpfel kaufen',
    group: TodoGroup.soon,
    createdAt: now,
    isPinned: true,
    details: TaskDetails(
      description: 'Zwei',
      date: DateTime(2026, 9, 7),
      minutes: 870,
      reminder: ReminderRule.none,
      recurrence: const RecurrenceRule(
        type: RecurrenceType.weekly,
        weekdays: [1, 3],
      ),
    ),
  );
  final snapshot = TodoSnapshot(
    spaces: [
      TodoSpace(id: 'work', name: 'Arbeit', todos: [task]),
    ],
    archive: const [],
    lastKnownLocalDate: DateTime(2026, 9, 6),
  );
  const appearance = AppearancePreference(
    mode: AppearanceMode.dark,
    style: AppearanceStyle.materialYou,
  );
  final backup = BackupData(
    snapshot,
    const AppSettings(
      displayName: 'Eik',
      isSupporter: true,
      membershipGradientIndex: 4,
    ),
    appearance,
  );

  test('A backup preserves task details and excludes store entitlement', () {
    final encoded = backup.encode(now: now);
    final restored = BackupData.decode(encoded);
    expect(
      restored.snapshot.spaces.single.todos.single.toJson(),
      task.toJson(),
    );
    expect(restored.settings.displayName, 'Eik');
    expect(restored.settings.membershipGradientIndex, 4);
    expect(restored.settings.isSupporter, false);
    expect(
      jsonDecode(encoded)['preferences'].containsKey('isSupporter'),
      false,
    );
    expect(restored.appearance.style, AppearanceStyle.materialYou);
  });
  test('Invalid and unsupported backups fail before storage changes', () {
    for (final source in [
      '{',
      '{}',
      backup.encode().replaceFirst('"version":1', '"version":7'),
      backup.encode().replaceFirst('"spaceId":"work"', '"spaceId":"missing"'),
    ]) {
      expect(() => BackupData.decode(source), throwsFormatException);
    }
    final missing = jsonDecode(backup.encode()) as Map<String, dynamic>;
    missing.remove('preferences');
    missing.remove('archive');
    expect(
      BackupData.decode(jsonEncode(missing)).settings.hapticsEnabled,
      true,
    );
    missing['preferences'] = {'isSupporter': true};
    expect(BackupData.decode(jsonEncode(missing)).settings.isSupporter, false);
  });
  test(
    'Widget snapshots exclude completed tasks and retain future availability',
    () async {
      final memory = MemoryTodoStorage(snapshot: snapshot);
      final controller = TodoController(storage: memory, clock: () => now);
      await controller.initialize();
      final data = widgetSnapshot(controller, 'de', 'dark');
      final row = ((data['spaces'] as List).single['tasks'] as List).single;
      expect(row['category'], 'soon');
      expect(row['description'], 'Zwei');
      expect(row['minutes'], 870);
      var changes = 0;
      controller.addListener(() => changes++);
      controller.updateTodo(
        'work',
        'a',
        const TodoDraft(
          title: 'Äpfel kaufen',
          group: TodoGroup.soon,
          details: TaskDetails(description: '  Neue Beschreibung  '),
        ),
      );
      var editedRow =
          ((widgetSnapshot(controller, 'de', 'dark')['spaces'] as List)
                      .single['tasks']
                  as List)
              .single;
      expect(changes, 1);
      expect(editedRow['description'], 'Neue Beschreibung');
      controller.updateTodo(
        'work',
        'a',
        const TodoDraft(
          title: 'Äpfel kaufen',
          group: TodoGroup.soon,
          details: TaskDetails(description: '   '),
        ),
      );
      editedRow =
          ((widgetSnapshot(controller, 'de', 'dark')['spaces'] as List)
                      .single['tasks']
                  as List)
              .single;
      expect(changes, 2);
      expect(editedRow['description'], isEmpty);
      controller.updateTodo(
        'work',
        'a',
        TodoDraft(
          title: task.title,
          group: task.group,
          details: task.details,
          isPinned: task.isPinned,
        ),
      );
      await controller.completeFromNotification('work', 'a');
      final tasks =
          ((widgetSnapshot(controller, 'en', 'light')['spaces'] as List)
                  .single['tasks']
              as List);
      expect(tasks.every((t) => t['id'] != 'a'), true);
      expect(tasks.single['available'], isNotNull);
      controller.dispose();
    },
  );
  test(
    'Import replaces one local bundle and preserves the current entitlement',
    () async {
      final preferences = _Preferences();
      final storage = LocalTodoStorage(preferences: preferences);
      final todos = TodoController(storage: storage, clock: () => now);
      final settings = SettingsController(storage: storage);
      final theme = ThemeController(storage: storage);
      await todos.initialize();
      await settings.initialize();
      await theme.initialize();
      await settings.grantSupporter(shapeCount: 3, gradientCount: 16);
      final transfer = DataTransfer(todos, settings, theme);
      preferences.fail = true;
      await expectLater(
        transfer.import(BackupData.decode(backup.encode())),
        throwsA(anything),
      );
      expect(todos.spaces.first.id, TodoSpace.defaultId);
      preferences.fail = false;
      await transfer.import(BackupData.decode(backup.encode()));
      expect(todos.spaces.single.id, 'work');
      expect(settings.value.isSupporter, true);
      expect(settings.value.displayName, 'Eik');
      expect(theme.mode, AppearanceMode.dark);
      expect((await storage.load())!.spaces.single.id, 'work');
      todos.dispose();
      settings.dispose();
      theme.dispose();
    },
  );
}

// ignore: must_be_immutable
class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, Object>{};
  bool fail = false;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<void> setString(String key, String value) async {
    if (fail) throw StateError('The test write failed.');
    values[key] = value;
  }
}
