import 'package:todo_app/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';
import 'package:todo_app/state/todo_controller.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/task_planning_fields.dart';

import 'support/memory_todo_storage.dart';
import 'todo_app_test.dart' show startApp, control;

void main() {
  testWidgets('A landscape keyboard keeps the creation panel usable', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage(), size: const Size(844, 390));
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Landscape task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.tap(control('Aufgabe hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.byType(AddTodoSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Routine rules handle multiple weekdays and short months', () {
    const weekly = RecurrenceRule(
      type: RecurrenceType.weekly,
      weekdays: [1, 3, 5],
    );
    expect(weekly.nextAfter(DateTime(2026, 9, 9)), DateTime(2026, 9, 11));
    expect(weekly.nextAfter(DateTime(2026, 9, 11)), DateTime(2026, 9, 14));
    const monthly = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31);
    expect(monthly.nextAfter(DateTime(2027, 1, 31)), DateTime(2027, 2, 28));
    expect(monthly.nextAfter(DateTime(2027, 2, 28)), DateTime(2027, 3, 31));
    const yearly = RecurrenceRule(
      type: RecurrenceType.yearly,
      yearMonth: 2,
      yearDay: 29,
    );
    expect(yearly.nextAfter(DateTime(2027, 2, 28)), DateTime(2028, 2, 29));
    expect(yearly.nextAfter(DateTime(2028, 2, 29)), DateTime(2029, 2, 28));
  });

  testWidgets('Pin option is available on Android and updates draft state', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(todos: []);
    await startApp(tester, storage, reduceMotion: true);
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    expect(control('An Benachrichtigungen anpinnen'), findsOneWidget);
    expect(
      tester
          .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
          .isPinned,
      isFalse,
    );
    await tester.tap(control('An Benachrichtigungen anpinnen'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
          .isPinned,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Pinned task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(control('Aufgabe hinzufügen'));
    await tester.pumpAndSettle();
    expect(storage.todos!.single.isPinned, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Edit panel restores an Android task pin', (tester) async {
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'pinned',
          title: 'Pinned task',
          group: TodoGroup.today,
          createdAt: DateTime(2026, 9, 4, 10),
          isPinned: true,
        ),
      ],
    );
    await startApp(tester, storage, reduceMotion: true);
    await tester.longPress(control('Pinned task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-task-pinned')));
    await tester.pumpAndSettle();
    expect(control('An Benachrichtigungen anpinnen'), findsOneWidget);
    expect(
      tester
          .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
          .isPinned,
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('A task moves after a 1100ms Space dwell and drop', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Move me',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Target', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final indicator = find.byKey(const ValueKey('space-dwell-indicator-1'));
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Move me')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 1);
    expect(
      find.byKey(const ValueKey('space-switch-border-task')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1000));
    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    expect(storage.snapshot!.spaces.last.todos, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    final pager = tester
        .widget<PageView>(find.byKey(const ValueKey('main-space-pager')))
        .controller!;
    expect(pager.page, closeTo(1, 0.01));
    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    expect(storage.snapshot!.spaces.last.todos, isEmpty);
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 0);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('space-switch-border-task')),
      findsNothing,
    );
    await gesture.moveTo(
      tester.getCenter(find.text('Heute')) + const Offset(0, 48),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(storage.snapshot!.spaces.first.todos, isEmpty);
    expect(storage.snapshot!.spaces.last.todos.single.title, 'Move me');
  });

  testWidgets('Leaving a Space before 1100ms cancels its dwell', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Keep me',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Target', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Keep me')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    final indicator = find.byKey(const ValueKey('space-dwell-indicator-1'));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 1);
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveTo(const Offset(100, 200));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 0);
    expect(
      find.byKey(const ValueKey('space-switch-border-task')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    expect(storage.snapshot!.spaces.last.todos, isEmpty);
  });

  testWidgets('Canceling after a preview switch keeps the source task', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Cancel me',
                group: TodoGroup.soon,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Target', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Cancel me')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    await tester.pump(const Duration(milliseconds: 1101));
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    expect(storage.snapshot!.spaces.last.todos, isEmpty);
  });

  testWidgets('Changing the Space hover target starts a new dwell', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Switch me',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'first', name: 'First', todos: []),
          const TodoSpace(id: 'second', name: 'Second', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Switch me')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('First')));
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveTo(tester.getCenter(find.text('Second')));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(
      tester.getCenter(find.text('Heute')) + const Offset(0, 48),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces[0].todos, isEmpty);
    expect(storage.snapshot!.spaces[1].todos, isEmpty);
    expect(storage.snapshot!.spaces[2].todos.single.id, 'task');
  });

  testWidgets('A second pointer cannot switch Spaces during a task drag', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'One pointer',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Target', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final drag = await tester.startGesture(
      tester.getCenter(find.text('One pointer')),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 381));
    await drag.moveBy(const Offset(0, 24));
    await tester.pump();
    final tap = await tester.startGesture(
      tester.getCenter(find.text('Target')),
      pointer: 2,
    );
    await tap.up();
    await tester.pump(const Duration(milliseconds: 300));

    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pager.page, closeTo(0, 0.01));
    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    expect(storage.snapshot!.spaces.last.todos, isEmpty);
    await drag.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('A release on the Space header does not move the task', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Do not drop',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Target', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Do not drop')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    await tester.pump(const Duration(milliseconds: 1101));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces.first.todos.single.id, 'task');
    expect(storage.snapshot!.spaces.last.todos, isEmpty);
  });

  testWidgets('A task can change category after a Space preview', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Change category',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Target', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Change category')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    await tester.pump(const Duration(milliseconds: 1101));
    await gesture.moveTo(
      tester.getCenter(find.text('Demnächst')) + const Offset(0, 48),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces.first.todos, isEmpty);
    final moved = storage.snapshot!.spaces.last.todos.single;
    expect(moved.id, 'task');
    expect(moved.group, TodoGroup.soon);
  });

  testWidgets('One drag can preview two Spaces before the final drop', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'task',
                title: 'Keep holding',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4, 10),
              ),
            ],
          ),
          const TodoSpace(id: 'first', name: 'First', todos: []),
          const TodoSpace(id: 'second', name: 'Second', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Keep holding')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('First')));
    await tester.pump(const Duration(milliseconds: 1101));
    await gesture.moveTo(tester.getCenter(find.text('Second')));
    await tester.pump(const Duration(milliseconds: 1101));
    await gesture.moveTo(
      tester.getCenter(find.text('Heute')) + const Offset(0, 48),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces[0].todos, isEmpty);
    expect(storage.snapshot!.spaces[1].todos, isEmpty);
    expect(storage.snapshot!.spaces[2].todos.single.id, 'task');
  });

  testWidgets('A destination list accepts an external insertion index', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'moving',
                title: 'Insert me',
                group: TodoGroup.today,
                createdAt: now,
              ),
            ],
          ),
          TodoSpace(
            id: 'target',
            name: 'Target',
            todos: [
              Todo(
                id: 'first',
                title: 'Target first',
                group: TodoGroup.today,
                createdAt: now,
                sortOrder: 0,
              ),
              Todo(
                id: 'second',
                title: 'Target second',
                group: TodoGroup.today,
                createdAt: now,
                sortOrder: 1,
              ),
            ],
          ),
        ],
        archive: const [],
        lastKnownLocalDate: now,
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Insert me')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    await tester.pump(const Duration(milliseconds: 1101));
    final first = tester.getCenter(find.text('Target first'));
    final second = tester.getCenter(find.text('Target second'));
    await gesture.moveTo(Offset(first.dx, (first.dy + second.dy) / 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final ordered =
        storage.snapshot!.spaces.last.todos
            .where((todo) => todo.group == TodoGroup.today)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    expect(ordered.map((todo) => todo.id), ['first', 'moving', 'second']);
  });

  testWidgets('A destination page auto-scrolls an external task drag', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Source',
            todos: [
              Todo(
                id: 'moving',
                title: 'Scroll me',
                group: TodoGroup.today,
                createdAt: now,
              ),
            ],
          ),
          TodoSpace(
            id: 'target',
            name: 'Target',
            todos: [
              for (var index = 0; index < 24; index++)
                Todo(
                  id: 'target-$index',
                  title: 'Target task $index',
                  group: TodoGroup.today,
                  createdAt: now,
                  sortOrder: index,
                ),
            ],
          ),
        ],
        archive: const [],
        lastKnownLocalDate: now,
      ),
    );
    await startApp(tester, storage, reduceMotion: true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Scroll me')),
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Target')));
    await tester.pump(const Duration(milliseconds: 1101));
    await gesture.moveTo(const Offset(150, 800));
    await tester.pump();
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = scroll.offset;
    for (var index = 0; index < 30; index++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.offset, greaterThan(before + 50));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(storage.snapshot!.spaces.first.todos.single.id, 'moving');
    expect(
      storage.snapshot!.spaces.last.todos.any((todo) => todo.id == 'moving'),
      isFalse,
    );
  });

  testWidgets('Pin option is absent on iOS', (tester) async {
    await startApp(tester, MemoryTodoStorage(), reduceMotion: true);
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    expect(control('An Benachrichtigungen anpinnen'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('Manual order stays authoritative for scheduled tasks', () async {
    final storage = MemoryTodoStorage(todos: []);
    final controller = TodoController(
      storage: storage,
      clock: () => DateTime(2026, 9, 9),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    const space = TodoSpace.defaultId;
    String add(String name, TaskDetails details) => controller.addTodo(
      space,
      TodoDraft(title: name, group: TodoGroup.today, details: details),
    );
    final first = add('Manual one', const TaskDetails());
    final second = add('Manual two', const TaskDetails());
    final timed = add('Time only', const TaskDetails(minutes: 1140));
    final dated = add(
      'Date',
      TaskDetails(description: 'Details', date: DateTime(2026, 9, 12)),
    );
    expect(
      controller.activeTodos(space, TodoGroup.today).map((todo) => todo.id),
      [first, second, timed, dated],
    );
    controller.moveTodo(space, dated, group: TodoGroup.today, index: 0);
    expect(
      controller.activeTodos(space, TodoGroup.today).map((todo) => todo.id),
      [dated, first, second, timed],
    );
    controller.moveTodo(space, dated, group: TodoGroup.soon, index: 0);
    expect(
      controller.activeTodos(space, TodoGroup.soon).single.details.description,
      'Details',
    );
    await controller.retrySave();
    final restarted = TodoController(
      storage: storage,
      clock: () => DateTime(2026, 9, 9),
    );
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(
      restarted.activeTodos(space, TodoGroup.today).map((todo) => todo.id),
      [first, second, timed],
    );
    expect(
      restarted.activeTodos(space, TodoGroup.soon).map((todo) => todo.id),
      [dated],
    );
    final saved = LocalTodoStorage.decode(
      LocalTodoStorage.encode(storage.snapshot!),
    );
    expect(
      saved.spaces.single.todos
          .firstWhere((todo) => todo.id == dated)
          .details
          .date,
      DateTime(2026, 9, 12),
    );
  });

  testWidgets(
    'A routine has one next occurrence after completion and restart',
    (tester) async {
      var now = DateTime(2026, 9, 9, 12);
      final storage = MemoryTodoStorage(todos: []);
      var controller = TodoController(storage: storage, clock: () => now);
      await controller.initialize();
      const space = TodoSpace.defaultId;
      final id = controller.addTodo(
        space,
        const TodoDraft(
          title: 'Workout',
          group: TodoGroup.today,
          details: TaskDetails(
            description: 'Warm up',
            minutes: 1080,
            recurrence: RecurrenceRule(
              type: RecurrenceType.weekly,
              weekdays: [1, 3, 5],
            ),
          ),
        ),
      );
      controller.toggleTodo(space, id);
      await tester.pump(const Duration(seconds: 3));
      expect(controller.completedTodos(space).single.id, id);
      expect(controller.activeTodos(space, TodoGroup.today), isEmpty);
      expect(controller.spaceById(space).todos, hasLength(2));
      await controller.handleResume();
      expect(controller.spaceById(space).todos, hasLength(2));
      controller.toggleTodo(space, id);
      expect(controller.spaceById(space).todos, hasLength(1));
      controller.toggleTodo(space, id);
      await tester.pump(const Duration(seconds: 3));
      await controller.retrySave();
      controller.dispose();
      storage.snapshot = LocalTodoStorage.decode(
        LocalTodoStorage.encode(storage.snapshot!),
      );
      now = DateTime(2026, 9, 11);
      controller = TodoController(storage: storage, clock: () => now);
      await controller.initialize();
      final next = controller.activeTodos(space, TodoGroup.today).single;
      expect(next.details.date, now);
      expect(next.details.minutes, 1080);
      expect(next.details.recurrence!.weekdays, [1, 3, 5]);
      expect(next.details.description, 'Warm up');
      await controller.handleResume();
      expect(controller.activeTodos(space, TodoGroup.today), hasLength(1));
      now = DateTime(2026, 9, 18);
      await controller.handleResume();
      expect(controller.archive, isEmpty);
      controller.dispose();
    },
  );

  testWidgets(
    'The creation panel keeps the header and saves optional details',
    (tester) async {
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);
      final headerBottom = tester.getBottomLeft(find.text('Sometime')).dy;
      await tester.tap(control('Neue Aufgabe'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('todo-title-field'))).dy,
        greaterThan(headerBottom),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('todo-title-field')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('todo-title-field')),
        'Call insurance',
      );
      await tester.enterText(
        find.byKey(const ValueKey('todo-description-field')),
        'Ask about the contract.',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(AddTodoSheet), findsOneWidget);
      await tester.tap(control('Datum'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(control('Zeit'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Pressable &&
              w.label.startsWith('Löschen ') &&
              w.label.contains(':'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(control('Routine'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(control('Mittwoch, 9. September 2026'));
      await tester.tap(control('Mittwoch, 9. September 2026'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
            .value
            .recurrence,
        isNotNull,
      );
      await tester.tap(control('Aufgabe hinzufügen'));
      await tester.pumpAndSettle();
      final task = storage.todos!.last;
      expect(task.details.description, 'Ask about the contract.');
      expect(task.details.date, isNotNull);
      expect(task.details.minutes, isNull);
      expect(task.details.recurrence, isNotNull);
      expect(find.text('Ask about the contract.'), findsOneWidget);
      expect(find.byType(AddTodoSheet), findsNothing);
      await tester.longPress(control('Call insurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('edit-task-${task.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('todo-description-field')),
            )
            .controller!
            .text,
        'Ask about the contract.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('todo-description-field')),
        '',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Pressable && w.label.startsWith('Löschen '),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(control('Monatlich'));
      await tester.pumpAndSettle();
      expect(control('31'), findsOneWidget);
      await tester.tap(control('Jährlich'));
      await tester.pumpAndSettle();
      expect(control('31'), findsNothing);
      await tester.tap(control('Routine'));
      await tester.pumpAndSettle();
      await tester.tap(control('Änderungen speichern'));
      await tester.pumpAndSettle();
      final edited = storage.todos!.firstWhere((todo) => todo.id == task.id);
      expect(edited.details.description, isEmpty);
      expect(edited.details.date, isNull);
      expect(edited.details.recurrence, isNull);
    },
  );
}
