import 'package:flutter/foundation.dart';

import 'task_details.dart';

enum TodoGroup {
  today('Heute'),
  soon('Demnächst'),
  someday('Irgendwann');

  const TodoGroup(this.label);

  final String label;
}

@immutable
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.group,
    required this.createdAt,
    TodoGroup? originalGroup,
    this.completedAt,
    this.completedPending = false,
    this.sortOrder = 0,
    this.details = const TaskDetails(),
    this.availableFrom,
    this.routineId,
    this.isPinned = false,
  }) : originalGroup = originalGroup ?? group;

  final String id;
  final String title;
  final TodoGroup group;
  final TodoGroup originalGroup;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool completedPending;
  final int sortOrder;
  final TaskDetails details;
  final DateTime? availableFrom;
  final String? routineId;
  final bool isPinned;

  bool get isComplete => completedAt != null;

  Todo complete(DateTime time, {bool pending = false}) => Todo(
    id: id,
    title: title,
    details: details,
    availableFrom: availableFrom,
    routineId: routineId,
    isPinned: details.recurrence != null && isPinned,
    group: group,
    originalGroup: group,
    createdAt: createdAt,
    completedAt: time,
    completedPending: pending,
    sortOrder: sortOrder,
  );

  Todo restore() => Todo(
    id: id,
    title: title,
    details: details,
    availableFrom: availableFrom,
    routineId: routineId,
    isPinned: isPinned,
    group: originalGroup,
    originalGroup: originalGroup,
    createdAt: createdAt,
    sortOrder: sortOrder,
  );

  Todo withCreatedAt(DateTime time) => Todo(
    id: id,
    title: title,
    details: details,
    availableFrom: availableFrom,
    routineId: routineId,
    isPinned: isPinned,
    group: group,
    originalGroup: originalGroup,
    createdAt: time,
    completedAt: completedAt,
    completedPending: completedPending,
    sortOrder: sortOrder,
  );

  Todo withSortOrder(int value) => Todo(
    id: id,
    title: title,
    details: details,
    availableFrom: availableFrom,
    routineId: routineId,
    isPinned: isPinned,
    group: group,
    originalGroup: originalGroup,
    createdAt: createdAt,
    completedAt: completedAt,
    completedPending: completedPending,
    sortOrder: value,
  );

  Todo update({
    required String title,
    required TodoGroup group,
    required int sortOrder,
    TaskDetails? details,
    bool? isPinned,
  }) => Todo(
    id: id,
    title: title.trim(),
    details: details ?? this.details,
    availableFrom: availableFrom,
    routineId: routineId,
    isPinned: isPinned ?? this.isPinned,
    group: group,
    originalGroup: group,
    createdAt: createdAt,
    completedAt: completedAt,
    completedPending: completedPending,
    sortOrder: sortOrder,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'group': group.name,
    'originalGroup': originalGroup.name,
    'isComplete': isComplete,
    'completedPending': completedPending,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'sortOrder': sortOrder,
    'details': details.toJson(),
    'availableFrom': availableFrom?.toIso8601String(),
    'routineId': routineId,
    'isPinned': isPinned,
  };

  factory Todo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final group = _parseGroup(json['group']);
    final originalGroup = _parseGroup(json['originalGroup']);
    final isComplete = json['isComplete'];
    final createdAt = _parseDate(json['createdAt']);
    final completedAt = _parseNullableDate(json['completedAt']);
    final sortOrderValue = json['sortOrder'];
    final sortOrder = sortOrderValue ?? 0;
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        group == null ||
        originalGroup == null ||
        isComplete is! bool ||
        sortOrder is! int ||
        sortOrder < 0 ||
        createdAt == null ||
        isComplete != (completedAt != null)) {
      throw const FormatException('The task data is not valid.');
    }
    return Todo(
      id: id,
      title: title.trim(),
      details: TaskDetails.fromJson(json['details']),
      availableFrom: _parseNullableDate(json['availableFrom']),
      routineId: json['routineId'] as String?,
      isPinned: json['isPinned'] == true,
      group: group,
      originalGroup: originalGroup,
      createdAt: createdAt,
      completedAt: completedAt,
      completedPending: completedAt != null && json['completedPending'] == true,
      sortOrder: sortOrder,
    );
  }

  factory Todo.fromVersionOneJson(
    Map<String, dynamic> json,
    DateTime migrationTime,
  ) {
    final id = json['id'];
    final title = json['title'];
    final group = _parseGroup(json['group']);
    final isComplete = json['isComplete'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        group == null ||
        isComplete is! bool) {
      throw const FormatException('The task data is not valid.');
    }
    return Todo(
      id: id,
      title: title.trim(),
      details: TaskDetails.fromJson(json['details']),
      availableFrom: _parseNullableDate(json['availableFrom']),
      routineId: json['routineId'] as String?,
      isPinned: json['isPinned'] == true,
      group: group,
      originalGroup: group,
      createdAt: migrationTime,
      completedAt: isComplete ? migrationTime : null,
      sortOrder: 0,
    );
  }

  static TodoGroup? _parseGroup(Object? value) {
    for (final group in TodoGroup.values) {
      if (group.name == value) return group;
    }
    return null;
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) return null;
    return _parseDate(value);
  }
}

@immutable
class TodoDraft {
  const TodoDraft({
    required this.title,
    required this.group,
    this.details = const TaskDetails(),
    this.isPinned = false,
  });

  final TaskDetails details;

  final String title;
  final TodoGroup group;
  final bool isPinned;

  TodoDraft copyWith({
    String? title,
    TodoGroup? group,
    TaskDetails? details,
    bool? isPinned,
  }) => TodoDraft(
    title: title ?? this.title,
    group: group ?? this.group,
    details: details ?? this.details,
    isPinned: isPinned ?? this.isPinned,
  );
}
