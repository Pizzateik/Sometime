import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/task_details.dart';
import '../models/todo.dart';
import '../state/settings_controller.dart';
import '../state/todo_controller.dart';
import '../utils/natural_datetime_parser.dart';

class AssistantTaskRequest {
  const AssistantTaskRequest({
    required this.id,
    required this.title,
    this.category,
    this.date,
    this.time,
  });

  final String id;
  final String title;
  final String? category;
  final String? date;
  final String? time;

  static AssistantTaskRequest? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final title = value['title'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty) {
      return null;
    }
    return AssistantTaskRequest(
      id: id,
      title: title,
      category: value['category'] is String ? value['category'] as String : null,
      date: value['date'] is String ? value['date'] as String : null,
      time: value['time'] is String ? value['time'] as String : null,
    );
  }

  TodoDraft toDraft({required DateTime now, required String languageCode}) {
    var taskTitle = title.trim();
    final categorySuffix = RegExp(
      r'\s+(?:in|to|for|under|für|zu|nach)\s+'
      r'(today|soon|sometime|heute|demnächst|irgendwann)(?=\s|$)',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    final spokenCategory = categorySuffix?.group(1);
    if (categorySuffix != null) {
      taskTitle = (
        taskTitle.substring(0, categorySuffix.start) +
        taskTitle.substring(categorySuffix.end)
      ).trim();
    }
    if (taskTitle.isEmpty) taskTitle = title.trim();
    final group = _group(category) ?? _group(spokenCategory) ?? TodoGroup.soon;
    final suggestion = NaturalDateTimeParser.parse(
      title: taskTitle,
      description: '',
      now: now,
      languageCode: languageCode,
    );
    final explicitDate = _date(date);
    final explicitMinutes = _minutes(time);
    return TodoDraft(
      title: taskTitle,
      group: group,
      details: TaskDetails(
        date: explicitDate ?? suggestion.date,
        minutes: explicitMinutes ?? suggestion.minutes,
      ),
    );
  }

  static TodoGroup? _group(String? value) => switch (value?.toLowerCase().trim()) {
    'today' || 'heute' => TodoGroup.today,
    'soon' || 'demnächst' || 'demnaechst' => TodoGroup.soon,
    'sometime' || 'someday' || 'irgendwann' => TodoGroup.someday,
    _ => null,
  };

  static DateTime? _date(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final normalized = '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
    if (normalized != value) return null;
    return parsed;
  }

  static int? _minutes(String? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value ?? '');
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }
}

class AssistantTaskBridge {
  AssistantTaskBridge(this.todos, this.settings);

  static const channel = MethodChannel('sometime/assistant');
  final TodoController todos;
  final SettingsController settings;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  static bool get supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void start() {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'newTask') await resume();
    });
    unawaited(resume());
  }

  Future<void> resume() async {
    if (!supported || _disposed || !todos.isReady) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        final pending = await channel.invokeListMethod<dynamic>('pending') ?? [];
        for (final item in pending) {
          if (_disposed) return;
          final request = AssistantTaskRequest.fromMap(item);
          if (request == null) continue;
          final language = settings.value.language == 'system'
              ? PlatformDispatcher.instance.locale.languageCode
              : settings.value.language;
          todos.addTodo(
            todos.spaces.first.id,
            request.toDraft(now: todos.clock(), languageCode: language),
            requestId: request.id,
          );
          await todos.flush();
          await channel.invokeMethod<void>('ack', request.id);
        }
      } while (_again);
    } on MissingPluginException {
      // The bridge is unavailable in tests and on unsupported host builds.
    } on PlatformException {
      // Keep unacknowledged requests for the next launch or resume.
    } on StateError {
      // Keep unacknowledged requests if task storage is unavailable.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    if (supported) channel.setMethodCallHandler(null);
  }
}
