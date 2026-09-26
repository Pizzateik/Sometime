import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/services/assistant_task_bridge.dart';
import 'package:todo_app/state/todo_controller.dart';

import 'support/memory_todo_storage.dart';

void main() {
  final now = DateTime(2026, 9, 23, 10);

  test('Assistant task defaults to Soon and keeps explicit date and time', () {
    final draft = const AssistantTaskRequest(
      id: 'one',
      title: 'Pick up parcel',
      date: '2026-09-25',
      time: '18:30:00',
    ).toDraft(now: now, languageCode: 'en');

    expect(draft.title, 'Pick up parcel');
    expect(draft.group, TodoGroup.soon);
    expect(draft.details.date, DateTime(2026, 9, 25));
    expect(draft.details.minutes, 18 * 60 + 30);
  });

  test('Spoken category and natural date and time become task fields', () {
    final draft = const AssistantTaskRequest(
      id: 'two',
      title: 'Call dentist tomorrow at 9:15 to Today',
    ).toDraft(now: now, languageCode: 'en');

    expect(draft.title, 'Call dentist tomorrow at 9:15');
    expect(draft.group, TodoGroup.today);
    expect(draft.details.date, DateTime(2026, 9, 24));
    expect(draft.details.minutes, 9 * 60 + 15);
  });

  test('Explicit category wins and Sometime maps to someday', () {
    final draft = const AssistantTaskRequest(
      id: 'three',
      title: 'Read a novel to Today',
      category: 'sometime',
    ).toDraft(now: now, languageCode: 'en');

    expect(draft.group, TodoGroup.someday);
  });

  test('Replaying an assistant request does not create a second task', () async {
    final storage = MemoryTodoStorage(useSampleData: false);
    final controller = TodoController(
      storage: storage,
      clock: () => now,
    );
    await controller.initialize();
    final draft = const TodoDraft(title: 'Buy milk', group: TodoGroup.soon);
    final first = controller.addTodo(
      TodoSpace.defaultId,
      draft,
      requestId: 'same-request',
    );
    await controller.flush();
    controller.dispose();

    final restarted = TodoController(storage: storage, clock: () => now);
    await restarted.initialize();
    final second = restarted.addTodo(
      TodoSpace.defaultId,
      draft,
      requestId: 'same-request',
    );

    expect(second, first);
    expect(
      restarted.activeTodos(TodoSpace.defaultId, TodoGroup.soon),
      hasLength(1),
    );
    restarted.dispose();
  });
}
