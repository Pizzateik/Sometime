import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_app/app/todo_app.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';
import 'package:todo_app/widgets/pressable.dart';
import 'package:todo_app/widgets/todo_section.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create, complete, and restore tasks on the device', (
    tester,
  ) async {
    final key = 'todos.integration.${DateTime.now().microsecondsSinceEpoch}';
    final themeKey = '$key.theme';
    final storage = LocalTodoStorage(key: key, themeKey: themeKey);
    await storage.save(sampleSnapshot(DateTime.now()));
    await tester.pumpWidget(TodoApp(storage: storage, themeStorage: storage));
    await waitForWidget(tester, control('Neue Aufgabe'));

    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(-360, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(360, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sometime'), findsOneWidget);

    await tester.tap(control('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(control('Off White'));
    await tester.pumpAndSettle();
    expect(await storage.loadThemePreference(), ThemePreference.offWhite);
    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(360, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    await waitForKeyboard(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title-field')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Milch kaufen',
    );
    await tester.pump();
    await tester.tap(control('Demnächst'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title-field')))
          .controller!
          .text,
      'Milch kaufen',
    );
    expect(
      tester.widget<Pressable>(control('Aufgabe hinzufügen')).onPressed,
      isNotNull,
    );
    await tester.tap(control('Aufgabe hinzufügen'));
    await waitForWidget(tester, find.text('Milch kaufen'));

    await tester.tap(control('Milch kaufen'));
    await tester.pumpAndSettle();
    final saved = await storage.load();
    final savedTodo = saved!.spaces.single.todos.last;
    expect(savedTodo.title, 'Milch kaufen');
    expect(savedTodo.group, TodoGroup.soon);
    expect(savedTodo.originalGroup, TodoGroup.soon);
    expect(savedTodo.isComplete, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    final restartedStorage = LocalTodoStorage(key: key, themeKey: themeKey);
    await tester.pumpWidget(
      TodoApp(storage: restartedStorage, themeStorage: restartedStorage),
    );
    await waitForWidget(tester, control('Erledigt'));
    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    await waitForWidget(tester, find.text('Milch kaufen'));
  });

  testWidgets('One pointer moves a task through a Space dwell', (tester) async {
    final now = DateTime.now();
    final key = 'todos.drag.integration.${now.microsecondsSinceEpoch}';
    final storage = LocalTodoStorage(key: key, themeKey: '$key.theme');
    await storage.save(
      TodoSnapshot(
        spaces: [
          TodoSpace(
            id: 'source',
            name: 'Dev',
            todos: [
              Todo(
                id: 'drag-task',
                title: 'Space drag task',
                group: TodoGroup.today,
                createdAt: now,
              ),
            ],
          ),
          const TodoSpace(id: 'target', name: 'Schule', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: localCalendarDate(now),
      ),
    );
    await storage.saveAppSettings(
      const AppSettings(
        hasCompletedOnboarding: true,
        hasSeenFirstEmptyHomeHint: true,
        hasSeenTaskEditTutorial: true,
        hasSeenSpaceManagementTutorial: true,
      ),
    );
    await tester.pumpWidget(TodoApp(storage: storage, themeStorage: storage));
    await waitForWidget(tester, find.text('Space drag task'));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Space drag task')),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 381));
    await gesture.moveTo(tester.getCenter(find.text('Schule')));
    await tester.pump(const Duration(milliseconds: 1101));
    await tester.pump(const Duration(milliseconds: 400));
    final today = find.byWidgetPredicate(
      (widget) => widget is TodoSection && widget.group == TodoGroup.today,
    );
    await gesture.moveTo(tester.getTopLeft(today) + const Offset(100, 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final saved = await storage.load();
    expect(saved!.spaces.first.todos, isEmpty);
    expect(saved.spaces.last.todos.single.id, 'drag-task');
    expect(saved.spaces.last.todos.single.group, TodoGroup.today);
  });
}
