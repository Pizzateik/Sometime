import 'package:flutter/widgets.dart';

import 'app/todo_app.dart';
import 'models/todo_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalTodoStorage();
  runApp(
    TodoApp(storage: storage, themeStorage: storage, enableNotifications: true),
  );
}
