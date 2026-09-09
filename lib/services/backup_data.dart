import 'dart:convert';

import '../models/app_settings.dart';
import '../models/theme_preference.dart';
import '../models/todo_space.dart';
import '../models/todo_storage.dart';

class BackupData {
  const BackupData(this.snapshot, this.settings, this.appearance);

  static const maxBytes = 10 * 1024 * 1024;
  final TodoSnapshot snapshot;
  final AppSettings settings;
  final AppearancePreference appearance;

  String encode({DateTime? now}) {
    final preferences = settings.toJson()
      ..remove('isSupporter')
      ..remove('supporterDebugOnly')
      ..remove('supportDate');
    return jsonEncode({
      'format': 'sometime-backup',
      'version': 1,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'spaces': snapshot.spaces
          .map((s) => {'id': s.id, 'name': s.name})
          .toList(),
      'tasks': [
        for (final s in snapshot.spaces)
          for (final t in s.todos) {...t.toJson(), 'spaceId': s.id},
      ],
      'archive': snapshot.archive.map((e) => e.toJson()).toList(),
      'lastKnownLocalDate': snapshot.lastKnownLocalDate.toIso8601String(),
      'preferences': {
        ...preferences,
        'appearance': {
          'mode': appearance.mode.name,
          'style': appearance.style.name,
          'seedColor': appearance.seedColor,
          'colorSource': appearance.colorSource.name,
        },
      },
    });
  }

  static BackupData decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('The backup is too large.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value['format'] != 'sometime-backup' ||
        value['version'] != 1) {
      throw const FormatException('The backup format is not supported.');
    }
    final spaces = value['spaces'];
    final tasks = value['tasks'];
    if (spaces is! List ||
        spaces.isEmpty ||
        spaces.length > 4 ||
        tasks is! List ||
        tasks.length > 20000) {
      throw const FormatException('The backup task list is not valid.');
    }
    final ids = <String>{};
    for (final space in spaces) {
      if (space is! Map<String, dynamic> ||
          space['id'] is! String ||
          !ids.add(space['id'] as String)) {
        throw const FormatException('The backup space is not valid.');
      }
    }
    for (final task in tasks) {
      if (task is! Map<String, dynamic> || !ids.contains(task['spaceId'])) {
        throw const FormatException('The backup task space is not valid.');
      }
    }
    final snapshot = LocalTodoStorage.decode(
      jsonEncode({
        'version': 2,
        'spaces': [
          for (final s in spaces)
            {
              ...s as Map<String, dynamic>,
              'todos': tasks.where((t) => t['spaceId'] == s['id']).toList(),
            },
        ],
        'archive': value['archive'] ?? [],
        'lastKnownLocalDate':
            value['lastKnownLocalDate'] ??
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ).toIso8601String(),
      }),
    );
    final prefs = value['preferences'] ?? <String, dynamic>{};
    if (prefs is! Map<String, dynamic>) {
      throw const FormatException('The backup preferences are not valid.');
    }
    final a = prefs['appearance'] ?? <String, dynamic>{};
    if (a is! Map<String, dynamic>) {
      throw const FormatException('The backup appearance is not valid.');
    }
    final mode = AppearanceMode.values
        .where((v) => v.name == (a['mode'] ?? 'system'))
        .firstOrNull;
    final style = AppearanceStyle.values
        .where((v) => v.name == (a['style'] ?? 'soft'))
        .firstOrNull;
    final seed = a['seedColor'] ?? 0xFFFF5C5C;
    final colorSource = MaterialColorSource.values
        .where((value) => value.name == (a['colorSource'] ?? 'system'))
        .firstOrNull;
    if (mode == null ||
        style == null ||
        colorSource == null ||
        seed is! int ||
        seed < 0 ||
        seed > 0xFFFFFFFF) {
      throw const FormatException('The backup appearance is not valid.');
    }
    return BackupData(
      snapshot,
      AppSettings.fromJson({
        ...prefs,
        'isSupporter': false,
        'supporterDebugOnly': false,
        'supportDate': null,
      }),
      AppearancePreference(
        mode: mode,
        style: style,
        seedColor: seed,
        colorSource: colorSource,
      ),
    );
  }
}
