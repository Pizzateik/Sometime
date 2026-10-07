import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/services/app_shortcut_bridge.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/task_planning_fields.dart';

import 'support/memory_todo_storage.dart';
import 'todo_app_test.dart' show startApp, control, showSettings;

class _OnboardingStorage extends MemoryTodoStorage
    implements AppSettingsStorage {
  _OnboardingStorage() : super(todos: []);
  AppSettings? settings;
  @override
  Future<AppSettings?> loadAppSettings() async => settings;
  @override
  Future<void> saveAppSettings(AppSettings value) async => settings = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? pending;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    pending = null;
    AppShortcutBridge.target.value = null;
    messenger.setMockMethodCallHandler(AppShortcutBridge.channel, (call) async {
      expect(call.method, 'launch');
      final action = pending;
      pending = null;
      return action;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AppShortcutBridge.channel, null);
    AppShortcutBridge.target.value = null;
  });

  Future<void> launch(WidgetTester tester, String action) async {
    pending = action;
    await messenger.handlePlatformMessage(
      AppShortcutBridge.channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('open')),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  for (final action in ['new_task', 'new_routine', 'someday']) {
    testWidgets('$action opens on cold start and saves the selected defaults', (
      tester,
    ) async {
      pending = action;
      final storage = MemoryTodoStorage(todos: []);
      await startApp(tester, storage);
      expect(find.byType(AddTodoSheet), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('todo-title-field')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      final details = tester
          .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
          .value;
      if (action == 'new_routine') {
        expect(details.recurrence!.type, RecurrenceType.weekly);
        expect(details.recurrence!.weekdays, [DateTime(2026, 9, 4).weekday]);
      } else {
        expect(details.recurrence, isNull);
      }
      await tester.enterText(
        find.byKey(const ValueKey('todo-title-field')),
        'Shortcut task',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.ensureVisible(control('Aufgabe hinzufügen'));
      await tester.tap(control('Aufgabe hinzufügen'));
      await tester.pumpAndSettle();
      final saved = storage.todos!.single;
      expect(saved.title, 'Shortcut task');
      expect(
        saved.group,
        action == 'someday' ? TodoGroup.someday : TodoGroup.today,
      );
      expect(saved.details.recurrence != null, action == 'new_routine');
      expect(find.byType(AddTodoSheet), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(AddTodoSheet), findsNothing);
      expect(storage.todos, hasLength(1));
    });
  }

  testWidgets(
    'Warm shortcut replaces an open editor without saving its draft',
    (tester) async {
      final storage = MemoryTodoStorage(todos: []);
      await startApp(tester, storage);
      await tester.tap(control('Neue Aufgabe'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('todo-title-field')),
        'Unsaved draft',
      );
      await launch(tester, 'new_routine');
      expect(find.byType(AddTodoSheet), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('todo-title-field')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
            .value
            .recurrence,
        isNotNull,
      );
      expect(storage.todos, isEmpty);
      await launch(tester, 'new_routine');
      expect(find.byType(AddTodoSheet), findsOneWidget);
    },
  );

  testWidgets('Shortcut leaves settings and opens the first space', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage(todos: []));
    await showSettings(tester);
    await launch(tester, 'someday');
    expect(find.byType(AddTodoSheet), findsOneWidget);
    expect(
      tester
          .widget<AddTodoSheet>(find.byType(AddTodoSheet))
          .initialDraft!
          .group,
      TodoGroup.someday,
    );
  });

  testWidgets('Shortcut creates in the currently selected space', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: const [
          TodoSpace(id: 'first', name: 'First', todos: []),
          TodoSpace(id: 'second', name: 'Second', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage);
    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(-390, 0),
    );
    await tester.pumpAndSettle();
    await launch(tester, 'new_task');
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Second space task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(control('Aufgabe hinzufügen'));
    await tester.pumpAndSettle();
    expect(storage.snapshot!.spaces.first.todos, isEmpty);
    expect(
      storage.snapshot!.spaces.last.todos.single.title,
      'Second space task',
    );
  });

  testWidgets('Pending shortcut waits for onboarding', (tester) async {
    pending = 'new_routine';
    await startApp(tester, _OnboardingStorage(), locale: const Locale('en'));
    expect(find.byType(AddTodoSheet), findsNothing);
    await tester.tap(control('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(AddTodoSheet), findsOneWidget);
    expect(
      tester
          .widget<TaskPlanningFields>(find.byType(TaskPlanningFields))
          .value
          .recurrence,
      isNotNull,
    );
  });
}
