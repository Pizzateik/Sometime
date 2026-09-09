import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'todo.dart';

@immutable
class TodoSpace {
  const TodoSpace({required this.id, required this.name, required this.todos});

  static const defaultId = 'default-space';
  static const maxNameLength = 10;
  static String normalizedName(String value) =>
      value.trim().characters.take(maxNameLength).toString();

  final String id;
  final String name;
  final List<Todo> todos;

  TodoSpace withTodos(List<Todo> value) =>
      TodoSpace(id: id, name: name, todos: List.unmodifiable(value));

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'todos': todos.map((todo) => todo.toJson()).toList(),
  };

  factory TodoSpace.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final entries = json['todos'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        entries is! List) {
      throw const FormatException('The todo space is not valid.');
    }
    return TodoSpace(
      id: id,
      name: normalizedName(name),
      todos: List.unmodifiable(
        entries.map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('The saved task is not valid.');
          }
          return Todo.fromJson(entry);
        }),
      ),
    );
  }

  factory TodoSpace.seeded(DateTime _) =>
      const TodoSpace(id: defaultId, name: 'Sometime', todos: []);
}

@immutable
class ArchivedTodo {
  const ArchivedTodo({
    required this.spaceId,
    required this.todo,
    required this.archivedAt,
  });

  final String spaceId;
  final Todo todo;
  final DateTime archivedAt;

  Map<String, Object> toJson() => {
    'spaceId': spaceId,
    'todo': todo.toJson(),
    'archivedAt': archivedAt.toIso8601String(),
  };

  factory ArchivedTodo.fromJson(Map<String, dynamic> json) {
    final spaceId = json['spaceId'];
    final todoJson = json['todo'];
    final archivedAtValue = json['archivedAt'];
    final archivedAt = archivedAtValue is String
        ? DateTime.tryParse(archivedAtValue)
        : null;
    if (spaceId is! String ||
        spaceId.isEmpty ||
        todoJson is! Map<String, dynamic> ||
        archivedAt == null) {
      throw const FormatException('The archived task is not valid.');
    }
    return ArchivedTodo(
      spaceId: spaceId,
      todo: Todo.fromJson(todoJson),
      archivedAt: archivedAt,
    );
  }
}

@immutable
class TodoSnapshot {
  const TodoSnapshot({
    required this.spaces,
    required this.archive,
    required this.lastKnownLocalDate,
  });

  final List<TodoSpace> spaces;
  final List<ArchivedTodo> archive;
  final DateTime lastKnownLocalDate;

  factory TodoSnapshot.seeded(DateTime time) => TodoSnapshot(
    spaces: [TodoSpace.seeded(time)],
    archive: const [],
    lastKnownLocalDate: localCalendarDate(time),
  );
}

DateTime localCalendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameLocalDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
