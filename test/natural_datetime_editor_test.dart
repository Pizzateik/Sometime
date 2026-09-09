import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/widgets/pressable.dart';
import 'package:todo_app/widgets/task_planning_fields.dart';

import 'support/memory_todo_storage.dart';
import 'todo_app_test.dart' show control, startApp;

void main() {
  testWidgets('title parsing keeps task text unchanged on submit', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage, clock: () => DateTime(2026, 9, 4, 10));
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Prüfung 5. Sep. um 18:30 Uhr',
    );
    await tester.enterText(
      find.byKey(const ValueKey('todo-description-field')),
      'Notizen',
    );
    await tester.pump();

    var value = tester
        .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
        .value;
    expect(value.date, DateTime(2026, 9, 5));
    expect(value.minutes, 18 * 60 + 30);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title-field')))
          .controller!
          .text,
      'Prüfung 5. Sep. um 18:30 Uhr',
    );
    await tester.tap(control('Aufgabe hinzufügen'));
    await tester.pumpAndSettle();
    final saved = storage.todos!.singleWhere(
      (todo) => todo.title == 'Prüfung 5. Sep. um 18:30 Uhr',
    );
    expect(saved.details.description, 'Notizen');
  });

  testWidgets('description fills missing date and time fields', (tester) async {
    await startApp(
      tester,
      MemoryTodoStorage(),
      clock: () => DateTime(2026, 9, 4, 10),
    );
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Prüfung',
    );
    await tester.enterText(
      find.byKey(const ValueKey('todo-description-field')),
      'Morgen um 08:15 Uhr',
    );
    await tester.pump();
    final value = tester
        .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
        .value;
    expect(value.date, DateTime(2026, 9, 5));
    expect(value.minutes, 8 * 60 + 15);
  });

  testWidgets('manual selection locks a field and clear restores eligibility', (
    tester,
  ) async {
    await startApp(
      tester,
      MemoryTodoStorage(),
      clock: () => DateTime(2026, 9, 4, 10),
    );
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Prüfung 5. Sep. um 18:30 Uhr',
    );
    await tester.pump();

    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is Pressable && widget.label.contains('Sep'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Prüfung 6. Sep. um 19:00 Uhr',
    );
    await tester.pump();
    var value = tester
        .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
        .value;
    expect(value.date, DateTime(2026, 9, 5));
    expect(value.minutes, 19 * 60);

    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is Pressable && widget.label.contains(':'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Prüfung 7. Sep. um 20:00 Uhr',
    );
    await tester.pump();
    value = tester
        .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
        .value;
    expect(value.date, DateTime(2026, 9, 5));
    expect(value.minutes, 19 * 60);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Pressable &&
            widget.label.contains('Löschen') &&
            widget.label.contains('Sep'),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Prüfung 7. Sep.',
    );
    await tester.pump();
    value = tester
        .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
        .value;
    expect(value.date, DateTime(2026, 9, 7));
    expect(value.minutes, 19 * 60);
  });

  testWidgets('saved date and time stay authoritative while editing', (
    tester,
  ) async {
    const recurrence = RecurrenceRule(
      type: RecurrenceType.weekly,
      weekdays: [1, 3],
    );
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'saved',
          title: 'Gespeichert',
          group: TodoGroup.today,
          createdAt: DateTime(2026, 9, 4, 10),
          details: TaskDetails(
            date: DateTime(2026, 9, 5),
            minutes: 11 * 60,
            recurrence: recurrence,
            reminder: ReminderRule.atTime,
          ),
        ),
      ],
    );
    await startApp(tester, storage, clock: () => DateTime(2026, 9, 4, 10));
    await tester.longPress(control('Gespeichert'));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.byKey(const ValueKey('edit-task-saved')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Gespeichert 6. Sep. um 20 Uhr',
    );
    await tester.pump();
    final value = tester
        .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
        .value;
    expect(value.date, DateTime(2026, 9, 5));
    expect(value.minutes, 11 * 60);
    await tester.tap(control('Änderungen speichern'));
    await tester.pumpAndSettle();

    final saved = storage.todos!.single;
    expect(saved.title, 'Gespeichert 6. Sep. um 20 Uhr');
    expect(saved.details.date, DateTime(2026, 9, 5));
    expect(saved.details.minutes, 11 * 60);
    expect(saved.details.recurrence, recurrence);
    expect(saved.details.reminder, ReminderRule.atTime);
  });
}
