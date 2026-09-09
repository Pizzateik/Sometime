import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/pressable.dart';

import '../test/support/sample_todos.dart';

Finder control(String label) => find.byWidgetPredicate(
  (widget) => widget is Pressable && widget.label == label,
);

TodoSnapshot sampleSnapshot(DateTime time) => TodoSnapshot(
  spaces: [
    TodoSpace(
      id: TodoSpace.defaultId,
      name: 'Sometime',
      todos: [for (final todo in sampleTodos) todo.withCreatedAt(time)],
    ),
  ],
  archive: const [],
  lastKnownLocalDate: localCalendarDate(time),
);

Future<void> waitForWidget(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> waitForKeyboard(WidgetTester tester) async {
  var previousInset = -1.0;
  var stableFrames = 0;
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final inset = MediaQuery.viewInsetsOf(
      tester.element(find.byType(AddTodoSheet)),
    ).bottom;
    stableFrames = inset > 0 && inset == previousInset ? stableFrames + 1 : 0;
    previousInset = inset;
    if (stableFrames == 3) break;
  }
  expect(previousInset, greaterThan(0));
  await tester.pumpAndSettle();
}
