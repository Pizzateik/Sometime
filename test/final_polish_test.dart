import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app_config.dart';
import 'package:todo_app/app/app_theme.dart';
import 'package:todo_app/app/sometime_icons.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/widgets/add_todo_button.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/sometime_input.dart';
import 'package:todo_app/widgets/sometime_action_icon.dart';
import 'package:todo_app/widgets/sometime_icon_box.dart';
import 'package:todo_app/widgets/sometime_segmented_control.dart';
import 'package:todo_app/widgets/task_planning_fields.dart';
import 'package:todo_app/models/todo.dart';

import 'support/memory_todo_storage.dart';
import 'todo_app_test.dart' show startApp, control, showSettings;

void main() {
  testWidgets('Disabled purchases expose only local debug supporter tools', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage(), locale: const Locale('en'));
    await showSettings(tester);
    if (kReleaseMode) {
      expect(control('Support Sometime'), findsNothing);
      expect(find.text('Become a Supporter'), findsNothing);
      expect(find.text('Restore Purchases'), findsNothing);
      return;
    }
    await tester.scrollUntilVisible(
      control('Support Sometime'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('settings-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.byKey(const PageStorageKey('settings-scroll')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(control('Support Sometime'));
    await tester.pumpAndSettle();

    expect(find.text('Become a Supporter'), findsNothing);
    expect(find.text('Restore Purchases'), findsNothing);
    expect(find.text('Preview supporter state'), findsOneWidget);
  });

  testWidgets('Enabling purchases restores the purchase and restore UI', (
    tester,
  ) async {
    await startApp(
      tester,
      MemoryTodoStorage(),
      locale: const Locale('en'),
      enableSupporterPurchases: true,
    );
    await showSettings(tester);
    await tester.scrollUntilVisible(
      control('Support Sometime'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('settings-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.byKey(const PageStorageKey('settings-scroll')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(control('Support Sometime'));
    await tester.pumpAndSettle();

    expect(find.text('Become a Supporter'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
  });

  testWidgets('About shows the Sometime source repository', (tester) async {
    await startApp(tester, MemoryTodoStorage(), locale: const Locale('en'));
    await showSettings(tester);
    final sourceCode = find.text('Source Code');
    await tester.scrollUntilVisible(
      sourceCode,
      300,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('settings-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(AppConfig.sourceCodeUrl, 'https://github.com/Pizzateik/Sometime');
    expect(sourceCode, findsOneWidget);
    expect(control('Source Code, external link'), findsOneWidget);
  });

  testWidgets('Create keeps the floating button size and position', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage(), locale: const Locale('en'));
    final origin = tester.getRect(find.byType(AddTodoButton));
    await tester.tap(control('New task'));
    await tester.pumpAndSettle();
    final send = tester.getRect(control('Add task'));
    expect(send.width, 56);
    expect(send.height, 56);
    expect(send.right, closeTo(origin.right, 0.1));
    expect(send.bottom, closeTo(origin.bottom, 0.1));
    expect(find.byType(SometimeSegmentedControl<TodoGroup>), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'New task',
    );
    await tester.pump();
    await tester.tap(control('Add task'));
    await tester.pumpAndSettle();
    expect(find.byType(AddTodoSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Appearance cards use equal light and dark previews', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage(), locale: const Locale('en'));
    await showSettings(tester);
    await tester.tap(control('Experience'));
    await tester.pumpAndSettle();

    final previews = [
      for (final style in AppearanceStyle.values)
        find.byKey(ValueKey('style-preview-${style.name}')),
    ];
    final sizes = [for (final preview in previews) tester.getSize(preview)];
    expect(sizes.toSet(), hasLength(1));
    expect(sizes.first.height, 112);

    for (final style in AppearanceStyle.values) {
      final previewFinder = find.byKey(ValueKey('style-preview-${style.name}'));
      final preview = tester.widget<AnimatedContainer>(previewFinder);
      expect((preview.decoration! as BoxDecoration).gradient, isNull);
      final light = find.byKey(ValueKey('style-preview-light-${style.name}'));
      final dark = find.byKey(ValueKey('style-preview-dark-${style.name}'));
      final lightRect = tester.getRect(light);
      final darkRect = tester.getRect(dark);
      expect(lightRect.width, closeTo(darkRect.width, 0.001));
      expect(lightRect.right, closeTo(darkRect.left, 0.001));
      expect(
        lightRect.width + darkRect.width,
        closeTo(tester.getSize(previewFinder).width, 0.001),
      );
      expect(
        find.byKey(ValueKey('style-preview-control-${style.name}')),
        findsOneWidget,
      );
      final controlLight = tester.getRect(
        find.byKey(ValueKey('style-preview-control-light-${style.name}')),
      );
      final controlDark = tester.getRect(
        find.byKey(ValueKey('style-preview-control-dark-${style.name}')),
      );
      expect(controlLight.width, closeTo(controlDark.width, 0.001));
      expect(controlLight.right, closeTo(controlDark.left, 0.001));
    }
  });

  testWidgets('The fallback profile icon uses the centered icon box', (
    tester,
  ) async {
    await startApp(tester, MemoryTodoStorage());

    final fallback = find.byKey(const ValueKey('profile-fallback-icon'));
    expect(fallback, findsOneWidget);
    final iconBox = tester.widget<SometimeIconBox>(fallback);
    expect(iconBox.dimension, 20);
    expect(iconBox.size, 20);
    expect(iconBox.opticalOffset, const Offset(2, 0));
    expect(
      find.ancestor(of: fallback, matching: find.byType(Center)),
      findsWidgets,
    );
  });

  testWidgets('Core screens fit supported locales at 130 percent text', (
    tester,
  ) async {
    for (final locale in const [
      Locale('en'),
      Locale('de'),
      Locale('es'),
      Locale('pt', 'BR'),
      Locale('fr'),
      Locale('ja'),
    ]) {
      await startApp(
        tester,
        MemoryTodoStorage(),
        locale: locale,
        size: const Size(320, 700),
        scale: 1.3,
      );
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

      await tester.tap(find.byType(AddTodoButton));
      await tester.pumpAndSettle();
      expect(find.byType(AddTodoSheet), findsOneWidget);
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());

      Navigator.of(tester.element(find.byType(AddTodoSheet))).pop();
      await tester.pumpAndSettle();
      await showSettings(tester);
      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('Soft Light uses a neutral surface instead of pure white', () {
    final theme = buildAppTheme(
      brightness: Brightness.light,
      background: AppBackgrounds.offWhite,
    );
    final colors = theme.extension<AppPalette>()!;
    expect(colors.surface, AppBackgrounds.softLightSurface);
    expect(colors.surface, isNot(AppBackgrounds.pureWhite));
  });

  testWidgets('Delete expands and undo restores the task', (tester) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage, locale: const Locale('en'));
    final gesture = await tester.startGesture(
      tester.getCenter(control('Mathe lernen')),
    );
    await tester.pump(const Duration(milliseconds: 390));
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final button = find.byType(AddTodoButton);
    expect(tester.getSize(button).width, 138);
    expect(tester.getSize(button).height, 56);
    await gesture.moveTo(tester.getCenter(button));
    await tester.pump();
    expect(tester.widget<AddTodoButton>(button).deleteHovered, true);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Item deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(storage.todos!.any((t) => t.id == 'demo-2'), true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Name input uses the shared radius and a comfortable height', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          background: Colors.white,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SometimeInput(controller: controller, hint: 'Name'),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(SometimeInput)).height,
      greaterThanOrEqualTo(58),
    );
    expect(
      Theme.of(tester.element(find.byType(TextField)))
          .textTheme
          .bodyLarge!
          .fontFamily,
      'Geist',
    );
    controller.dispose();
  });
  test('The pin uses regular and fill variants', () {
    expect(SometimeIcons.pushPin, isNot(SometimeIcons.pushPinActive));
  });

  testWidgets('Action icons use fixed centered geometry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: Center(
            child: SometimeActionIconBox(
              key: ValueKey('plus-action-icon'),
              glyph: SometimeActionGlyph.plus,
              size: 26,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('plus-action-icon'))),
      const Size.square(32),
    );
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('plus-action-icon')),
          matching: find.byType(CustomPaint),
        ),
      ),
      const Size.square(26),
    );
  });

  testWidgets('Task planning icons align with their labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          background: Colors.white,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: TaskPlanningFields(
              value: const TaskDetails(),
              isPinned: false,
              onChanged: (_) {},
              onPinChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final icon = find.byIcon(SometimeIcons.arrowsClockwise);
    final label = find.text('Routine');
    expect(icon, findsOneWidget);
    expect(label, findsOneWidget);
    expect(tester.getCenter(icon).dy, closeTo(tester.getCenter(label).dy, 0.1));
  });
}
