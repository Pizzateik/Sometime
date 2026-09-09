import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';

import 'support/sample_todos.dart';

TodoSnapshot snapshotWith(Todo todo) => TodoSnapshot(
  spaces: [
    TodoSpace(id: TodoSpace.defaultId, name: 'todo', todos: [todo]),
  ],
  archive: const [],
  lastKnownLocalDate: DateTime(2026, 9, 4),
);

void main() {
  test('Version two keeps spaces, dates, groups, and archived tasks', () {
    final created = DateTime(2026, 9, 4, 8, 30);
    final completed = DateTime(2026, 9, 4, 9, 45);
    final active = Todo(
      id: 'active',
      title: 'Grüße an José 👋',
      group: TodoGroup.soon,
      createdAt: created,
      sortOrder: 4,
    );
    final archivedTodo = Todo(
      id: 'archive',
      title: 'Archiviert',
      group: TodoGroup.someday,
      originalGroup: TodoGroup.someday,
      createdAt: created,
      completedAt: completed,
      sortOrder: 2,
    );
    final source = TodoSnapshot(
      spaces: [
        TodoSpace(id: TodoSpace.defaultId, name: 'todo', todos: [active]),
      ],
      archive: [
        ArchivedTodo(
          spaceId: TodoSpace.defaultId,
          todo: archivedTodo,
          archivedAt: DateTime(2026, 9, 5),
        ),
      ],
      lastKnownLocalDate: DateTime(2026, 9, 5),
    );

    final restored = LocalTodoStorage.decode(LocalTodoStorage.encode(source));
    expect(restored.spaces.single.id, TodoSpace.defaultId);
    expect(restored.spaces.single.todos.single.toJson(), active.toJson());
    expect(restored.archive.single.todo.toJson(), archivedTodo.toJson());
    expect(restored.lastKnownLocalDate, DateTime(2026, 9, 5));
  });

  test('Version one data migrates into the default space', () {
    final migrationTime = DateTime(2026, 9, 4, 12);
    final source = jsonEncode({
      'version': 1,
      'todos': [
        {
          'id': 'legacy',
          'title': 'Alte Aufgabe',
          'group': 'soon',
          'isComplete': true,
        },
      ],
    });
    final restored = LocalTodoStorage.decode(
      source,
      migrationTime: migrationTime,
    );
    final todo = restored.spaces.single.todos.single;
    expect(restored.spaces.single.id, TodoSpace.defaultId);
    expect(todo.group, TodoGroup.soon);
    expect(todo.originalGroup, TodoGroup.soon);
    expect(todo.createdAt, migrationTime);
    expect(todo.completedAt, migrationTime);
  });

  test('Invalid data cannot silently replace the saved state', () {
    final valid = snapshotWith(
      sampleTodos.first.withCreatedAt(DateTime(2026, 9, 4)),
    );
    final duplicateTodo = valid.spaces.single.todos.first;
    for (final source in [
      'broken JSON',
      '[]',
      '{"version":3}',
      '{"version":2,"spaces":[],"archive":[],"lastKnownLocalDate":"2026-09-04T00:00:00.000"}',
      jsonEncode({
        'version': 2,
        'spaces': [
          {
            ...valid.spaces.single.toJson(),
            'todos': [duplicateTodo.toJson(), duplicateTodo.toJson()],
          },
        ],
        'archive': [],
        'lastKnownLocalDate': '2026-09-04T00:00:00.000',
      }),
      jsonEncode({
        'version': 2,
        'spaces': [valid.spaces.single.toJson()],
        'archive': [],
        'lastKnownLocalDate': '2026-09-04T12:00:00.000',
      }),
    ]) {
      expect(() => LocalTodoStorage.decode(source), throwsFormatException);
    }
  });

  test('Rapid writes keep the last task state', () async {
    final preferences = _ControlledPreferences();
    final storage = LocalTodoStorage(preferences: preferences);
    final firstTodo = sampleTodos.first.withCreatedAt(DateTime(2026, 9, 4));
    final first = storage.save(snapshotWith(firstTodo));
    final second = storage.save(
      snapshotWith(firstTodo.complete(DateTime(2026, 9, 4, 10))),
    );
    await Future<void>.delayed(Duration.zero);
    expect(preferences.writes, hasLength(1));

    preferences.writes.first.completer.complete();
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(preferences.writes, hasLength(2));
    preferences.writes.last.completer.complete();
    await second;

    final restored = await storage.load();
    expect(restored!.spaces.single.todos.single.isComplete, isTrue);
  });

  test('A failed task write does not block the next write', () async {
    final preferences = _ControlledPreferences();
    final storage = LocalTodoStorage(preferences: preferences);
    final first = storage.save(
      snapshotWith(sampleTodos.first.withCreatedAt(DateTime(2026, 9, 4))),
    );
    final failure = expectLater(first, throwsStateError);
    final second = storage.save(
      snapshotWith(sampleTodos.last.withCreatedAt(DateTime(2026, 9, 4))),
    );
    await Future<void>.delayed(Duration.zero);

    preferences.writes.first.completer.completeError(
      StateError('The test write failed.'),
    );
    await failure;
    await Future<void>.delayed(Duration.zero);
    preferences.writes.last.completer.complete();
    await second;
    expect(
      (await storage.load())!.spaces.single.todos.single.id,
      sampleTodos.last.id,
    );
  });

  test('Theme preferences use a separate saved value', () async {
    final preferences = _ControlledPreferences();
    final storage = LocalTodoStorage(preferences: preferences);
    final write = storage.saveThemePreference(ThemePreference.oledBlack);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.writes.single.key, 'theme-preference.v1');
    preferences.writes.single.completer.complete();
    await write;
    expect(await storage.loadThemePreference(), ThemePreference.oledBlack);

    preferences.values['theme-preference.v1'] = 'unknown';
    expect(storage.loadThemePreference(), throwsFormatException);
  });
}

class _PendingWrite {
  _PendingWrite({required this.key, required this.completer});

  final String key;
  final Completer<void> completer;
}

class _ControlledPreferences extends Fake implements SharedPreferencesAsync {
  final writes = <_PendingWrite>[];
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    final completer = Completer<void>();
    writes.add(_PendingWrite(key: key, completer: completer));
    await completer.future;
    values[key] = value;
  }
}
