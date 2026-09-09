import 'package:todo_app/app/app_strings.dart';
import 'package:todo_app/app/sometime_icons.dart';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:todo_app/models/theme_preference.dart';

import 'package:todo_app/models/todo.dart';

import 'package:todo_app/models/todo_space.dart';

import 'package:todo_app/models/todo_storage.dart';

import 'package:todo_app/state/todo_controller.dart';

import 'package:todo_app/widgets/add_todo_button.dart';

import 'support/memory_todo_storage.dart';
import 'support/sample_todos.dart';

import 'todo_app_test.dart' show startApp, control;

void main() {
  testWidgets('Pending completion cancels and resumes from saved time', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 4, 10);

    final storage = MemoryTodoStorage();

    var controller = TodoController(storage: storage, clock: () => now);

    await controller.initialize();

    const space = TodoSpace.defaultId;

    controller.toggleTodo(space, 'demo-1');

    expect(
      controller.activeTodos(space, TodoGroup.today).first.completedPending,

      isTrue,
    );

    expect(controller.completedTodos(space), isEmpty);

    await tester.pump(const Duration(seconds: 1));

    controller.toggleTodo(space, 'demo-1');

    await tester.pump(const Duration(seconds: 4));

    expect(controller.completedTodos(space), isEmpty);

    expect(controller.spaceById(space).todos.first.isComplete, isFalse);

    controller.toggleTodo(space, 'demo-1');

    await controller.retrySave();

    controller.dispose();

    storage.snapshot = LocalTodoStorage.decode(
      LocalTodoStorage.encode(storage.snapshot!),
    );

    now = now.add(const Duration(seconds: 1));

    controller = TodoController(storage: storage, clock: () => now);

    await controller.initialize();

    expect(controller.completedTodos(space), isEmpty);

    await tester.pump(const Duration(seconds: 1));

    expect(controller.isCompletionExiting('demo-1'), isTrue);

    await tester.pump(TodoController.completionExit);

    expect(controller.completedTodos(space).single.id, 'demo-1');

    controller.toggleTodo(space, 'demo-1');

    controller.toggleTodo(space, 'demo-1');

    await controller.retrySave();

    controller.dispose();

    now = now.add(const Duration(seconds: 5));

    controller = TodoController(storage: storage, clock: () => now);

    await controller.initialize();

    expect(controller.completedTodos(space).single.completedPending, isFalse);

    controller.dispose();
  });

  testWidgets('One long press can drag and closes edit mode after a move', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();

    await startApp(tester, storage);

    final gesture = await tester.startGesture(
      tester.getCenter(control('Mathe lernen')),
    );

    await tester.pump(const Duration(milliseconds: 379));

    expect(find.byKey(const ValueKey('move-handle-demo-2')), findsNothing);

    await tester.pump(const Duration(milliseconds: 2));

    expect(find.byKey(const ValueKey('move-handle-demo-2')), findsOneWidget);

    await gesture.moveBy(const Offset(0, 28));

    await tester.pump();

    expect(find.text('Mathe lernen'), findsOneWidget);

    await gesture.moveTo(
      tester.getCenter(find.text('Irgendwann')) + const Offset(0, 45),
    );

    await tester.pump();

    await gesture.up();

    await tester.pumpAndSettle();

    expect(
      storage.todos!.firstWhere((todo) => todo.id == 'demo-2').group,

      TodoGroup.someday,
    );

    expect(find.byKey(const ValueKey('move-handle-demo-2')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('A long press without a move keeps edit mode open', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage());

    final gesture = await tester.startGesture(
      tester.getCenter(control('Mathe lernen')),
    );

    await tester.pump(const Duration(milliseconds: 381));

    await gesture.up();

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move-handle-demo-2')), findsOneWidget);
  });

  testWidgets('Settings subpages open and appearance choices persist', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();

    await startApp(tester, storage);

    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),

      const Offset(-390, 0),
    );

    await tester.pumpAndSettle();

    expect(control('Darstellung'), findsOneWidget);

    expect(control('Sprache'), findsOneWidget);

    expect(control('Mitteilungen'), findsOneWidget);

    expect(control('Daten und Datenschutz'), findsOneWidget);

    await tester.tap(control('Darstellung'));

    await tester.pumpAndSettle();

    await tester.tap(control('Klar'));

    await tester.pumpAndSettle();

    await tester.tap(control('Dunkel'));

    await tester.pumpAndSettle();

    expect(storage.appearancePreference?.style, AppearanceStyle.normal);

    expect(storage.appearancePreference?.mode, AppearanceMode.dark);

    await tester.tap(find.byType(BackButton));

    await tester.pumpAndSettle();

    await tester.tap(control('Sprache'));

    await tester.pumpAndSettle();

    expect(find.text('Deutsch'), findsOneWidget);

    await tester.tap(find.byType(BackButton));

    await tester.pumpAndSettle();

    await tester.ensureVisible(control('Daten und Datenschutz'));
    await tester.pumpAndSettle();
    await tester.tap(control('Daten und Datenschutz'));

    await tester.pumpAndSettle();

    expect(
      find.text(const AppStrings(Locale('de')).onDevice.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('Space rename keeps IDs and four spaces block creation', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);

    final storage = MemoryTodoStorage();

    final controller = TodoController(storage: storage, clock: () => now);

    await controller.initialize();

    controller.addSpace('Work');

    controller.addSpace('Home');

    controller.addSpace('Uni');

    expect(() => controller.addSpace('Fifth'), throwsStateError);

    await controller.retrySave();

    controller.dispose();

    await startApp(tester, storage, size: const Size(390, 844));

    await tester.longPress(find.text('Work'));

    await tester.pumpAndSettle();

    expect(find.byIcon(SometimeIcons.prohibit), findsOneWidget);

    expect(find.byKey(const ValueKey('add-space')), findsNothing);

    expect(
      tester.getCenter(find.byIcon(SometimeIcons.prohibit)).dx,

      greaterThan(tester.getCenter(find.text('Uni')).dx),
    );

    await tester.tap(find.text('Sometime'));

    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,

      'Sometime',
    );

    await tester.enterText(find.byType(TextField), 'Main');

    await tester.tap(find.text('Speichern'));

    await tester.pumpAndSettle();

    final restored = LocalTodoStorage.decode(
      LocalTodoStorage.encode(storage.snapshot!),
    );

    expect(restored.spaces.first.id, TodoSpace.defaultId);

    expect(restored.spaces.first.name, 'Main');

    expect(restored.spaces.first.todos.length, 4);

    expect(restored.spaces.length, 4);

    expect(find.byIcon(SometimeIcons.prohibit), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('The add button stays fixed and hides on settings', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);

    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: TodoSpace.defaultId,
            name: 'Sometime',
            todos: [for (final todo in sampleTodos) todo.withCreatedAt(now)],
          ),

          const TodoSpace(id: 'work', name: 'Work', todos: []),
        ],

        archive: const [],

        lastKnownLocalDate: now,
      ),
    );

    await startApp(tester, storage);

    final button = find.byType(AddTodoButton);

    final element = tester.element(button);

    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;

    final right = tester.getBottomRight(button);

    pager.jumpTo(390 * 0.5);

    await tester.pump();

    expect(tester.getBottomRight(button), right);

    pager.jumpToPage(1);

    await tester.pumpAndSettle();

    await tester.tap(control('Neue Aufgabe'));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),

      'Work task',
    );

    await tester.pump();

    await tester.tap(control('Aufgabe hinzufügen'));

    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces.last.todos.single.title, 'Work task');

    pager.jumpTo(390 * 1.5);

    await tester.pump();

    expect(tester.getBottomRight(button), right);

    pager.jumpToPage(1);

    await tester.pumpAndSettle();

    await tester.tap(control('Einstellungen öffnen'));

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpAndSettle();

    expect(identical(tester.element(button), element), isTrue);

    expect(control('Pro kaufen'), findsNothing);

    expect(find.byType(AlertDialog), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
