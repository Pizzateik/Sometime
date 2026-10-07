import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppShortcut { newTask, newRoutine, someday }

class AppShortcutBridge {
  static const channel = MethodChannel('sometime/shortcuts');
  static final target = ValueNotifier<AppShortcut?>(null);
  bool _disposed = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void start() {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open') await resume();
    });
    unawaited(resume());
  }

  Future<void> resume() async {
    if (!supported || _disposed) return;
    try {
      final action = await channel.invokeMethod<String>('launch');
      if (_disposed) return;
      final shortcut = switch (action) {
        'new_task' => AppShortcut.newTask,
        'new_routine' => AppShortcut.newRoutine,
        'someday' => AppShortcut.someday,
        _ => null,
      };
      if (shortcut != null) target.value = shortcut;
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void dispose() {
    _disposed = true;
    if (supported) channel.setMethodCallHandler(null);
    target.value = null;
  }
}
