import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app_theme.dart';
import 'package:todo_app/models/task_details.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/state/todo_controller.dart';
import 'package:todo_app/utils/natural_datetime_parser.dart';
import 'package:todo_app/widgets/sometime_segmented_control.dart';

import 'support/memory_todo_storage.dart';

void main() {
  testWidgets('Midnight archives completed tasks without future routines', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 7, 23, 59, 59);
    final storage = MemoryTodoStorage(
      todos: [
        Todo(
          id: 'done',
          title: 'Done',
          group: TodoGroup.today,
          createdAt: now,
          completedAt: now,
        ),
      ],
      localDate: DateTime(2026, 9, 7),
    );
    final controller = TodoController(storage: storage, clock: () => now);
    await controller.initialize();
    expect(
      controller.completedTodos(controller.spaces.single.id),
      hasLength(1),
    );
    now = DateTime(2026, 9, 8);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.completedTodos(controller.spaces.single.id), isEmpty);
    expect(controller.archive.single.todo.id, 'done');
    controller.dispose();
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'The $brightness selected thumb has area and grows on contact',
      (tester) async {
        var value = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(
              brightness: brightness,
              background: brightness == Brightness.light
                  ? Colors.white
                  : Colors.black,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => SometimeSegmentedControl<int>(
                  values: const [0, 1, 2],
                  value: value,
                  label: (v) => ['Heute', 'Demnächst', 'Irgendwann'][v],
                  onChanged: (next) => update(() => value = next),
                ),
              ),
            ),
          ),
        );
        final color = brightness == Brightness.light
            ? Colors.black
            : Colors.white;
        final thumb = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == color,
        );
        expect(thumb, findsOneWidget);
        expect(tester.getSize(thumb).height, greaterThan(30));
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Heute')),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          find.byWidgetPredicate((w) => w is AnimatedScale && w.scale == 1.05),
          findsOneWidget,
        );
        await gesture.moveTo(tester.getCenter(find.text('Demnächst')));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(value, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('spaceById safely falls back to first space when spaceId is unknown', (tester) async {
    final storage = MemoryTodoStorage();
    final controller = TodoController(storage: storage, clock: () => DateTime(2026, 9, 9));
    await controller.initialize();
    final fallback = controller.spaceById('non-existent-stale-space-id');
    expect(fallback, isNotNull);
    expect(fallback.id, controller.spaces.first.id);
    controller.dispose();
  });

  test('RecurrenceRule handles empty weekdays without throwing', () {
    const rule = RecurrenceRule(type: RecurrenceType.weekly, weekdays: []);
    final now = DateTime(2026, 9, 9);
    final next = rule.nextAfter(now);
    expect(next.isAfter(now), isTrue);
  });

  test('NaturalDateTimeParser handles unusual input without throwing', () {
    final now = DateTime(2026, 9, 9);
    final suggestion = NaturalDateTimeParser.parse(
      title: '??? !!! 99.99.9999 25:99',
      description: 'nothing here',
      now: now,
      languageCode: 'de',
    );
    expect(suggestion.date, isNull);
    expect(suggestion.minutes, isNull);
  });

  test('Theme includes robust platform Japanese fallbacks', () {
    final theme = buildAppTheme(brightness: Brightness.light, background: Colors.white);
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, contains('Noto Sans CJK JP'));
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, contains('Hiragino Sans'));
  });
}
