import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/todo_app.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/pressable.dart';

import 'support/memory_todo_storage.dart';

class _TutorialStorage extends MemoryTodoStorage implements AppSettingsStorage {
  _TutorialStorage()
    : appSettings = const AppSettings(
        hasCompletedOnboarding: true,
        hasSeenFirstEmptyHomeHint: true,
      ),
      super(useSampleData: false);

  AppSettings? appSettings;

  @override
  Future<AppSettings?> loadAppSettings() async => appSettings;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    appSettings = settings;
  }
}

Finder _control(String label) => find.byWidgetPredicate(
  (widget) => widget is Pressable && widget.label == label,
);

Future<void> _start(WidgetTester tester, _TutorialStorage storage) async {
  tester.platformDispatcher.localesTestValue = [const Locale('en')];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.platformDispatcher.clearLocalesTestValue();
    tester.view.reset();
  });
  await tester.pumpWidget(
    TodoApp(
      storage: storage,
      themeStorage: storage,
      clock: () => DateTime(2026, 9, 7),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addTask(WidgetTester tester, String title) async {
  await tester.tap(_control('New task'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('todo-title-field')), title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.tap(_control('Add task'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The first saved task opens and persists the edit tutorial', (
    tester,
  ) async {
    final storage = _TutorialStorage();
    await _start(tester, storage);
    await _addTask(tester, 'First task');

    expect(find.byType(AddTodoSheet), findsNothing);
    expect(
      find.byKey(const ValueKey('first-task-edit-tutorial')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('first-task-edit-tutorial')))
          .width,
      358,
    );
    expect(find.text('Manage your task'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    final id = storage.todos!.single.id;
    expect(find.byKey(ValueKey('move-handle-$id')), findsOneWidget);
    expect(_control('Edit: First task'), findsOneWidget);
    expect(storage.appSettings?.hasSeenTaskEditTutorial, isTrue);

    await tester.tap(_control('Got it'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('first-task-edit-tutorial')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('space-management-tutorial')),
      findsOneWidget,
    );
    expect(find.text('Manage Spaces'), findsOneWidget);
    expect(storage.appSettings?.hasSeenSpaceManagementTutorial, isTrue);

    await tester.tap(_control('Got it'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('space-management-tutorial')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _start(tester, storage);
    expect(
      find.byKey(const ValueKey('space-management-tutorial')),
      findsNothing,
    );
  });

  testWidgets('Using the real edit control dismisses the tutorial', (
    tester,
  ) async {
    final storage = _TutorialStorage();
    await _start(tester, storage);
    await _addTask(tester, 'First task');

    await tester.tap(_control('Edit: First task'));
    await tester.pumpAndSettle();

    expect(find.byType(AddTodoSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('first-task-edit-tutorial')),
      findsNothing,
    );
  });

  testWidgets('A second task does not open the tutorial after restart', (
    tester,
  ) async {
    final storage = _TutorialStorage();
    await _start(tester, storage);
    await _addTask(tester, 'First task');

    await tester.tap(_control('Got it'));
    await tester.pumpAndSettle();
    await _addTask(tester, 'Second task');
    expect(
      find.byKey(const ValueKey('first-task-edit-tutorial')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      TodoApp(
        storage: storage,
        themeStorage: storage,
        clock: () => DateTime(2026, 9, 7),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-task-edit-tutorial')),
      findsNothing,
    );
    expect(storage.todos, hasLength(2));
  });

  testWidgets('The Android tutorial includes Pin', (tester) async {
    final storage = _TutorialStorage();
    await _start(tester, storage);
    await _addTask(tester, 'First task');

    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('The iOS tutorial omits Pin', (tester) async {
    final storage = _TutorialStorage();
    await _start(tester, storage);
    await _addTask(tester, 'First task');

    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Pin'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
