import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/widgets/completed_section.dart';
import 'package:todo_app/widgets/dashed_divider.dart';
import 'package:todo_app/widgets/todo_section.dart';

import 'support/memory_todo_storage.dart';
import 'support/sample_todos.dart';
import 'todo_app_test.dart' show startApp, control;

class _ReadyMemoryTodoStorage extends MemoryTodoStorage
    implements AppSettingsStorage {
  _ReadyMemoryTodoStorage({required super.snapshot})
    : _settings = const AppSettings(
        hasCompletedOnboarding: true,
        hasSeenFirstEmptyHomeHint: true,
      );

  AppSettings _settings;

  @override
  Future<AppSettings?> loadAppSettings() async => _settings;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    _settings = settings;
  }
}

void main() {
  testWidgets('Completed tasks open upward when no active tasks remain', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);
    await startApp(
      tester,
      _ReadyMemoryTodoStorage(
        snapshot: TodoSnapshot(
          spaces: [
            TodoSpace(
              id: TodoSpace.defaultId,
              name: 'Sometime',
              todos: [
                for (var index = 0; index < 8; index++)
                  Todo(
                    id: 'done-$index',
                    title: 'Done $index',
                    group: TodoGroup.today,
                    createdAt: now,
                    completedAt: now,
                    sortOrder: index,
                  ),
              ],
            ),
          ],
          archive: const [],
          lastKnownLocalDate: DateTime(2026, 9, 4),
        ),
      ),
    );
    expect(find.text('Alles erledigt :D'), findsOneWidget);
    final header = control('Erledigt');
    final headerCenter = tester.getCenter(header);

    await tester.tap(header);
    await tester.pump();
    expect(find.text('Alles erledigt :D'), findsNothing);
    for (final step in [60, 120, 180, 240, 300]) {
      await tester.pump(Duration(milliseconds: step));
      expect(tester.getCenter(header).dy, closeTo(headerCenter.dy, 1));
    }
    await tester.pumpAndSettle();

    expect(tester.getCenter(header).dy, closeTo(headerCenter.dy, 1));
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(
      tester.getBottomLeft(find.text('Done 0')).dy,
      lessThan(tester.getTopLeft(header).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Completed tasks stay anchored after the empty hint is dismissed',
    (tester) async {
      final now = DateTime(2026, 9, 4, 10);
      await startApp(
        tester,
        _ReadyMemoryTodoStorage(
          snapshot: TodoSnapshot(
            spaces: [
              TodoSpace(
                id: TodoSpace.defaultId,
                name: 'Sometime',
                todos: [
                  Todo(
                    id: 'done',
                    title: 'Done',
                    group: TodoGroup.today,
                    createdAt: now,
                    completedAt: now,
                  ),
                ],
              ),
            ],
            archive: const [],
            lastKnownLocalDate: DateTime(2026, 9, 4),
          ),
        ),
      );
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      expect(scroll.offset, closeTo(0, 1));
      for (final group in TodoGroup.values) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is TodoSection && widget.group == group,
          ),
          findsOneWidget,
        );
      }
      final header = control('Erledigt');
      final headerCenter = tester.getCenter(header);

      await tester.tap(header);
      await tester.pumpAndSettle();

      expect(tester.getCenter(header).dy, closeTo(headerCenter.dy, 1));
      expect(scroll.offset, closeTo(0, 1));
      expect(find.text('Alles erledigt :D'), findsNothing);
      expect(
        tester.getBottomLeft(find.text('Done')).dy,
        lessThan(tester.getTopLeft(header).dy),
      );

      await tester.tap(header);
      await tester.pump();
      expect(find.text('Alles erledigt :D'), findsNothing);
      expect(tester.getCenter(header).dy, closeTo(headerCenter.dy, 1));
      for (final step in [30, 60, 90, 120, 180, 240]) {
        await tester.pump(Duration(milliseconds: step));
        expect(tester.getCenter(header).dy, closeTo(headerCenter.dy, 1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Alles erledigt :D'), findsOneWidget);
      expect(
        tester
            .getRect(find.text('Alles erledigt :D'))
            .overlaps(tester.getRect(find.text('Erledigt'))),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Completed section stays anchored after the last task completes',
    (tester) async {
      final now = DateTime(2026, 9, 4, 10);
      final storage = _ReadyMemoryTodoStorage(
        snapshot: TodoSnapshot(
          spaces: [
            TodoSpace(
              id: TodoSpace.defaultId,
              name: 'Sometime',
              todos: [
                Todo(
                  id: 'active',
                  title: 'Active',
                  group: TodoGroup.today,
                  createdAt: now,
                ),
                Todo(
                  id: 'done',
                  title: 'Done',
                  group: TodoGroup.today,
                  createdAt: now,
                  completedAt: now,
                ),
              ],
            ),
          ],
          archive: const [],
          lastKnownLocalDate: now,
        ),
      );
      await startApp(tester, storage);

      await tester.tap(find.text('Active'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      expect(scroll.offset, closeTo(0, 1));
      final header = control('Erledigt');
      final headerCenter = tester.getCenter(header);

      await tester.tap(header);
      await tester.pumpAndSettle();

      expect(tester.getCenter(header).dy, closeTo(headerCenter.dy, 1));
      expect(scroll.offset, closeTo(0, 1));
      expect(
        tester.getBottomLeft(find.text('Done')).dy,
        lessThan(tester.getTopLeft(header).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A completed-only Space opens at the top', (tester) async {
    final now = DateTime(2026, 9, 4, 10);
    await startApp(
      tester,
      _ReadyMemoryTodoStorage(
        snapshot: TodoSnapshot(
          spaces: [
            const TodoSpace(id: 'source', name: 'Source', todos: []),
            TodoSpace(
              id: 'target',
              name: 'Target',
              todos: [
                Todo(
                  id: 'done',
                  title: 'Done',
                  group: TodoGroup.today,
                  createdAt: now,
                  completedAt: now,
                ),
              ],
            ),
          ],
          archive: const [],
          lastKnownLocalDate: now,
        ),
      ),
    );

    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();

    final scroll = tester
        .widget<CustomScrollView>(
          find.byKey(const PageStorageKey<String>('todo-scroll-target')),
        )
        .controller!;
    expect(scroll.offset, closeTo(0, 1));

    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();

    expect(scroll.offset, closeTo(0, 1));
    expect(find.text('Alles erledigt :D'), findsNothing);
    for (final group in TodoGroup.values) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TodoSection && widget.group == group,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('The divider spans the list and a deliberate pull closes it', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 4, 10);
    await startApp(
      tester,
      MemoryTodoStorage(
        todos: [
          ...sampleTodos,
          Todo(
            id: 'done',
            title: 'Done',
            group: TodoGroup.today,
            createdAt: now,
            completedAt: now,
          ),
        ],
      ),
    );
    final divider = find.descendant(
      of: find.byType(CompletedSection),
      matching: find.byType(DashedDivider),
    );
    expect(divider, findsNothing);
    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    expect(tester.getSize(divider).width, closeTo(334, 1));
    expect(
      tester.getTopLeft(divider).dy,
      lessThan(tester.getTopLeft(find.text('Done')).dy),
    );
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    expect(scroll.position.maxScrollExtent, 0);

    var gesture = await tester.startGesture(
      tester.getCenter(find.text('Heute')),
    );
    await gesture.moveBy(const Offset(0, 15));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<CompletedSection>(find.byType(CompletedSection)).expanded,
      isTrue,
    );

    gesture = await tester.startGesture(tester.getCenter(find.text('Heute')));
    for (var i = 0; i < 16; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.offset, greaterThan(-240));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<CompletedSection>(find.byType(CompletedSection)).expanded,
      isFalse,
    );
    expect(divider, findsNothing);
    expect(scroll.offset, closeTo(0, 1));

    await tester.tap(control('Erledigt'));
    await tester.pumpAndSettle();
    await tester.tap(control('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(control('todo öffnen'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CompletedSection>(find.byType(CompletedSection)).expanded,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
