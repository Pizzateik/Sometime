import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';
import 'package:todo_app/state/todo_controller.dart';

import 'support/memory_todo_storage.dart';

Todo todo(String id, TodoGroup group, int sortOrder) => Todo(
  id: id,
  title: id.toUpperCase(),
  group: group,
  createdAt: DateTime(2026, 9, 4),
  sortOrder: sortOrder,
);

TodoSnapshot snapshot(List<Todo> todos) => TodoSnapshot(
  spaces: [TodoSpace(id: TodoSpace.defaultId, name: 'todo', todos: todos)],
  archive: const [],
  lastKnownLocalDate: DateTime(2026, 9, 4),
);

void main() {
  test(
    'New spaces keep their IDs, order, and tasks in local storage',
    () async {
      final storage = MemoryTodoStorage();
      final controller = TodoController(
        storage: storage,
        clock: () => DateTime(2026, 9, 4),
      );
      await controller.initialize();
      final work = controller.addSpace(' Arbeit ');
      final home = controller.addSpace('Privat');
      controller.addTodo(
        work,
        const TodoDraft(title: 'Work task', group: TodoGroup.today),
      );
      controller.addTodo(
        home,
        const TodoDraft(title: 'Home task', group: TodoGroup.soon),
      );
      await controller.retrySave();
      final restored = LocalTodoStorage.decode(
        LocalTodoStorage.encode(storage.snapshot!),
      );
      expect(restored.spaces.map((space) => space.id), [
        TodoSpace.defaultId,
        work,
        home,
      ]);
      expect(restored.spaces.map((space) => space.name), [
        'Sometime',
        'Arbeit',
        'Privat',
      ]);
      expect(restored.spaces[1].todos.single.title, 'Work task');
      expect(restored.spaces[2].todos.single.title, 'Home task');
      controller.dispose();
    },
  );

  test('Deleting a Space removes its tasks and keeps one Space', () async {
    final now = DateTime(2026, 9, 4, 10);
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          const TodoSpace(id: TodoSpace.defaultId, name: 'Sometime', todos: []),
          TodoSpace(
            id: 'work-id',
            name: 'Work',
            todos: [
              Todo(
                id: 'work-task',
                title: 'Work task',
                group: TodoGroup.today,
                createdAt: now,
              ),
            ],
          ),
        ],
        archive: [
          ArchivedTodo(
            spaceId: 'work-id',
            todo: Todo(
              id: 'work-archived',
              title: 'Archived work task',
              group: TodoGroup.today,
              createdAt: now,
              completedAt: now,
            ),
            archivedAt: now,
          ),
        ],
        lastKnownLocalDate: now,
      ),
    );
    final controller = TodoController(storage: storage, clock: () => now);
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(await controller.deleteSpace('work-id'), isTrue);
    expect(controller.spaces.map((space) => space.id), [TodoSpace.defaultId]);
    expect(controller.archive, isEmpty);
    expect(storage.snapshot!.spaces.map((space) => space.id), [
      TodoSpace.defaultId,
    ]);
    expect(await controller.deleteSpace(TodoSpace.defaultId), isFalse);
  });

  test(
    'Editing updates the title and moves the task to the group end',
    () async {
      final storage = MemoryTodoStorage(
        snapshot: snapshot([
          todo('a', TodoGroup.today, 0),
          todo('b', TodoGroup.soon, 0),
        ]),
      );
      final controller = TodoController(
        storage: storage,
        clock: () => DateTime(2026, 9, 4, 10),
      );
      await controller.initialize();

      controller.updateTodo(
        TodoSpace.defaultId,
        'a',
        const TodoDraft(title: 'Geändert', group: TodoGroup.soon),
      );
      await Future<void>.delayed(Duration.zero);

      final soon = controller.activeTodos(TodoSpace.defaultId, TodoGroup.soon);
      expect(soon.map((item) => item.title), ['B', 'Geändert']);
      expect(soon.map((item) => item.sortOrder), [0, 1]);
      final saved = storage.snapshot!.spaces.single.todos.singleWhere(
        (item) => item.id == 'a',
      );
      expect(saved.title, 'Geändert');
      expect(saved.group, TodoGroup.soon);
    },
  );

  test('Pinned draft state persists through add and edit', () async {
    final storage = MemoryTodoStorage(todos: []);
    final controller = TodoController(
      storage: storage,
      clock: () => DateTime(2026, 9, 4, 10),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    const space = TodoSpace.defaultId;

    final id = controller.addTodo(
      space,
      const TodoDraft(
        title: 'Pinned task',
        group: TodoGroup.today,
        isPinned: true,
      ),
    );
    await controller.flush();
    expect(controller.spaceById(space).todos.single.isPinned, isTrue);

    controller.updateTodo(
      space,
      id,
      const TodoDraft(
        title: 'Edited task',
        group: TodoGroup.today,
        isPinned: false,
      ),
    );
    await controller.flush();
    expect(controller.spaceById(space).todos.single.isPinned, isFalse);
  });

  test('Moves within and between groups survive a restart', () async {
    final storage = MemoryTodoStorage(
      snapshot: snapshot([
        todo('a', TodoGroup.today, 0),
        todo('b', TodoGroup.today, 1),
        todo('c', TodoGroup.today, 2),
        todo('d', TodoGroup.soon, 0),
      ]),
    );
    final controller = TodoController(
      storage: storage,
      clock: () => DateTime(2026, 9, 4, 10),
    );
    await controller.initialize();

    controller.moveTodo(
      TodoSpace.defaultId,
      'c',
      group: TodoGroup.today,
      index: 0,
    );
    controller.moveTodo(
      TodoSpace.defaultId,
      'a',
      group: TodoGroup.soon,
      index: 1,
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      controller
          .activeTodos(TodoSpace.defaultId, TodoGroup.today)
          .map((item) => item.id),
      ['c', 'b'],
    );
    expect(
      controller
          .activeTodos(TodoSpace.defaultId, TodoGroup.soon)
          .map((item) => item.id),
      ['d', 'a'],
    );

    final restarted = TodoController(
      storage: storage,
      clock: () => DateTime(2026, 9, 4, 11),
    );
    await restarted.initialize();
    expect(
      restarted
          .activeTodos(TodoSpace.defaultId, TodoGroup.today)
          .map((item) => item.id),
      ['c', 'b'],
    );
    expect(
      restarted
          .activeTodos(TodoSpace.defaultId, TodoGroup.soon)
          .map((item) => item.id),
      ['d', 'a'],
    );
  });
}
