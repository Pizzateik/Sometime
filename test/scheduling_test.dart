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

  testWidgets('Pin option is absent on iOS', (tester) async {
    await startApp(tester, MemoryTodoStorage(), reduceMotion: true);
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    expect(control('An Benachrichtigungen anpinnen'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('Scheduled tasks sort first and moves keep their details', () async {
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
      [dated, timed, first, second],
    );
    controller.moveTodo(space, second, group: TodoGroup.today, index: 2);
    expect(
      controller.activeTodos(space, TodoGroup.today).map((todo) => todo.id),
      [dated, timed, second, first],
    );
    controller.moveTodo(space, dated, group: TodoGroup.soon, index: 0);
    expect(
      controller.activeTodos(space, TodoGroup.soon).single.details.description,
      'Details',
    );
    await controller.retrySave();
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
