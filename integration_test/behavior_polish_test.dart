import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_app/app/todo_app.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('category progress and final completion run on Android', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    final now = DateTime.now();
    final key = 'todos.polish.integration.${now.microsecondsSinceEpoch}';
    final storage = LocalTodoStorage(key: key, themeKey: '$key.theme');
    await storage.save(
      TodoSnapshot(
        spaces: [
          TodoSpace(
            id: TodoSpace.defaultId,
            name: 'Sometime',
            todos: [
              for (var index = 0; index < 2; index++)
                Todo(
                  id: 'polish-$index',
                  title: 'Polish task $index',
                  group: TodoGroup.today,
                  createdAt: now,
                  sortOrder: index,
                ),
            ],
          ),
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
    addTearDown(() {
      tester.platformDispatcher.clearLocalesTestValue();
    });

    await tester.pumpWidget(TodoApp(storage: storage, themeStorage: storage));
    await waitForWidget(tester, find.text('Polish task 0'));

    await tester.tap(find.text('Polish task 0'));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('Polish task 1'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Alles erledigt :D'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alles erledigt :D'), findsOneWidget);
    expect(find.text('2 / 2'), findsNothing);
  });
}
