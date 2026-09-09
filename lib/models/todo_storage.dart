import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'theme_preference.dart';
import 'todo.dart';
import 'todo_space.dart';

abstract interface class TodoStorage {
  Future<TodoSnapshot?> load();
  Future<void> save(TodoSnapshot snapshot);
}

abstract interface class ThemePreferenceStorage {
  Future<ThemePreference?> loadThemePreference();
  Future<void> saveThemePreference(ThemePreference preference);
  Future<AppearancePreference?> loadAppearancePreference();
  Future<void> saveAppearancePreference(AppearancePreference preference);
}

class LocalTodoStorage
    implements TodoStorage, ThemePreferenceStorage, AppSettingsStorage {
  LocalTodoStorage({
    this.key = 'todos.v1',
    this.themeKey = 'theme-preference.v1',
    this.appearanceModeKey = 'appearance-mode.v1',
    this.appearanceStyleKey = 'appearance-style.v1',
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final String key;
  final String themeKey;
  final String appearanceModeKey;
  final String appearanceStyleKey;
  final SharedPreferencesAsync _preferences;
  static const _bundleKey = 'sometime.local-bundle.v1';
  Future<void> _bundleWrite = Future<void>.value();

  Future<Map<String, dynamic>?> _bundle() async {
    await _bundleWrite;
    final raw = await _preferences.getString(_bundleKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _updateBundle(Map<String, Object?> values) {
    final next = _bundleWrite.then((_) async {
      final raw = await _preferences.getString(_bundleKey);
      final old = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      await _preferences.setString(_bundleKey, jsonEncode({...old, ...values}));
    });
    _bundleWrite = next.catchError((Object _) {});
    return next;
  }

  Future<void> replaceLocalData(
    TodoSnapshot snapshot,
    AppSettings settings,
    AppearancePreference appearance,
  ) async {
    await Future.wait([_pendingTodoWrite, _pendingThemeWrite]);
    await _updateBundle({
      'todos': encode(snapshot),
      'settings': settings.toJson(),
      'appearance': {
        'mode': appearance.mode.name,
        'style': appearance.style.name,
        'seedColor': appearance.seedColor,
        'colorSource': appearance.colorSource.name,
      },
    });
  }

  Future<void> _pendingTodoWrite = Future<void>.value();
  Future<void> _pendingThemeWrite = Future<void>.value();

  @override
  Future<TodoSnapshot?> load() async {
    await _pendingTodoWrite;
    final json =
        (await _bundle())?['todos'] as String? ??
        await _preferences.getString(key);
    return json == null ? null : decode(json);
  }

  @override
  Future<void> save(TodoSnapshot snapshot) {
    final json = encode(snapshot);
    final write = _pendingTodoWrite.then((_) => _updateBundle({'todos': json}));
    _pendingTodoWrite = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<ThemePreference?> loadThemePreference() async {
    await _pendingThemeWrite;
    final value = await _preferences.getString(themeKey);
    if (value == null) return null;
    for (final preference in ThemePreference.values) {
      if (preference.name == value) return preference;
    }
    throw const FormatException('The saved theme preference is not valid.');
  }

  @override
  Future<void> saveThemePreference(ThemePreference preference) {
    final write = _pendingThemeWrite.then(
      (_) => _preferences.setString(themeKey, preference.name),
    );
    _pendingThemeWrite = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<AppearancePreference?> loadAppearancePreference() async {
    await _pendingThemeWrite;
    final bundled = (await _bundle())?['appearance'];
    if (bundled is Map) {
      return AppearancePreference(
        mode: AppearanceMode.values.byName(bundled['mode'] as String),
        style: AppearanceStyle.values.byName(bundled['style'] as String),
        seedColor: bundled['seedColor'] as int,
        colorSource:
            MaterialColorSource.values
                .where((value) => value.name == bundled['colorSource'])
                .firstOrNull ??
            MaterialColorSource.system,
      );
    }
    final modeValue = await _preferences.getString(appearanceModeKey);
    final styleValue = await _preferences.getString(appearanceStyleKey);
    if (modeValue == null || styleValue == null) return null;
    final mode = AppearanceMode.values.where(
      (value) => value.name == modeValue,
    );
    final style = AppearanceStyle.values.where(
      (value) => value.name == styleValue,
    );
    if (mode.isEmpty || style.isEmpty) {
      throw const FormatException('The saved appearance setting is not valid.');
    }
    return AppearancePreference(
      mode: mode.single,
      style: style.single,
      seedColor:
          await _preferences.getInt('material-you-seed.v1') ?? 0xFFFF5C5C,
      colorSource: MaterialColorSource.system,
    );
  }

  @override
  Future<void> saveAppearancePreference(AppearancePreference preference) {
    final write = _pendingThemeWrite.then((_) async {
      await _updateBundle({
        'appearance': {
          'mode': preference.mode.name,
          'style': preference.style.name,
          'seedColor': preference.seedColor,
          'colorSource': preference.colorSource.name,
        },
      });
    });
    _pendingThemeWrite = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<AppSettings?> loadAppSettings() async {
    final bundled = (await _bundle())?['settings'];
    if (bundled is Map<String, dynamic>) return AppSettings.fromJson(bundled);
    final source = await _preferences.getString('app-settings.v1');
    if (source == null) return null;
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The saved app settings are not valid.');
    }
    return AppSettings.fromJson(value);
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) =>
      _updateBundle({'settings': settings.toJson()});

  static String encode(TodoSnapshot snapshot) => jsonEncode({
    'version': 2,
    'spaces': snapshot.spaces.map((space) => space.toJson()).toList(),
    'archive': snapshot.archive.map((entry) => entry.toJson()).toList(),
    'lastKnownLocalDate': snapshot.lastKnownLocalDate.toIso8601String(),
  });

  static TodoSnapshot decode(String source, {DateTime? migrationTime}) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('The saved task state is not valid.');
    }
    return switch (json['version']) {
      1 => _decodeVersionOne(json, migrationTime ?? DateTime.now()),
      2 => _decodeVersionTwo(json),
      _ => throw const FormatException(
        'The saved task state version is not valid.',
      ),
    };
  }

  static TodoSnapshot _decodeVersionOne(
    Map<String, dynamic> json,
    DateTime migrationTime,
  ) {
    final entries = json['todos'];
    if (entries is! List) {
      throw const FormatException('The saved task list is not valid.');
    }
    final ids = <String>{};
    final todos = entries
        .map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('The saved task is not valid.');
          }
          final todo = Todo.fromVersionOneJson(entry, migrationTime);
          if (!ids.add(todo.id)) {
            throw const FormatException(
              'The saved task ID occurs more than once.',
            );
          }
          return todo;
        })
        .toList(growable: false);
    return TodoSnapshot(
      spaces: [
        TodoSpace(id: TodoSpace.defaultId, name: 'Sometime', todos: todos),
      ],
      archive: const [],
      lastKnownLocalDate: localCalendarDate(migrationTime),
    );
  }

  static TodoSnapshot _decodeVersionTwo(Map<String, dynamic> json) {
    final spaceEntries = json['spaces'];
    final archiveEntries = json['archive'];
    final dateValue = json['lastKnownLocalDate'];
    final date = dateValue is String ? DateTime.tryParse(dateValue) : null;
    if (spaceEntries is! List ||
        spaceEntries.isEmpty ||
        archiveEntries is! List ||
        date == null ||
        date != localCalendarDate(date)) {
      throw const FormatException('The saved task state is not valid.');
    }

    final spaceIds = <String>{};
    final todoIds = <String>{};
    final spaces = spaceEntries
        .map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('The saved todo space is not valid.');
          }
          final space = TodoSpace.fromJson(entry);
          if (!spaceIds.add(space.id)) {
            throw const FormatException('The space ID occurs more than once.');
          }
          for (final todo in space.todos) {
            if (!todoIds.add(todo.id)) {
              throw const FormatException('The task ID occurs more than once.');
            }
          }
          return space;
        })
        .toList(growable: false);

    final archive = archiveEntries
        .map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'The saved archive entry is not valid.',
            );
          }
          final archived = ArchivedTodo.fromJson(entry);
          if (!spaceIds.contains(archived.spaceId) ||
              !archived.todo.isComplete ||
              !todoIds.add(archived.todo.id)) {
            throw const FormatException('The archived task is not valid.');
          }
          return archived;
        })
        .toList(growable: false);

    return TodoSnapshot(
      spaces: List.unmodifiable(spaces),
      archive: List.unmodifiable(archive),
      lastKnownLocalDate: date,
    );
  }
}
