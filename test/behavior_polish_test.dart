import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/screens/todo_space_screen.dart';

import 'support/memory_todo_storage.dart';
import 'todo_app_test.dart' as app_test;

void main() {
  testWidgets('category progress uses a temporary baseline', (tester) async {
    final storage = MemoryTodoStorage(
      todos: [
        for (var index = 0; index < 5; index++)
          Todo(
            id: 'today-$index',
            title: 'Today task $index',
            group: TodoGroup.today,
            createdAt: DateTime(2026, 9, 4, 10),
            sortOrder: index,
          ),
      ],
    );
    await app_test.startApp(tester, storage);

    await tester.tap(app_test.control('Today task 0'));
    await tester.pump();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.tap(app_test.control('Today task 1'));
    await tester.pump();
    expect(find.text('2 / 5'), findsOneWidget);

    await tester.tap(app_test.control('Today task 1'));
    await tester.pump();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1 / 5'), findsNothing);
  });

  testWidgets('the final Space moment waits for committed completion', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'last-task',
          title: 'Last task',
          group: TodoGroup.today,
          createdAt: DateTime(2026, 9, 4, 10),
        ),
      ],
    );
    await app_test.startApp(tester, storage);

    await tester.tap(app_test.control('Last task'));
    await tester.pump();
    expect(find.text('Alles erledigt :D'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Alles erledigt :D'), findsNothing);

    await tester.pump(const Duration(milliseconds: 280));
    expect(find.text('Alles erledigt :D'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('final-completion-wave-1')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('final-completion-wave-1')),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(find.text('Alles erledigt :D'), findsOneWidget);
  });

  testWidgets('unchecking the pending final task prevents the Space moment', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'pending-last-task',
          title: 'Pending last task',
          group: TodoGroup.today,
          createdAt: DateTime(2026, 9, 4, 10),
        ),
      ],
    );
    await app_test.startApp(tester, storage);

    await tester.tap(app_test.control('Pending last task'));
    await tester.pump();
    await tester.tap(app_test.control('Pending last task'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(storage.todos!.single.isComplete, isFalse);
    expect(find.text('Alles erledigt :D'), findsNothing);
  });

  testWidgets('a routine occurrence prevents the final Space moment', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'routine-task',
          title: 'Routine task',
          group: TodoGroup.today,
          createdAt: DateTime(2026, 9, 4, 10),
          details: TaskDetails(
            date: DateTime(2026, 9, 4),
            recurrence: const RecurrenceRule(
              type: RecurrenceType.weekly,
              weekdays: [1],
            ),
          ),
          routineId: 'routine-task',
        ),
      ],
    );
    await app_test.startApp(tester, storage);

    await tester.tap(app_test.control('Routine task'));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(storage.todos, hasLength(2));
    expect(find.byKey(const ValueKey('final-completion-wave-1')), findsNothing);
  });

  testWidgets('reduced motion uses a full-screen wash', (tester) async {
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'reduced-task',
          title: 'Reduced task',
          group: TodoGroup.today,
          createdAt: DateTime(2026, 9, 4, 10),
        ),
      ],
    );
    await app_test.startApp(tester, storage, reduceMotion: true);

    await tester.tap(app_test.control('Reduced task'));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 60));

    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('final-completion-wave-1')),
    );
    expect((paint.painter! as FinalCompletionWavePainter).reduceMotion, isTrue);
  });

  testWidgets('opening an empty Space does not replay the final wave', (
    tester,
  ) async {
    await app_test.startApp(tester, MemoryTodoStorage());

    expect(find.byKey(const ValueKey('final-completion-wave-1')), findsNothing);
  });
}
