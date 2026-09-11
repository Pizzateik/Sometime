import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/todo.dart';
import '../models/todo_space.dart';
import '../models/todo_storage.dart';

typedef AppClock = DateTime Function();

class TodoController extends ChangeNotifier {
  TodoController({required this.storage, required this.clock});

  final TodoStorage storage;
  final AppClock clock;

  List<TodoSpace> _spaces = const [];
  List<ArchivedTodo> _archive = const [];
  DateTime? _lastKnownLocalDate;
  bool _ready = false;
  bool _loadFailed = false;
  bool _saveFailed = false;
  bool _disposed = false;
  int _dataVersion = 0;
  int _nextId = 0;
  int _stateRevision = 0;
  int _persistedRevision = 0;
  Future<void>? _pendingPersist;
  static const maxSpaces = 4;
  static const completionDelay = Duration(seconds: 2);
  static const completionExit = Duration(milliseconds: 280);
  final _completionTimers = <String, Timer>{};
  final _exitingTodos = <String>{};
  Timer? _deletionTimer;
  Timer? _dayTimer;
  ({String spaceId, Todo todo, int index})? _pendingDeletion;
  bool get canUndoDeletion => _pendingDeletion != null;

  void deleteTodo(String spaceId, String todoId) {
    final todo = spaceById(spaceId).todos
        .where((todo) => todo.id == todoId)
        .firstOrNull;
    if (todo == null) return;
    _deletionTimer?.cancel();
    _completionTimers.remove(todoId)?.cancel();
    _exitingTodos.remove(todoId);
    _pendingDeletion = (
      spaceId: spaceId,
      todo: todo,
      index: _orderedActive(
        spaceById(spaceId).todos,
        todo.group,
      ).indexWhere((todo) => todo.id == todoId),
    );
    // Save the removal now. A restart ends the undo window.
    _updateSpace(
      spaceId,
      (todos) =>
          _normalizedTodos(todos.where((todo) => todo.id != todoId).toList()),
    );
    _deletionTimer = Timer(const Duration(seconds: 5), () {
      _pendingDeletion = null;
      _notify();
    });
  }

  void undoDeletion() {
    final deleted = _pendingDeletion;
    if (deleted == null) return;
    _deletionTimer?.cancel();
    _pendingDeletion = null;
    _updateSpace(deleted.spaceId, (todos) {
      final ordered = _orderedActive(todos, deleted.todo.group);
      ordered.insert(deleted.index.clamp(0, ordered.length), deleted.todo);
      final replacements = {
        for (var i = 0; i < ordered.length; i++)
          ordered[i].id: ordered[i].withSortOrder(i),
      };
      return [
        for (final todo in todos) replacements[todo.id] ?? todo,
        replacements[deleted.todo.id]!,
      ];
    });
    if (deleted.todo.completedPending) _resumeCompletions();
  }

  bool isCompletionExiting(String id) => _exitingTodos.contains(id);
  bool get canAddSpace => _spaces.length < maxSpaces;

  bool get isReady => _ready;
  bool get loadFailed => _loadFailed;
  bool get saveFailed => _saveFailed;
  int get dataVersion => _dataVersion;
  List<TodoSpace> get spaces => List.unmodifiable(_spaces);
  List<ArchivedTodo> get archive => List.unmodifiable(_archive);
  DateTime get currentLocalDate => localCalendarDate(clock());

  TodoSpace spaceById(String spaceId) =>
      _spaces.where((space) => space.id == spaceId).firstOrNull ??
      _spaces.first;

  TodoSpace? spaceByIdOrNull(String spaceId) =>
      _spaces.where((space) => space.id == spaceId).firstOrNull;

  List<Todo> activeTodos(String spaceId, TodoGroup group) =>
      List.unmodifiable(_orderedActive(spaceById(spaceId).todos, group));

  List<Todo> widgetTodos(String spaceId, TodoGroup group) => List.unmodifiable(
    _orderedActive(spaceById(spaceId).todos, group, includeFuture: true),
  );

  List<Todo> completedTodos(String spaceId) => List.unmodifiable(
    spaceById(spaceId).todos
        .where((todo) => todo.isComplete && !todo.completedPending),
  );

  Future<void> initialize() async {
    _deletionTimer?.cancel();
    _pendingDeletion = null;
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    _exitingTodos.clear();
    _loadFailed = false;
    _notify();
    try {
      final now = clock();
      final saved = await storage.load();
      if (_disposed) return;
      final snapshot = saved ?? TodoSnapshot.seeded(now);
      _dataVersion++;
      final repairedEmptySpaces = snapshot.spaces.isEmpty;
      _spaces = repairedEmptySpaces
          ? [TodoSpace.seeded(now)]
          : List.of(snapshot.spaces);
      _archive = repairedEmptySpaces ? [] : List.of(snapshot.archive);
      _lastKnownLocalDate = snapshot.lastKnownLocalDate;
      _resumeCompletions();
      final normalizedOrder = _normalizeSortOrders();
      _ready = true;
      _loadFailed = false;
      final changedDay = _applyDayChange(now);
      _scheduleDayCheck();
      _notify();
      if (saved == null ||
          repairedEmptySpaces ||
          changedDay ||
          normalizedOrder) {
        _stateRevision++;
        unawaited(_persist());
      }
    } catch (_) {
      if (_disposed) return;
      _loadFailed = true;
      _notify();
    }
  }

  Future<void> handleResume() async {
    if (!_ready) return;
    _resumeCompletions();
    if (_applyDayChange(clock())) {
      _stateRevision++;
      _notify();
      await _persist();
    }
    _scheduleDayCheck();
  }

  void _scheduleDayCheck() {
    _dayTimer?.cancel();
    if (_disposed || !_ready) return;
    final now = clock();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(
      midnight.difference(now),
      () => unawaited(handleResume()),
    );
  }

  String addSpace(String name) {
    if (!canAddSpace) throw StateError('The space limit is reached.');
    final trimmed = TodoSpace.normalizedName(name);
    if (trimmed.isEmpty) throw ArgumentError('The space name is empty.');
    String id;
    do {
      id = 'space-${clock().microsecondsSinceEpoch}-${_nextId++}';
    } while (_spaces.any((space) => space.id == id));
    _stateRevision++;
    _spaces = [..._spaces, TodoSpace(id: id, name: trimmed, todos: const [])];
    _notify();
    unawaited(_persist());
    return id;
  }

  void renameSpace(String spaceId, String name) {
    final trimmed = TodoSpace.normalizedName(name);
    if (trimmed.isEmpty) throw ArgumentError('The space name is empty.');
    _stateRevision++;
    _spaces = [
      for (final space in _spaces)
        if (space.id == spaceId)
          TodoSpace(id: space.id, name: trimmed, todos: space.todos)
        else
          space,
    ];
    _notify();
    unawaited(_persist());
  }

  Future<bool> deleteSpace(String spaceId) async {
    if (_spaces.length <= 1) return false;
    final deleted = _spaces.where((space) => space.id == spaceId).firstOrNull;
    if (deleted == null) return false;

    final deletedTodoIds = deleted.todos.map((todo) => todo.id).toSet();
    for (final todoId in deletedTodoIds) {
      _completionTimers.remove(todoId)?.cancel();
      _exitingTodos.remove(todoId);
    }
    if (_pendingDeletion?.spaceId == spaceId) {
      _deletionTimer?.cancel();
      _pendingDeletion = null;
    }
    _archive = _archive
        .where((entry) => entry.spaceId != spaceId)
        .toList(growable: false);
    _stateRevision++;
    _spaces = [
      for (final space in _spaces)
        if (space.id != spaceId) space,
    ];
    _notify();
    _scheduleDayCheck();
    await _persist();
    return true;
  }

  String addTodo(String spaceId, TodoDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('The task title is empty.');
    }
    final now = clock();
    final id = '${now.microsecondsSinceEpoch}-${_nextId++}';
    _updateSpace(spaceId, (todos) {
      final groupTodos = _orderedActive(todos, draft.group);
      return [
        ...todos,
        Todo(
          id: id,
          title: draft.title.trim(),
          group: draft.group,
          createdAt: now,
          sortOrder: groupTodos.length,
          details: draft.details,
          routineId: draft.details.recurrence == null ? null : id,
          isPinned: draft.isPinned,
        ),
      ];
    });
    return id;
  }

  void updateTodo(String spaceId, String todoId, TodoDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('The task title is empty.');
    }
    _updateSpace(spaceId, (todos) {
      final current = todos.where((todo) => todo.id == todoId).firstOrNull;
      if (current == null || current.isComplete) return todos;
      final groupChanged = current.group != draft.group;
      final targetOrder = groupChanged
          ? _orderedActive(todos, draft.group).length
          : current.sortOrder;
      final updated = [
        for (final todo in todos)
          if (todo.id == todoId)
            todo.update(
              title: draft.title,
              group: draft.group,
              sortOrder: targetOrder,
              details: draft.details,
              isPinned: draft.isPinned,
            )
          else
            todo,
      ];
      return _normalizedTodos(updated);
    });
  }

  void moveTodo(
    String spaceId,
    String todoId, {
    required TodoGroup group,
    required int index,
  }) {
    _updateSpace(spaceId, (todos) {
      final moving = todos.where((todo) => todo.id == todoId).firstOrNull;
      if (moving == null || moving.isComplete) return todos;

      final source = _orderedActive(todos, moving.group);
      final oldIndex = source.indexWhere((todo) => todo.id == todoId);
      var insertionIndex = index;
      if (moving.group == group && oldIndex < insertionIndex) {
        insertionIndex--;
      }

      final target = _orderedActive(
        todos.where((todo) => todo.id != todoId).toList(),
        group,
      );
      insertionIndex = insertionIndex.clamp(0, target.length);
      target.insert(
        insertionIndex,
        moving.update(
          title: moving.title,
          group: group,
          sortOrder: insertionIndex,
        ),
      );

      final replacements = <String, Todo>{};
      if (moving.group != group) {
        final remainingSource = source
            .where((todo) => todo.id != todoId)
            .toList(growable: false);
        for (var i = 0; i < remainingSource.length; i++) {
          replacements[remainingSource[i].id] = remainingSource[i]
              .withSortOrder(i);
        }
      }
      for (var i = 0; i < target.length; i++) {
        replacements[target[i].id] = target[i].withSortOrder(i);
      }
      return [for (final todo in todos) replacements[todo.id] ?? todo];
    });
  }

  bool moveTodoToSpace(
    String sourceSpaceId,
    String todoId,
    String destinationSpaceId, {
    TodoGroup? group,
    int? index,
  }) {
    if (sourceSpaceId == destinationSpaceId) return false;
    final source = spaceByIdOrNull(sourceSpaceId);
    final destination = spaceByIdOrNull(destinationSpaceId);
    if (source == null || destination == null) return false;
    if (destination.todos.any((todo) => todo.id == todoId)) return false;
    final todo = source.todos.where((todo) => todo.id == todoId).firstOrNull;
    if (todo == null) return false;

    final destinationGroup = group ?? todo.group;
    final destinationGroupTodos = _orderedActive(
      destination.todos,
      destinationGroup,
      includeFuture: true,
    );
    final destinationOrder = (index ?? destinationGroupTodos.length).clamp(
      0,
      destinationGroupTodos.length,
    );
    final moved = destinationGroup == todo.group
        ? todo.withSortOrder(destinationOrder)
        : todo.update(
            title: todo.title,
            group: destinationGroup,
            sortOrder: destinationOrder,
            details: todo.details,
            isPinned: todo.isPinned,
          );
    final sourceTodos = _normalizedTodos(
      source.todos.where((entry) => entry.id != todoId).toList(),
    );
    destinationGroupTodos.insert(destinationOrder, moved);
    final destinationReplacements = <String, Todo>{};
    for (var i = 0; i < destinationGroupTodos.length; i++) {
      destinationReplacements[destinationGroupTodos[i].id] =
          destinationGroupTodos[i].withSortOrder(i);
    }
    final destinationTodos = _normalizedTodos([
      for (final entry in destination.todos)
        destinationReplacements[entry.id] ?? entry,
      if (!destination.todos.any((entry) => entry.id == todoId))
        destinationReplacements[todoId]!,
    ]);

    _stateRevision++;
    _spaces = [
      for (final space in _spaces)
        if (space.id == sourceSpaceId)
          space.withTodos(sourceTodos)
        else if (space.id == destinationSpaceId)
          space.withTodos(destinationTodos)
        else
          space,
    ];
    _notify();
    _scheduleDayCheck();
    unawaited(_persist());
    return true;
  }

  void toggleTodo(String spaceId, String todoId) {
    final now = clock();
    final current = spaceById(spaceId).todos
        .where((todo) => todo.id == todoId)
        .firstOrNull;
    if (current == null) return;
    final series = current.routineId ?? current.id;
    final successors = spaceById(spaceId).todos
        .where(
          (todo) =>
              todo.id != current.id &&
              todo.routineId == series &&
              todo.availableFrom != null &&
              (current.availableFrom == null ||
                  todo.availableFrom!.isAfter(current.availableFrom!)),
        )
        .toList();
    final pendingIds = current.isComplete
        ? successors
              .where(
                (todo) =>
                    !todo.isComplete &&
                    todo.availableFrom != null &&
                    todo.availableFrom!.isAfter(now),
              )
              .map((todo) => todo.id)
              .toSet()
        : <String>{};
    final newerOccurrence = successors.any(
      (todo) => !pendingIds.contains(todo.id),
    );
    _completionTimers.remove(todoId)?.cancel();
    _exitingTodos.remove(todoId);
    _updateSpace(
      spaceId,
      (todos) => _normalizedTodos([
        for (final todo in todos)
          if (pendingIds.contains(todo.id))
            ...<Todo>[]
          else if (todo.id == todoId)
            todo.isComplete
                ? todo.restore().update(
                    title: todo.title,
                    group: todo.originalGroup,
                    sortOrder: todo.sortOrder,
                    details: newerOccurrence
                        ? todo.details.withoutRecurrence()
                        : todo.details,
                  )
                : todo.complete(now, pending: true)
          else
            todo,
      ]),
    );
    final todo = spaceById(spaceId).todos
        .where((todo) => todo.id == todoId)
        .firstOrNull;
    if (todo != null && todo.completedPending) {
      _scheduleCompletion(spaceId, todo);
    }
  }

  void _resumeCompletions() {
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    _exitingTodos.clear();
    for (final space in List.of(_spaces)) {
      for (final todo in space.todos.where((todo) => todo.completedPending)) {
        if (clock().difference(todo.completedAt!) >= completionDelay) {
          _finishCompletion(space.id, todo);
        } else {
          _scheduleCompletion(space.id, todo);
        }
      }
    }
    _notify();
  }

  void _scheduleCompletion(String spaceId, Todo todo) {
    final remaining = completionDelay - clock().difference(todo.completedAt!);
    _completionTimers[todo.id] = Timer(remaining, () {
      if (!_isPending(spaceId, todo)) return;
      _exitingTodos.add(todo.id);
      _notify();
      _completionTimers[todo.id] = Timer(completionExit, () {
        _finishCompletion(spaceId, todo);
      });
    });
  }

  bool _isPending(String spaceId, Todo expected) =>
      !_disposed &&
      spaceById(spaceId).todos.any(
        (todo) =>
            todo.id == expected.id &&
            todo.completedPending &&
            todo.completedAt == expected.completedAt,
      );

  void _finishCompletion(String spaceId, Todo expected) {
    if (!_isPending(spaceId, expected)) return;
    _completionTimers.remove(expected.id)?.cancel();
    _exitingTodos.remove(expected.id);
    final rule = expected.details.recurrence;
    final planned = expected.details.date;
    final completed = expected.completedAt!;
    final nextDate = rule?.nextAfter(
      planned != null && planned.isAfter(completed) ? planned : completed,
    );
    final series = expected.routineId ?? expected.id;
    final nextId = nextDate == null
        ? null
        : '$series-${nextDate.toIso8601String()}';
    _updateSpace(
      spaceId,
      (todos) => _normalizedTodos([
        for (final todo in todos)
          todo.id == expected.id ? todo.complete(todo.completedAt!) : todo,
        if (nextDate != null && !todos.any((todo) => todo.id == nextId))
          Todo(
            id: nextId!,
            title: expected.title,
            group: expected.group,
            createdAt: completed,
            sortOrder: expected.sortOrder,
            details: expected.details.onDate(nextDate),
            availableFrom: nextDate,
            routineId: series,
            isPinned: expected.isPinned,
          ),
      ]),
    );
  }

  void setPinned(String spaceId, String todoId, bool value) {
    _updateSpace(
      spaceId,
      (todos) => [
        for (final todo in todos)
          if (todo.id == todoId && !todo.isComplete)
            todo.update(
              title: todo.title,
              group: todo.group,
              sortOrder: todo.sortOrder,
              isPinned: value,
            )
          else
            todo,
      ],
    );
  }

  void rollForwardRoutines() {
    final today = currentLocalDate;
    for (final space in List.of(_spaces)) {
      final replacements = <String, Todo>{};
      for (final todo in space.todos) {
        final rule = todo.details.recurrence;
        final date = todo.details.date;
        if (todo.isComplete ||
            rule == null ||
            date == null ||
            !date.isBefore(today)) {
          continue;
        }
        final next = rule.nextAfter(
          DateTime(today.year, today.month, today.day - 1),
        );
        replacements[todo.id] = todo.update(
          title: todo.title,
          group: todo.group,
          sortOrder: todo.sortOrder,
          details: todo.details.onDate(next),
        );
      }
      if (replacements.isNotEmpty) {
        _updateSpace(
          space.id,
          (todos) => [for (final todo in todos) replacements[todo.id] ?? todo],
        );
      }
    }
  }

  Future<void> completeFromNotification(String spaceId, String todoId) async {
    final todo = spaceById(spaceId).todos
        .where((t) => t.id == todoId)
        .firstOrNull;
    if (todo == null || todo.isComplete) return;
    toggleTodo(spaceId, todoId);
    final updated = spaceById(spaceId).todos
        .where((t) => t.id == todoId)
        .firstOrNull;
    if (updated != null) {
      _finishCompletion(spaceId, updated);
    }
    await flush();
  }

  Future<void> flush() async {
    while (_stateRevision > _persistedRevision && !_saveFailed) {
      await _persist();
    }
    if (_saveFailed) throw StateError('The task state could not be saved.');
  }

  Future<void> retrySave() => _persist();

  Future<void> deleteAllData() async {
    _deletionTimer?.cancel();
    _pendingDeletion = null;
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    _exitingTodos.clear();
    _archive = const [];
    _spaces = [
      TodoSpace(id: TodoSpace.defaultId, name: 'Sometime', todos: const []),
    ];
    _lastKnownLocalDate = currentLocalDate;
    _stateRevision++;
    _notify();
    await _persist();
  }

  void _updateSpace(String spaceId, List<Todo> Function(List<Todo>) update) {
    _stateRevision++;
    _spaces = [
      for (final space in _spaces)
        space.id == spaceId ? space.withTodos(update(space.todos)) : space,
    ];
    _notify();
    _scheduleDayCheck();
    unawaited(_persist());
  }

  bool _applyDayChange(DateTime now) {
    final today = localCalendarDate(now);
    final archiveCount = _archive.length;
    _archive = _archive
        .where(
          (entry) =>
              now.difference(entry.todo.completedAt!) < const Duration(days: 7),
        )
        .toList();
    if (_lastKnownLocalDate != null &&
        isSameLocalDate(_lastKnownLocalDate!, today)) {
      return archiveCount != _archive.length;
    }

    final additions = <ArchivedTodo>[];
    final updatedSpaces = <TodoSpace>[];
    for (final space in _spaces) {
      final visibleTodos = <Todo>[];
      for (final todo in space.todos) {
        if (!todo.isComplete ||
            todo.completedPending ||
            isSameLocalDate(todo.completedAt!, today)) {
          visibleTodos.add(todo);
        } else {
          additions.add(
            ArchivedTodo(spaceId: space.id, todo: todo, archivedAt: now),
          );
        }
      }
      updatedSpaces.add(space.withTodos(visibleTodos));
    }
    _spaces = updatedSpaces;
    _archive = [..._archive, ...additions]
        .where(
          (entry) =>
              now.difference(entry.todo.completedAt!) < const Duration(days: 7),
        )
        .toList();
    _lastKnownLocalDate = today;
    return true;
  }

  bool _normalizeSortOrders() {
    var changed = false;
    _spaces = [
      for (final space in _spaces)
        space.withTodos(
          _normalizedTodos(space.todos, onChange: () => changed = true),
        ),
    ];
    return changed;
  }

  List<Todo> _normalizedTodos(List<Todo> todos, {VoidCallback? onChange}) {
    final replacements = <String, Todo>{};
    for (final group in TodoGroup.values) {
      final ordered = _orderedActive(todos, group, includeFuture: true);
      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i].sortOrder == i) continue;
        replacements[ordered[i].id] = ordered[i].withSortOrder(i);
        onChange?.call();
      }
    }
    if (replacements.isEmpty) return todos;
    return [for (final todo in todos) replacements[todo.id] ?? todo];
  }

  List<Todo> _orderedActive(
    List<Todo> todos,
    TodoGroup group, {
    bool includeFuture = false,
  }) {
    final indexed = <({int index, Todo todo})>[];
    for (var i = 0; i < todos.length; i++) {
      final todo = todos[i];
      if ((!todo.isComplete || todo.completedPending) &&
          todo.group == group &&
          (includeFuture ||
              todo.availableFrom == null ||
              !todo.availableFrom!.isAfter(clock()))) {
        indexed.add((index: i, todo: todo));
      }
    }
    indexed.sort((first, second) {
      final order = first.todo.sortOrder.compareTo(second.todo.sortOrder);
      return order != 0 ? order : first.index.compareTo(second.index);
    });
    return [for (final entry in indexed) entry.todo];
  }

  TodoSnapshot get snapshot => _snapshot;

  TodoSnapshot get _snapshot => TodoSnapshot(
    spaces: List.unmodifiable(_spaces),
    archive: List.unmodifiable(_archive),
    lastKnownLocalDate: _lastKnownLocalDate ?? currentLocalDate,
  );

  Future<void> _persist() {
    if (_persistedRevision == _stateRevision && !_saveFailed) {
      return Future<void>.value();
    }
    if (_pendingPersist != null) {
      return _pendingPersist!;
    }
    final targetRevision = _stateRevision;
    final future = () async {
      try {
        await storage.save(_snapshot);
        if (_disposed) return;
        _persistedRevision = targetRevision;
        if (_saveFailed) {
          _saveFailed = false;
          _notify();
        }
      } catch (_) {
        if (_disposed) return;
        _saveFailed = true;
        _notify();
      } finally {
        _pendingPersist = null;
        if (!_saveFailed && _stateRevision > _persistedRevision && !_disposed) {
          unawaited(_persist());
        }
      }
    }();
    _pendingPersist = future;
    return future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deletionTimer?.cancel();
    _dayTimer?.cancel();
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
