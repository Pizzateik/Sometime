import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/state/todo_controller.dart';
import 'package:todo_app/widgets/add_todo_button.dart';
import 'package:todo_app/widgets/dissolving_todo.dart';

import 'support/memory_todo_storage.dart';
import 'support/sample_todos.dart';
import 'todo_app_test.dart' show startApp, control;

void main() {
  testWidgets(
    'Only the last deletion has an undo window and names stop at ten characters',
    (tester) async {
      final storage = MemoryTodoStorage();
      final controller = TodoController(
        storage: storage,
        clock: () => DateTime(2026, 9, 4, 10),
      );
      await controller.initialize();
      final id = controller.addSpace('12345678901');
      expect(controller.spaceById(id).name, '1234567890');
      controller.renameSpace(id, 'abcdefghijk');
      expect(controller.spaceById(id).name, 'abcdefghij');
      const space = TodoSpace.defaultId;
      controller.deleteTodo(space, 'demo-1');
      controller.deleteTodo(space, 'demo-2');
      controller.undoDeletion();
      expect(
        controller.spaceById(space).todos.any((todo) => todo.id == 'demo-1'),
        isFalse,
      );
      expect(
        controller.spaceById(space).todos.any((todo) => todo.id == 'demo-2'),
        isTrue,
      );
      controller.deleteTodo(space, 'demo-2');
      await tester.pump(const Duration(seconds: 5));
      expect(controller.canUndoDeletion, isFalse);
      controller.undoDeletion();
      expect(
        controller.spaceById(space).todos.any((todo) => todo.id == 'demo-2'),
        isFalse,
      );
      await controller.retrySave();
      expect(
        storage.snapshot!.spaces.first.todos.any((todo) => todo.id == 'demo-2'),
        isFalse,
      );
      controller.dispose();
    },
  );

  testWidgets('The completed footer pins below content and opens upward', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);
    final done = Todo(
      id: 'done',
      title: 'Done task',
      group: TodoGroup.today,
      createdAt: now,
      completedAt: now,
    );
    await startApp(tester, MemoryTodoStorage(todos: [...sampleTodos, done]));
    final header = control('Erledigt');
    final buttonY = tester.getCenter(find.byType(AddTodoButton)).dy;
    expect(tester.getCenter(header).dy, closeTo(buttonY, 1));
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(tester.getCenter(header).dy, closeTo(buttonY, 1));
    expect(
      tester.getBottomLeft(find.text('Done task')).dy,
      lessThan(tester.getTopLeft(header).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await startApp(
      tester,
      MemoryTodoStorage(
        todos: [
          for (var i = 0; i < 22; i++)
            Todo(
              id: 'long-$i',
              title: 'Task $i',
              group: TodoGroup.someday,
              createdAt: now,
              sortOrder: i,
            ),
          for (var i = 0; i < 18; i++)
            Todo(
              id: 'done-$i',
              title: 'Done $i',
              group: TodoGroup.today,
              createdAt: now,
              completedAt: now,
            ),
        ],
      ),
    );
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final lastTaskBottom = tester.getBottomLeft(control('Task 21')).dy;
    expect(header, findsNothing);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getCenter(header).dy, closeTo(buttonY, 1));
    scroll.jumpTo(scroll.offset + 80);
    await tester.pump();
    expect(tester.getCenter(header).dy, closeTo(buttonY, 1));
    scroll.jumpTo(lastTaskBottom - (buttonY - 53) + 2);
    await tester.pump();
    await tester.tap(header);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getCenter(header).dy, closeTo(buttonY, 1));
    await tester.pumpAndSettle();
    expect(tester.getCenter(header).dy, closeTo(buttonY, 1));
    expect(tester.takeException(), isNull);
    await tester.tap(header);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pump();
    expect(header.hitTestable(), findsNothing);
  });

  testWidgets(
    'A generous trash target deletes and undo restores the position',
    (tester) async {
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);
      final gesture = await tester.startGesture(
        tester.getCenter(control('Mathe lernen')),
      );
      await tester.pump(const Duration(milliseconds: 390));
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump();
      final button = find.byType(AddTodoButton);
      expect(tester.widget<AddTodoButton>(button).dragging, isTrue);
      final bounds = tester.getRect(button);
      await gesture.moveTo(Offset(bounds.left - 20, bounds.center.dy));
      await tester.pump();
      expect(tester.widget<AddTodoButton>(button).deleteHovered, isTrue);
      await gesture.up();
      await tester.pump();
      expect(storage.todos!.any((todo) => todo.id == 'demo-2'), isFalse);
      expect(find.byType(DissolvingTodo), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Eintrag gelöscht'), findsOneWidget);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      final restored = storage.todos!.firstWhere((todo) => todo.id == 'demo-2');
      expect(restored.group, TodoGroup.today);
      expect(restored.sortOrder, 1);
      expect(find.text('Eintrag gelöscht'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expect(storage.todos!.any((todo) => todo.id == 'demo-2'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Completion sends one haptic and uncheck cancels the pending move',
    (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);
      haptics.clear();
      await tester.tap(control('Mathe lernen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(storage.todos![1].completedPending, isTrue);
      await tester.tap(control('Mathe lernen'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(storage.todos![1].isComplete, isFalse);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      expect(control('Erledigt'), findsNothing);
    },
  );
}
