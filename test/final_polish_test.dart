import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app_theme.dart';
import 'package:todo_app/app/sometime_icons.dart';
import 'package:todo_app/widgets/add_todo_button.dart';
import 'package:todo_app/widgets/add_todo_sheet.dart';
import 'package:todo_app/widgets/sometime_input.dart';
import 'package:todo_app/widgets/sometime_segmented_control.dart';
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
}
