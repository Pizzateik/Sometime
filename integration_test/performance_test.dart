import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_app/app/todo_app.dart';
import 'package:todo_app/models/todo_storage.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Measure completion and composer frames', (tester) async {
    final storage = LocalTodoStorage(
      key: 'todos.performance',
      themeKey: 'theme.performance',
    );
    await storage.save(sampleSnapshot(DateTime.now()));
    await tester.pumpWidget(TodoApp(storage: storage, themeStorage: storage));
    await waitForWidget(tester, control('Neue Aufgabe'));

    // Draw the controls once before the measurement starts.
    await tester.tap(control('Frühstück kaufen'));
    await tester.pumpAndSettle();
    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    await tester.tap(control('Frühstück kaufen'));
    await tester.pumpAndSettle();
    await tester.tap(control('Neue Aufgabe'));
    await tester.pumpAndSettle();
    await waitForKeyboard(tester);
    await tester.tap(control('Eingabe schließen'));
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      for (var index = 0; index < 12; index++) {
        await tester.tap(control('Frühstück kaufen'));
        await tester.pumpAndSettle();
        await tester.tap(control('Erledigt'));
        await tester.pumpAndSettle();
        await tester.tap(control('Frühstück kaufen'));
        await tester.pumpAndSettle();
      }
      for (var index = 0; index < 3; index++) {
        await tester.tap(control('Neue Aufgabe'));
        await tester.pumpAndSettle();
        await waitForKeyboard(tester);
        await tester.tap(control('Eingabe schließen'));
        await tester.pumpAndSettle();
      }
      for (var index = 0; index < 3; index++) {
        await tester.drag(
          find.byKey(const ValueKey('main-space-pager')),
          const Offset(-360, 0),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('main-space-pager')),
          const Offset(360, 0),
        );
        await tester.pumpAndSettle();
      }
    }, reportKey: 'interactions');
  });
}
