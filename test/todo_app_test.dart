import 'dart:ui' show CheckedState, Tristate;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:dynamic_color/samples.dart';
import 'package:dynamic_color/test_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app_theme.dart';
import 'package:todo_app/app/todo_app.dart';
import 'package:todo_app/app/todo_date_formatter.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/screens/settings_screen.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/dashed_divider.dart';
import 'package:todo_app/widgets/pressable.dart';
import 'package:todo_app/widgets/todo_item.dart';
import 'package:todo_app/widgets/todo_section.dart';

import 'support/memory_todo_storage.dart';
import 'support/sample_todos.dart';

Finder control(String label) => find.byWidgetPredicate(
  (widget) => widget is Pressable && widget.label == label,
);

Future<void> startApp(
  WidgetTester tester,
  MemoryTodoStorage storage, {
  DateTime Function()? clock,
  Locale locale = const Locale('de'),
  Size size = const Size(390, 844),
  double scale = 1,
  bool reduceMotion = false,
  Brightness platformBrightness = Brightness.light,
  bool enableSupporterPurchases = false,
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearLocalesTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  await tester.pumpWidget(
    TodoApp(
      storage: storage,
      themeStorage: storage,
      clock: clock ?? () => DateTime(2026, 9, 4, 10),
      enableSupporterPurchases: enableSupporterPurchases,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> showSettings(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('main-space-pager')),
    const Offset(-390, 0),
  );
  await tester.pumpAndSettle();
}

ThemeData currentTheme(WidgetTester tester) => Theme.of(
  tester.element(
    find.byKey(const ValueKey('main-space-pager'), skipOffstage: false),
  ),
);

Todo task({
  required String id,
  required String title,
  required TodoGroup group,
  required DateTime createdAt,
  DateTime? completedAt,
  TodoGroup? originalGroup,
  int sortOrder = 0,
}) => Todo(
  id: id,
  title: title,
  group: group,
  originalGroup: originalGroup,
  createdAt: createdAt,
  completedAt: completedAt,
  sortOrder: sortOrder,
);

void main() {
  testWidgets(
    'Material You uses system colors and reloads them after restart',
    (tester) async {
      DynamicColorTestingUtils.setMockDynamicColors(
        corePalette: SampleCorePalettes.green,
      );
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);
      await showSettings(tester);
      await tester.tap(control('Darstellung'));
      await tester.pumpAndSettle();
      await tester.tap(control('Farbe'));
      await tester.pumpAndSettle();
      expect(storage.appearancePreference?.style, AppearanceStyle.materialYou);
      expect(
        currentTheme(tester).colorScheme.primary,
        SampleCorePalettes.green.toColorScheme().primary,
      );
      expect(control('Material You'), findsOneWidget);
      await tester.tap(control('Eigene Farbe'));
      await tester.pumpAndSettle();
      expect(control('Farbe'), findsOneWidget);
      expect(
        currentTheme(tester).colorScheme,
        sometimeColorScheme(Brightness.light),
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      await tester.tap(control('Material You').first);
      await tester.pumpAndSettle();
      expect(control('Material You'), findsOneWidget);
      expect(
        currentTheme(tester).colorScheme.primary,
        SampleCorePalettes.green.toColorScheme().primary,
      );
      for (final mode in [
        AppearanceMode.dark,
        AppearanceMode.light,
        AppearanceMode.system,
      ]) {
        await tester.tap(
          control(["System", "Hell", "Dunkel"][mode.index]).last,
        );
        await tester.pumpAndSettle();
        final brightness = mode == AppearanceMode.dark
            ? Brightness.dark
            : Brightness.light;
        expect(
          currentTheme(tester).colorScheme,
          SampleCorePalettes.green.toColorScheme(brightness: brightness),
        );
      }
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(currentTheme(tester).brightness, Brightness.dark);
      expect(
        currentTheme(tester).extension<AppPalette>()!.text,
        currentTheme(tester).colorScheme.onSurface,
      );
      expect(AppBackgrounds.deleteAccent, const Color(0xFFFF303B));
      await tester.pumpWidget(const SizedBox.shrink());
      DynamicColorTestingUtils.setMockDynamicColors();
      await startApp(tester, storage);
      expect(storage.appearancePreference?.style, AppearanceStyle.materialYou);
      expect(
        currentTheme(tester).colorScheme,
        sometimeColorScheme(Brightness.light),
      );
    },
  );

  testWidgets(
    'The iOS color style uses the fallback and keeps its saved name',
    (tester) async {
      DynamicColorTestingUtils.setMockDynamicColors(
        corePalette: SampleCorePalettes.green,
      );
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);
      await showSettings(tester);
      await tester.tap(control('Darstellung'));
      await tester.pumpAndSettle();
      await tester.tap(control('Farbe'));
      await tester.pumpAndSettle();
      expect(storage.appearancePreference?.style, AppearanceStyle.materialYou);
      expect(
        currentTheme(tester).colorScheme,
        sometimeColorScheme(Brightness.light),
      );
      await tester.tap(control('Dunkel'));
      await tester.pumpAndSettle();
      expect(
        currentTheme(tester).colorScheme,
        sometimeColorScheme(Brightness.dark),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('A fresh start shows an empty todo space', (tester) async {
    final storage = MemoryTodoStorage(useSampleData: false);
    await startApp(tester, storage);

    expect(find.text('Sometime'), findsOneWidget);
    for (final group in TodoGroup.values) {
      expect(find.text(group.label), findsOneWidget);
    }
    expect(find.byType(TodoItem), findsNothing);
    expect(control('Neue Aufgabe'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(DashedDivider), findsNWidgets(2));
    expect(control('Erledigt'), findsNothing);
    expect(storage.snapshot!.spaces, hasLength(1));
    expect(storage.snapshot!.spaces.single.todos, isEmpty);
  });

  for (final group in TodoGroup.values) {
    testWidgets('A new task goes into ${group.name} and survives restart', (
      tester,
    ) async {
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);
      await tester.tap(control('Neue Aufgabe'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('todo-title-field')),
        '  Milch kaufen  ',
      );
      await tester.tap(control(group.label));
      await tester.pumpAndSettle();
      await tester.tap(control('Aufgabe hinzufügen'));
      await tester.pumpAndSettle();

      expect(find.byType(AddTodoSheet), findsNothing);
      expect(find.text('Milch kaufen'), findsOneWidget);
      expect(storage.todos!.last.title, 'Milch kaufen');
      expect(storage.todos!.last.group, group);
      expect(storage.todos!.last.createdAt, DateTime(2026, 9, 4, 10));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        TodoApp(
          storage: storage,
          themeStorage: storage,
          clock: () => DateTime(2026, 9, 4, 10),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Milch kaufen'), findsOneWidget);
    });
  }

  testWidgets('Completion moves a task into the collapsed completed section', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);

    await tester.tap(control('Frühstück kaufen'));
    await tester.pump();
    expect(find.text('Frühstück kaufen'), findsOneWidget);
    expect(control('Erledigt'), findsNothing);
    expect(storage.todos!.first.completedPending, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Frühstück kaufen'), findsNothing);
    expect(control('Erledigt'), findsOneWidget);
    expect(find.byType(DashedDivider), findsNWidgets(2));
    expect(storage.todos!.first.completedAt, DateTime(2026, 9, 4, 10));
    expect(storage.todos!.first.originalGroup, TodoGroup.today);

    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Frühstück kaufen'), findsOneWidget);
    expect(find.byType(DashedDivider), findsNWidgets(3));
    expect(
      tester
          .getSemantics(control('Frühstück kaufen'))
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );
  });

  testWidgets('Restoring a task returns it to its original group', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);

    await tester.tap(control('Bewerbung fertig machen'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    await tester.tap(control('Bewerbung fertig machen'));
    await tester.pumpAndSettle();

    final restored = storage.todos!.singleWhere((todo) => todo.id == 'demo-3');
    expect(restored.isComplete, isFalse);
    expect(restored.group, TodoGroup.soon);
    expect(restored.originalGroup, TodoGroup.soon);
    expect(control('Erledigt'), findsNothing);
    expect(find.text('Bewerbung fertig machen'), findsOneWidget);
  });

  testWidgets('The completed section expands and collapses', (tester) async {
    await startApp(tester, MemoryTodoStorage());
    await tester.tap(control('Mathe lernen'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Mathe lernen'), findsNothing);

    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Mathe lernen'), findsOneWidget);
    expect(
      tester.getSemantics(control('Erledigt')).flagsCollection.isExpanded,
      Tristate.isTrue,
    );

    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('Mathe lernen'), findsNothing);
  });

  testWidgets('A completed task stays completed after restart', (tester) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);
    await tester.tap(control('Mathe lernen'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      TodoApp(
        storage: storage,
        themeStorage: storage,
        clock: () => DateTime(2026, 9, 4, 12),
      ),
    );
    await tester.pumpAndSettle();
    expect(control('Erledigt'), findsOneWidget);
    expect(find.text('Mathe lernen'), findsNothing);
    expect(storage.todos![1].isComplete, isTrue);
  });

  testWidgets('App start archives completed tasks from the prior day', (
    tester,
  ) async {
    final monday = DateTime(2026, 9, 7, 20);
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: TodoSpace.defaultId,
            name: 'Sometime',
            todos: [
              task(
                id: 'done',
                title: 'Montagsaufgabe',
                group: TodoGroup.today,
                createdAt: monday,
                completedAt: monday,
              ),
            ],
          ),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 7),
      ),
    );

    await startApp(tester, storage, clock: () => DateTime(2026, 9, 8, 8));
    expect(control('Erledigt'), findsNothing);
    expect(find.text('Montagsaufgabe'), findsNothing);
    expect(storage.snapshot!.archive, hasLength(1));
    expect(storage.snapshot!.archive.single.todo.title, 'Montagsaufgabe');
    expect(storage.todos, isEmpty);
  });

  testWidgets('App resume archives tasks after a local day change', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 7, 20);
    final storage = MemoryTodoStorage();
    await startApp(tester, storage, clock: () => now);
    await tester.tap(control('Frühstück kaufen'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(control('Erledigt'), findsOneWidget);

    now = DateTime(2026, 9, 8, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(control('Erledigt'), findsNothing);
    expect(storage.snapshot!.archive, hasLength(1));
    expect(storage.snapshot!.lastKnownLocalDate, DateTime(2026, 9, 8));
  });

  testWidgets('The current local date uses the app locale', (tester) async {
    final now = DateTime(2026, 9, 4, 10);
    await startApp(tester, MemoryTodoStorage(), clock: () => now);
    expect(find.byKey(const ValueKey('today-date')), findsOneWidget);
    expect(
      find.text(const TodoDateFormatter().format(now, const Locale('de'))),
      findsOneWidget,
    );
  });

  testWidgets('Horizontal swipes move between todo and settings', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage());
    await showSettings(tester);
    expect(find.text('Einstellungen').hitTestable(), findsOneWidget);
    expect(find.text('Darstellung').hitTestable(), findsOneWidget);
    expect(find.text('Sprache').hitTestable(), findsOneWidget);
    expect(find.text('Mitteilungen').hitTestable(), findsOneWidget);
    await tester.ensureVisible(control('Daten und Datenschutz'));
    await tester.pumpAndSettle();
    expect(find.text('Daten und Datenschutz').hitTestable(), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(390, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sometime').hitTestable(), findsOneWidget);
  });

  testWidgets('The profile placeholder opens the last page', (tester) async {
    await startApp(tester, MemoryTodoStorage());
    await tester.tap(control('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen').hitTestable(), findsOneWidget);
  });

  testWidgets('The profile shortcut skips future spaces and opens settings', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: const [
          TodoSpace(id: 'private', name: 'Privat', todos: []),
          TodoSpace(id: 'work', name: 'Arbeit', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage);
    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.childrenDelegate.estimatedChildCount, 3);

    await tester.tap(control('Einstellungen öffnen').first);
    await tester.pumpAndSettle();
    expect(pager.controller!.page, 2);
    expect(find.text('Einstellungen').hitTestable(), findsOneWidget);
  });

  testWidgets('Profile scale follows the swipe progress', (tester) async {
    await startApp(tester, MemoryTodoStorage());
    final gesture = await tester.startGesture(const Offset(195, 500));
    await gesture.moveBy(const Offset(-195, 0));
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('profile-scale-default-space')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.02));
    expect(transform.transform.getMaxScaleOnAxis(), lessThan(1.09));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('The shared header stays visible and favors the profile', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage());
    await showSettings(tester);

    expect(find.text('Sometime').hitTestable(), findsNWidgets(2));
    final label = tester.widgetList<Text>(find.text('Sometime')).first;
    expect(label.style!.fontSize, 24);
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('profile-scale-default-space')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.1));
  });

  testWidgets('The completed section stays near the content bottom', (
    tester,
  ) async {
    final completedAt = DateTime(2026, 9, 4, 9);
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: TodoSpace.defaultId,
            name: 'Sometime',
            todos: [
              task(
                id: 'done',
                title: 'Fertig',
                group: TodoGroup.today,
                createdAt: completedAt,
                completedAt: completedAt,
              ),
            ],
          ),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage);

    expect(tester.getTopLeft(control('Erledigt')).dy, greaterThan(620));
  });

  testWidgets('The completed section follows long content in one scroll view', (
    tester,
  ) async {
    final createdAt = DateTime(2026, 9, 4, 9);
    final storage = MemoryTodoStorage(
      snapshot: TodoSnapshot(
        spaces: [
          TodoSpace(
            id: TodoSpace.defaultId,
            name: 'Sometime',
            todos: [
              for (var index = 0; index < 14; index++)
                task(
                  id: 'task-$index',
                  title: 'Aufgabe $index',
                  group: TodoGroup.someday,
                  createdAt: createdAt,
                  sortOrder: index,
                ),
              task(
                id: 'done',
                title: 'Fertig',
                group: TodoGroup.today,
                createdAt: createdAt,
                completedAt: createdAt,
              ),
            ],
          ),
        ],
        archive: const [],
        lastKnownLocalDate: DateTime(2026, 9, 4),
      ),
    );
    await startApp(tester, storage);
    expect(find.byType(CustomScrollView), findsOneWidget);

    await tester.scrollUntilVisible(
      control('Erledigt'),
      240,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    expect(control('Erledigt').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'Long press opens the task controls and editing reuses the form',
    (tester) async {
      final storage = MemoryTodoStorage();
      await startApp(tester, storage);

      await tester.longPress(control('Mathe lernen'));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byKey(const ValueKey('move-handle-demo-2')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('completion-control-demo-2')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('edit-task-demo-2')), findsOneWidget);

      await tester.tap(find.text('Heute'));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byKey(const ValueKey('move-handle-demo-2')), findsNothing);
      await tester.longPress(control('Mathe lernen'));
      await tester.pump(const Duration(milliseconds: 220));

      await tester.tap(find.byKey(const ValueKey('edit-task-demo-2')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('todo-title-field')),
      );
      expect(field.controller!.text, 'Mathe lernen');
      await tester.enterText(
        find.byKey(const ValueKey('todo-title-field')),
        'Physik lernen',
      );
      await tester.tap(control('Demnächst'));
      await tester.pump();
      await tester.tap(control('Änderungen speichern'));
      await tester.pumpAndSettle();

      final edited = storage.todos!.singleWhere((todo) => todo.id == 'demo-2');
      expect(edited.title, 'Physik lernen');
      expect(edited.group, TodoGroup.soon);
      expect(find.byKey(const ValueKey('move-handle-demo-2')), findsNothing);
    },
  );

  testWidgets('The move handle can move a task between groups', (tester) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);

    await tester.longPress(control('Neue Laufschuhe suchen'));
    await tester.pump(const Duration(milliseconds: 220));
    final handle = find.byKey(const ValueKey('move-handle-demo-4'));
    final target = find.text('Heute');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 2));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 250));

    final moved = storage.todos!.singleWhere((todo) => todo.id == 'demo-4');
    expect(moved.group, TodoGroup.today);
    expect(moved.sortOrder, 0);
    expect(
      tester.getTopLeft(find.text('Neue Laufschuhe suchen')).dy,
      lessThan(tester.getTopLeft(find.text('Frühstück kaufen')).dy),
    );
  });

  testWidgets('A new space precedes settings and survives a restart', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);
    expect(find.byKey(const ValueKey('add-space')), findsNothing);
    await tester.longPress(find.text('Sometime'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-space')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arbeit');
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();
    expect(storage.snapshot!.spaces.map((space) => space.name), [
      'Sometime',
      'Arbeit',
    ]);
    expect(storage.snapshot!.spaces.last.todos, isEmpty);
    expect(find.byKey(const ValueKey('add-space')), findsNothing);
    expect(find.text('Mathe lernen'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await startApp(tester, storage);
    expect(find.text('Arbeit'), findsOneWidget);
    await tester.tap(find.text('Arbeit'));
    await tester.pumpAndSettle();
    expect(find.text('Mathe lernen'), findsNothing);
    await showSettings(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Space management closes and supports a second space', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);
    await tester.longPress(find.text('Sometime'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heute'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-space')), findsNothing);
    for (final name in ['Arbeit', 'Privat']) {
      await tester.longPress(find.text('Sometime'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-space')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();
    }
    expect(storage.snapshot!.spaces.map((space) => space.name), [
      'Sometime',
      'Arbeit',
      'Privat',
    ]);
    await tester.longPress(find.text('Privat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arbeit'));
    await tester.pumpAndSettle();
    expect(find.text('Space umbenennen'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-space')), findsNothing);
    await tester.longPress(find.text('Arbeit'));
    await tester.pumpAndSettle();
    await tester.tap(control('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-space')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Space management deletes a Space after confirmation', (
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
          TodoSpace(
            id: 'work-id',
            name: 'Work',
            todos: [
              Todo(
                id: 'work-task',
                title: 'Work task',
                group: TodoGroup.today,
                createdAt: now,
              ),
            ],
          ),
          const TodoSpace(id: 'study-id', name: 'Study', todos: []),
        ],
        archive: const [],
        lastKnownLocalDate: now,
      ),
    );
    await startApp(tester, storage);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Space löschen'), findsOneWidget);

    await tester.tap(find.text('Space löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Diesen Space löschen?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Löschen'),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.snapshot!.spaces.map((space) => space.id), [
      TodoSpace.defaultId,
      'study-id',
    ]);
    expect(
      storage.snapshot!.spaces.any((space) => space.id == 'work-id'),
      isFalse,
    );
    expect(find.text('Work'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The last Space can be renamed but not deleted', (tester) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);

    await tester.longPress(find.text('Sometime'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sometime'));
    await tester.pumpAndSettle();

    expect(find.text('Space löschen'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Main');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(storage.snapshot!.spaces.single.name, 'Main');
    expect(tester.takeException(), isNull);
  });

  for (final startOnText in [true, false]) {
    testWidgets(
      'The task row previews a move without a duplicate: $startOnText',
      (tester) async {
        final storage = MemoryTodoStorage(
          todos: [
            for (var i = 0; i < 3; i++)
              task(
                id: 'row-$i',
                title: 'Task $i',
                group: TodoGroup.today,
                createdAt: DateTime(2026, 9, 4),
                sortOrder: i,
              ),
          ],
        );
        await startApp(tester, storage);
        await tester.longPress(find.text('Task 2'));
        await tester.pumpAndSettle();
        final textBounds = tester.getRect(find.text('Task 2'));
        final editBounds = tester.getRect(
          find.byKey(const ValueKey('edit-task-row-2')),
        );
        expect(editBounds.left - textBounds.right, lessThanOrEqualTo(24));
        final origin = startOnText
            ? textBounds.center
            : Offset(350, textBounds.center.dy);
        final gesture = await tester.startGesture(origin);
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump();
        final targetY = tester.getBottomLeft(find.text('Task 0')).dy + 4;
        await gesture.moveTo(Offset(origin.dx, targetY));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Task 2'), findsOneWidget);
        expect(find.byType(Draggable<Object>), findsNothing);
        final section = tester
            .widgetList<TodoSection>(find.byType(TodoSection))
            .firstWhere((section) => section.group == TodoGroup.today);
        expect(section.todos.map((todo) => todo.id), [
          'row-0',
          'row-2',
          'row-1',
        ]);
        await gesture.up();
        await tester.pumpAndSettle();
        final saved =
            storage.todos!
                .where((todo) => todo.group == TodoGroup.today)
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        expect(saved.map((todo) => todo.id), ['row-0', 'row-2', 'row-1']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'An empty category accepts a task and cancellation restores the source',
    (tester) async {
      final storage = MemoryTodoStorage(
        todos: [
          task(
            id: 'only',
            title: 'Only task',
            group: TodoGroup.today,
            createdAt: DateTime(2026, 9, 4),
          ),
        ],
      );
      await startApp(tester, storage);
      for (final cancel in [true, false]) {
        await tester.longPress(find.text('Only task'));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Only task')),
        );
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.text('Demnächst')));
        await tester.pump(const Duration(milliseconds: 300));
        final section = tester
            .widgetList<TodoSection>(find.byType(TodoSection))
            .firstWhere((section) => section.group == TodoGroup.soon);
        expect(section.todos.single.id, 'only');
        expect(find.text('Only task'), findsOneWidget);
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(
          storage.todos!.single.group,
          cancel ? TodoGroup.today : TodoGroup.soon,
        );
      }
    },
  );

  testWidgets('A stationary pointer near the edge scrolls the list', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(
      todos: [
        for (var i = 0; i < 24; i++)
          task(
            id: 'long-$i',
            title: 'Long task $i',
            group: TodoGroup.today,
            createdAt: DateTime(2026, 9, 4),
            sortOrder: i,
          ),
      ],
    );
    await startApp(tester, storage);
    await tester.longPress(find.text('Long task 0'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Long task 0')),
    );
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    await gesture.moveTo(const Offset(150, 800));
    await tester.pump();
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = scroll.offset;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.offset, greaterThan(before + 50));
    await gesture.cancel();
    await tester.pumpAndSettle();
    final stopped = scroll.offset;
    await tester.pump(const Duration(milliseconds: 300));
    expect(scroll.offset, stopped);
    expect(tester.takeException(), isNull);
  });

  testWidgets('System theme follows light and dark platform modes', (
    tester,
  ) async {
    await startApp(
      tester,
      MemoryTodoStorage(themePreference: ThemePreference.system),
    );
    expect(currentTheme(tester).brightness, Brightness.light);
    expect(
      currentTheme(tester).scaffoldBackgroundColor,
      AppBackgrounds.offWhite,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(currentTheme(tester).brightness, Brightness.dark);
    expect(
      currentTheme(tester).scaffoldBackgroundColor,
      AppBackgrounds.softDark,
    );
  });

  for (final entry in [
    (
      mode: AppearanceMode.light,
      style: AppearanceStyle.soft,
      background: AppBackgrounds.offWhite,
      brightness: Brightness.light,
    ),
    (
      mode: AppearanceMode.light,
      style: AppearanceStyle.normal,
      background: AppBackgrounds.pureWhite,
      brightness: Brightness.light,
    ),
    (
      mode: AppearanceMode.dark,
      style: AppearanceStyle.normal,
      background: AppBackgrounds.oledBlack,
      brightness: Brightness.dark,
    ),
  ]) {
    testWidgets(
      '${entry.mode.label} with ${entry.style.label} uses its palette',
      (tester) async {
        final storage = MemoryTodoStorage();
        await startApp(
          tester,
          storage,
          platformBrightness: entry.brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        );
        await showSettings(tester);
        await tester.tap(control('Darstellung'));
        await tester.pumpAndSettle();
        await tester.tap(
          control(
            entry.style == AppearanceStyle.soft
                ? "Sanft"
                : entry.style == AppearanceStyle.normal
                ? "Klar"
                : entry.style.label,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          control(["System", "Hell", "Dunkel"][entry.mode.index]),
        );
        await tester.pumpAndSettle();

        expect(storage.appearancePreference?.mode, entry.mode);
        expect(storage.appearancePreference?.style, entry.style);
        final appearanceTheme = Theme.of(
          tester.element(find.byType(AppearanceScreen)),
        );
        expect(appearanceTheme.brightness, entry.brightness);
        expect(appearanceTheme.scaffoldBackgroundColor, entry.background);
      },
    );
  }

  testWidgets('The selected theme survives an app restart', (tester) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage);
    await showSettings(tester);
    await tester.tap(control('Darstellung'));
    await tester.pumpAndSettle();
    await tester.tap(control('Klar'));
    await tester.pumpAndSettle();
    await tester.tap(control('Dunkel'));
    await tester.pumpAndSettle();
    expect(storage.appearancePreference?.mode, AppearanceMode.dark);
    expect(storage.appearancePreference?.style, AppearanceStyle.normal);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      TodoApp(
        storage: storage,
        themeStorage: storage,
        clock: () => DateTime(2026, 9, 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(currentTheme(tester).brightness, Brightness.dark);
    expect(
      currentTheme(tester).scaffoldBackgroundColor,
      AppBackgrounds.oledBlack,
    );
  });

  testWidgets('Large text and safe areas keep the main flow usable', (
    tester,
  ) async {
    await startApp(
      tester,
      MemoryTodoStorage(),
      size: const Size(320, 568),
      scale: 2,
    );
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
    await tester.pump();
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('The touch targets and labels meet accessibility guidelines', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage());
    await tester.tap(control('Mathe lernen'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('A load error can be retried without replacing saved tasks', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(todos: [sampleTodos.last])
      ..failLoad = true;
    await startApp(tester, storage);
    expect(control('Neue Aufgabe'), findsNothing);
    expect(storage.saveCount, 0);
    storage.failLoad = false;
    await tester.tap(control('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.byType(TodoItem), findsOneWidget);
    expect(storage.todos!.single.id, sampleTodos.last.id);
  });

  testWidgets('A write error keeps the task and allows a retry', (
    tester,
  ) async {
    final storage = MemoryTodoStorage(todos: List.of(sampleTodos))
      ..failSave = true;
    await startApp(tester, storage);
    await tester.tap(control('Mathe lernen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Die Aufgaben konnten nicht gespeichert werden.'),
      findsOneWidget,
    );
    storage.failSave = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(storage.todos![1].isComplete, isTrue);
  });
}
