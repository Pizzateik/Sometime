import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/state/category_progress_controller.dart';

void main() {
  test('creates a baseline on the first completion', () {
    final progress = CategoryProgressController();

    final session = progress.recordCompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      baselineTaskIds: ['a', 'b', 'c'],
      taskId: 'a',
    );

    expect(session.baselineTaskIds, {'a', 'b', 'c'});
    expect(session.totalCount, 3);
    expect(session.completedCount, 1);
  });

  test('increments and decrements within the baseline', () {
    final progress = CategoryProgressController();
    progress.recordCompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      baselineTaskIds: ['a', 'b'],
      taskId: 'a',
    );

    final second = progress.recordCompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      baselineTaskIds: const [],
      taskId: 'b',
    );
    expect(second.completedCount, 2);

    final restored = progress.recordUncompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      taskId: 'b',
    );
    expect(restored!.completedCount, 1);
  });

  test('isolates Spaces and categories and clamps counts', () {
    final progress = CategoryProgressController();
    progress.recordCompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      baselineTaskIds: ['a'],
      taskId: 'a',
    );
    progress.recordCompletion(
      spaceId: 'school',
      category: TodoGroup.today,
      baselineTaskIds: ['b'],
      taskId: 'b',
    );

    final unchanged = progress.recordCompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      baselineTaskIds: const [],
      taskId: 'new',
    );
    expect(unchanged.completedCount, 1);
    expect(progress.sessionFor('school', TodoGroup.today)!.completedCount, 1);

    progress.recordUncompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      taskId: 'a',
    );
    final safe = progress.recordUncompletion(
      spaceId: 'dev',
      category: TodoGroup.today,
      taskId: 'a',
    );
    expect(safe!.completedCount, 0);
  });

  test('reset removes only the changed category session', () {
    final progress = CategoryProgressController();
    for (final category in TodoGroup.values) {
      progress.recordCompletion(
        spaceId: 'dev',
        category: category,
        baselineTaskIds: ['task-${category.name}'],
        taskId: 'task-${category.name}',
      );
    }

    progress.reset('dev', TodoGroup.today);

    expect(progress.sessionFor('dev', TodoGroup.today), isNull);
    expect(progress.sessionFor('dev', TodoGroup.soon), isNotNull);
  });
}
