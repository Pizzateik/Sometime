import 'package:todo_app/models/todo.dart';

final sampleTodos = <Todo>[
  Todo(
    id: 'demo-1',
    title: 'Frühstück kaufen',
    group: TodoGroup.today,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    sortOrder: 0,
  ),
  Todo(
    id: 'demo-2',
    title: 'Mathe lernen',
    group: TodoGroup.today,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    sortOrder: 1,
  ),
  Todo(
    id: 'demo-3',
    title: 'Bewerbung fertig machen',
    group: TodoGroup.soon,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    sortOrder: 0,
  ),
  Todo(
    id: 'demo-4',
    title: 'Neue Laufschuhe suchen',
    group: TodoGroup.someday,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    sortOrder: 0,
  ),
];
