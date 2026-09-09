import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/widgets/completed_section.dart';
import 'package:todo_app/widgets/dashed_divider.dart';

import 'support/memory_todo_storage.dart';
import 'support/sample_todos.dart';
import 'todo_app_test.dart' show startApp, control;

void main() {
  testWidgets('The divider spans the list and a deliberate pull closes it', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);
    await startApp(
      tester,
      MemoryTodoStorage(
        todos: [
          ...sampleTodos,
          Todo(
            id: 'done',
            title: 'Done',
            group: TodoGroup.today,
            createdAt: now,
            completedAt: now,
          ),
        ],
      ),
    );
    final divider = find.descendant(
      of: find.byType(CompletedSection),
      matching: find.byType(DashedDivider),
    );
    expect(divider, findsNothing);
    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    expect(tester.getSize(divider).width, closeTo(334, 1));
    expect(
      tester.getTopLeft(divider).dy,
      lessThan(tester.getTopLeft(find.text('Done')).dy),
    );
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    expect(scroll.position.maxScrollExtent, 0);

    var gesture = await tester.startGesture(
      tester.getCenter(find.text('Heute')),
    );
    await gesture.moveBy(const Offset(0, 15));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<CompletedSection>(find.byType(CompletedSection)).expanded,
      isTrue,
    );

    gesture = await tester.startGesture(tester.getCenter(find.text('Heute')));
    for (var i = 0; i < 16; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.offset, greaterThan(-240));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<CompletedSection>(find.byType(CompletedSection)).expanded,
      isFalse,
    );
    expect(divider, findsNothing);
    expect(scroll.offset, closeTo(0, 1));

    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    await tester.tap(control('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(control('todo öffnen'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CompletedSection>(find.byType(CompletedSection)).expanded,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
