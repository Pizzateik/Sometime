import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_todo_storage.dart';
import 'todo_app_test.dart' show control, showSettings, startApp;

void main() {
  testWidgets('Language changes while the language page is open', (
    tester,
  ) async {
    final storage = MemoryTodoStorage();
    await startApp(tester, storage, locale: const Locale('en'));
    await showSettings(tester);
    await tester.tap(control('Language'));
    await tester.pumpAndSettle();
    await tester.tap(control('Deutsch'));
    await tester.pumpAndSettle();

    expect(find.text('Sprache'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
