import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../models/todo.dart';
import '../models/theme_preference.dart';
import '../state/todo_controller.dart';
import '../state/settings_controller.dart';
import '../state/theme_controller.dart';

Map<String, Object?> widgetSnapshot(
  TodoController todos,
  String language,
  String mode,
) => {
  'version': 1,
  'language': language,
  'mode': mode,
  'spaces': [
    for (final space in todos.spaces)
      {
        'id': space.id,
        'name': space.name,
        'tasks': [
          for (final group in TodoGroup.values)
            for (final task in todos.widgetTodos(space.id, group))
              if (!task.isComplete)
                {
                  'id': task.id,
                  'title': task.title,
                  'description': task.details.description.trim(),
                  'category': group.name,
                  'available': task.availableFrom?.millisecondsSinceEpoch,
                  'availableDate': task.availableFrom == null
                      ? null
                      : [
                          task.availableFrom!.year,
                          task.availableFrom!.month,
                          task.availableFrom!.day,
                        ],
                  'minutes': task.details.minutes,
                },
        ],
      },
  ],
};

class WidgetBridge {
  WidgetBridge(this.todos, this.settings, this.theme);
  static const channel = MethodChannel('sometime/widgets');
  static final target =
      ValueNotifier<
        ({String space, String? task, String? category, bool create})?
      >(null);
  final TodoController todos;
  final SettingsController settings;
  final ThemeController theme;
  bool _dirty = false, _running = false, _disposed = false;
  String? _last;
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  void start() {
    if (!supported) return;
    todos.addListener(refresh);
    settings.addListener(refresh);
    theme.addListener(refresh);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open') await resume();
    });
    refresh();
    unawaited(resume());
  }

  Future<void> resume() async {
    if (!supported || _disposed) return;
    try {
      final value = await channel.invokeMapMethod<String, dynamic>('launch');
      if (!_disposed && value != null && value['space'] is String) {
        target.value = (
          space: value['space'] as String,
          task: value['task'] as String?,
          category: value['category'] as String?,
          create: value['create'] == true,
        );
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
    refresh();
  }

  void refresh() {
    if (_disposed || !supported || !todos.isReady) return;
    _dirty = true;
    if (!_running) unawaited(_sync());
  }

  Future<void> _sync() async {
    _running = true;
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        final language = settings.value.language == 'system'
            ? PlatformDispatcher.instance.locale.toLanguageTag()
            : settings.value.language;
        final snapshot = jsonEncode({
          ...widgetSnapshot(todos, language, theme.mode.name),
          'languageMode': settings.value.language,
          'style': theme.style.name,
          'colorSource': theme.colorSource.name,
          'theme': {
            'light': _widgetColors(Brightness.light),
            'dark': _widgetColors(Brightness.dark),
          },
        });
        if (_last == snapshot) continue;
        await channel.invokeMethod<void>('sync', snapshot);
        _last = snapshot;
      }
    } on MissingPluginException {
      _last = null;
    } on PlatformException {
      _last = null;
    } on StateError {
      _last = null;
    } finally {
      _running = false;
    }
  }

  Map<String, int> _widgetColors(Brightness brightness) {
    final materialYou = theme.style == AppearanceStyle.materialYou;
    final systemScheme = brightness == Brightness.dark
        ? theme.dynamicDark
        : theme.dynamicLight;
    final scheme = materialYou
        ? (theme.useSystemColors ? systemScheme : null) ??
              sometimeColorScheme(brightness, seed: theme.seedColor)
        : null;
    final background = brightness == Brightness.dark
        ? (theme.style == AppearanceStyle.normal
              ? AppBackgrounds.oledBlack
              : AppBackgrounds.softDark)
        : (theme.style == AppearanceStyle.normal
              ? AppBackgrounds.pureWhite
              : AppBackgrounds.offWhite);
    final palette = scheme == null
        ? (brightness == Brightness.dark
              ? AppPalette.dark(background)
              : AppPalette.light(background))
        : AppPalette.fromScheme(scheme);
    return {
      'background': palette.background.toARGB32(),
      'ink': palette.ink.toARGB32(),
      'text': palette.text.toARGB32(),
      'secondary': palette.secondary.toARGB32(),
      'outline': palette.outline.toARGB32(),
      'primary': (scheme?.primary ?? palette.ink).toARGB32(),
      'onPrimary': (scheme?.onPrimary ?? palette.background).toARGB32(),
      'control': (scheme?.surfaceContainerHigh ?? palette.surface).toARGB32(),
    };
  }

  void dispose() {
    _disposed = true;
    todos.removeListener(refresh);
    settings.removeListener(refresh);
    theme.removeListener(refresh);
    if (supported) channel.setMethodCallHandler(null);
  }
}
