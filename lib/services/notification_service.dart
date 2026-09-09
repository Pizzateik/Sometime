import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/task_details.dart';
import '../state/settings_controller.dart';
import '../state/todo_controller.dart';

class NotificationService extends ChangeNotifier {
  NotificationService(this.todos, this.settings);

  static const channel = MethodChannel('sometime/notifications');
  static NotificationService? current;
  final TodoController todos;
  final SettingsController settings;
  final openTask = ValueNotifier<({String spaceId, String taskId})?>(null);
  bool allowed = true;
  String? problem;
  bool _disposed = false;
  bool _dirty = false;
  bool _running = false;
  bool _started = false;
  String? _lastPlan;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start() async {
    if (!supported) return;
    current = this;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'events') {
        await todos.handleResume();
        refresh();
      }
    });
    todos.addListener(refresh);
    settings.addListener(refresh);
    _started = true;
    refresh();
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      final permission =
          await channel.invokeMethod<bool>('permission') ?? false;
      if (_disposed) return false;
      allowed = permission;
      problem = allowed
          ? null
          : 'Notifications are off. Enable them in Settings.';
      _lastPlan = null;
      refresh();
      notifyListeners();
      return allowed;
    } catch (_) {
      if (_disposed) return false;
      problem =
          'Notifications are not available. The task will still be saved.';
      notifyListeners();
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await channel.invokeMethod<void>('settings');
    } catch (_) {
      if (_disposed) return;
      problem =
          'Notifications are not available. The task will still be saved.';
      notifyListeners();
    }
  }

  void refresh() {
    if (_disposed || !_started) return;
    _dirty = true;
    if (!_running) unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    _running = true;
    try {
      while (_dirty && !_disposed && todos.isReady) {
        _dirty = false;
        final events = await channel.invokeListMethod<dynamic>('events') ?? [];
        if (_disposed) return;
        for (final raw in events) {
          final event = Map<String, dynamic>.from(raw as Map);
          final space = todos.spaces
              .where((s) => s.id == event['space'])
              .firstOrNull;
          final task = space?.todos
              .where((t) => t.id == event['task'])
              .firstOrNull;
          if (space != null && task != null) {
            switch (event['action']) {
              case 'complete':
                await todos.completeFromNotification(space.id, task.id);
              case 'unpin':
                todos.setPinned(space.id, task.id, false);
                await todos.flush();
              case 'open':
                openTask.value = (spaceId: space.id, taskId: task.id);
            }
          }
          await channel.invokeMethod<void>('ack', event['id']);
          _lastPlan = null;
        }
        todos.rollForwardRoutines();
        final specs = <Map<String, Object?>>[];
        for (final space in todos.spaces) {
          for (final task in space.todos) {
            if (task.isComplete) continue;
            final details = task.details;
            final reminder = details.reminderTime(
              settings: ReminderSettings(
                morningMinutes: settings.value.morningReminderMinutes,
              ),
            );
            if (!task.isPinned &&
                details.effectiveReminder == ReminderRule.none) {
              continue;
            }
            final date = details.date;
            specs.add({
              'id': task.id,
              'space': space.id,
              'title': task.title,
              'description': task.details.description.trim(),
              'language': settings.value.language == 'system'
                  ? PlatformDispatcher.instance.locale.toLanguageTag()
                  : settings.value.language,
              'date': date == null ? null : [date.year, date.month, date.day],
              'minutes': details.minutes,
              'reminder': details.effectiveReminder.name,
              'morningMinutes': settings.value.morningReminderMinutes,
              'at': reminder?.millisecondsSinceEpoch,
              'pinned': task.isPinned,
              'available': task.availableFrom?.millisecondsSinceEpoch,
              'availableDate': task.availableFrom == null
                  ? null
                  : [
                      task.availableFrom!.year,
                      task.availableFrom!.month,
                      task.availableFrom!.day,
                    ],
            });
          }
        }
        final plan = jsonEncode(specs);
        if (plan != _lastPlan) {
          final result = await channel.invokeMapMethod<String, dynamic>(
            'sync',
            specs,
          );
          if (_disposed) return;
          if (result?['retry'] == true) {
            _dirty = true;
          } else {
            _lastPlan = plan;
            allowed = result?['allowed'] != false;
            problem = !allowed && specs.isNotEmpty
                ? 'Notifications are off. Enable them in Settings.'
                : result?['warning'] as String?;
            notifyListeners();
          }
        }
      }
    } catch (_) {
      problem = 'Notifications could not be updated. Your task data is kept.';
      if (!_disposed) notifyListeners();
    } finally {
      _running = false;
    }
  }

  Future<void> resume() async {
    _lastPlan = null;
    refresh();
  }

  Future<void> removeSpace(String spaceId) async {
    if (!_started || _disposed || !supported) return;
    try {
      await channel.invokeMethod<void>('removeSpace', spaceId);
      _lastPlan = null;
      refresh();
    } catch (_) {
      if (_disposed) return;
      problem = 'Notifications could not be updated. Your task data is kept.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    todos.removeListener(refresh);
    settings.removeListener(refresh);
    if (current == this) current = null;
    if (_started) channel.setMethodCallHandler(null);
    openTask.dispose();
    super.dispose();
  }
}
