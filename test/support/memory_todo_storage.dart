import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/models/todo_space.dart';
import 'package:todo_app/models/todo_storage.dart';

import 'sample_todos.dart';

class MemoryTodoStorage implements TodoStorage, ThemePreferenceStorage {
  MemoryTodoStorage({
    List<Todo>? todos,
    TodoSnapshot? snapshot,
    bool useSampleData = true,
    this.themePreference,
    DateTime? localDate,
  }) : snapshot =
           snapshot ??
           (todos == null && !useSampleData
               ? null
               : TodoSnapshot(
                   spaces: [
                     TodoSpace(
                       id: TodoSpace.defaultId,
                       name: todos?.isNotEmpty == true ? 'todo' : 'Sometime',
                       todos: List.of(
                         todos ??
                             sampleTodos.map(
                               (todo) =>
                                   todo.withCreatedAt(DateTime(2026, 9, 4, 10)),
                             ),
                       ),
                     ),
                   ],
                   archive: const [],
                   lastKnownLocalDate: localDate ?? DateTime(2026, 9, 4),
                 ));

  TodoSnapshot? snapshot;
  ThemePreference? themePreference;
  AppearancePreference? appearancePreference;
  bool failLoad = false;
  bool failSave = false;
  bool failThemeLoad = false;
  bool failThemeSave = false;
  int saveCount = 0;
  int themeSaveCount = 0;

  List<Todo>? get todos => snapshot?.spaces.single.todos;

  @override
  Future<TodoSnapshot?> load() async {
    if (failLoad) throw StateError('The test storage cannot load tasks.');
    return snapshot;
  }

  @override
  Future<void> save(TodoSnapshot value) async {
    saveCount++;
    if (failSave) throw StateError('The test storage cannot save tasks.');
    snapshot = value;
  }

  @override
  Future<ThemePreference?> loadThemePreference() async {
    if (failThemeLoad) {
      throw StateError('The test storage cannot load the theme.');
    }
    return themePreference;
  }

  @override
  Future<void> saveThemePreference(ThemePreference value) async {
    themeSaveCount++;
    if (failThemeSave) {
      throw StateError('The test storage cannot save the theme.');
    }
    themePreference = value;
  }

  @override
  Future<AppearancePreference?> loadAppearancePreference() async {
    if (failThemeLoad) {
      throw StateError('The test storage cannot load the theme.');
    }
    return appearancePreference;
  }

  @override
  Future<void> saveAppearancePreference(AppearancePreference value) async {
    themeSaveCount++;
    if (failThemeSave) {
      throw StateError('The test storage cannot save the theme.');
    }
    appearancePreference = value;
    themePreference = switch ((value.mode, value.style)) {
      (AppearanceMode.system, _) => ThemePreference.system,
      (AppearanceMode.light, AppearanceStyle.normal) =>
        ThemePreference.pureWhite,
      (AppearanceMode.light, _) => ThemePreference.offWhite,
      (AppearanceMode.dark, _) => ThemePreference.oledBlack,
    };
  }
}
