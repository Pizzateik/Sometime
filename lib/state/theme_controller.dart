import 'package:flutter/material.dart';

import '../models/theme_preference.dart';
import '../models/todo_storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({required this.storage});

  final ThemePreferenceStorage storage;

  AppearanceMode _mode = AppearanceMode.system;
  AppearanceStyle _style = AppearanceStyle.soft;
  Color seedColor = const Color(0xFFFF5C5C);
  MaterialColorSource _colorSource = MaterialColorSource.system;
  bool dynamicColorsAvailable = false;
  ColorScheme? dynamicLight;
  ColorScheme? dynamicDark;
  bool _saveFailed = false;
  bool _disposed = false;
  int _saveRevision = 0;

  AppearanceMode get mode => _mode;
  AppearanceStyle get style => _style;
  MaterialColorSource get colorSource => _colorSource;
  bool get useSystemColors =>
      _colorSource == MaterialColorSource.system && dynamicColorsAvailable;
  ThemePreference get preference => switch ((_mode, _style)) {
    (AppearanceMode.system, _) => ThemePreference.system,
    (AppearanceMode.light, AppearanceStyle.normal) => ThemePreference.pureWhite,
    (AppearanceMode.light, _) => ThemePreference.offWhite,
    (AppearanceMode.dark, _) => ThemePreference.oledBlack,
  };
  bool get saveFailed => _saveFailed;

  ThemeMode get themeMode => switch (_mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };

  Future<void> initialize() async {
    try {
      final appearance = await storage.loadAppearancePreference();
      if (_disposed) return;
      if (appearance != null) {
        _mode = appearance.mode;
        _style = appearance.style;
        seedColor = Color(appearance.seedColor);
        _colorSource = appearance.colorSource;
      } else {
        final saved = await storage.loadThemePreference();
        if (_disposed || saved == null) return;
        final migrated = switch (saved) {
          ThemePreference.system => (
            AppearanceMode.system,
            AppearanceStyle.soft,
          ),
          ThemePreference.offWhite => (
            AppearanceMode.light,
            AppearanceStyle.soft,
          ),
          ThemePreference.pureWhite => (
            AppearanceMode.light,
            AppearanceStyle.normal,
          ),
          ThemePreference.oledBlack => (
            AppearanceMode.dark,
            AppearanceStyle.normal,
          ),
        };
        _mode = migrated.$1;
        _style = migrated.$2;
      }
      notifyListeners();
    } catch (_) {
      // Keep the safe system default when the saved value is not valid.
    }
  }

  Future<void> setPreference(ThemePreference value) async {
    final next = switch (value) {
      ThemePreference.system => (AppearanceMode.system, _style),
      ThemePreference.offWhite => (AppearanceMode.light, AppearanceStyle.soft),
      ThemePreference.pureWhite => (
        AppearanceMode.light,
        AppearanceStyle.normal,
      ),
      ThemePreference.oledBlack => (
        AppearanceMode.dark,
        AppearanceStyle.normal,
      ),
    };
    if ((_mode, _style) == next && !_saveFailed) return;
    _mode = next.$1;
    _style = next.$2;
    _saveFailed = false;
    _notify();
    await _save();
  }

  Future<void> setMode(AppearanceMode value) async {
    if (_mode == value && !_saveFailed) return;
    _mode = value;
    _saveFailed = false;
    _notify();
    await _save();
  }

  Future<void> setStyle(AppearanceStyle value) async {
    if (_style == value && !_saveFailed) return;
    _style = value;
    _saveFailed = false;
    _notify();
    await _save();
  }

  Future<void> setSeedColor(Color value) async {
    if (seedColor.toARGB32() == value.toARGB32() && !_saveFailed) return;
    seedColor = value.withValues(alpha: 1);
    _notify();
    await _save();
  }

  Future<void> setColorSource(MaterialColorSource value) async {
    if (_colorSource == value && !_saveFailed) return;
    _colorSource = value;
    _saveFailed = false;
    _notify();
    await _save();
  }

  Future<void> retrySave() => _save();

  Future<void> reset() async {
    _mode = AppearanceMode.system;
    _style = AppearanceStyle.soft;
    seedColor = const Color(0xFFFF5C5C);
    _colorSource = MaterialColorSource.system;
    _notify();
    await _save();
  }

  Future<void> _save() async {
    final revision = ++_saveRevision;
    try {
      await storage.saveAppearancePreference(
        AppearancePreference(
          mode: _mode,
          style: _style,
          seedColor: seedColor.toARGB32(),
          colorSource: _colorSource,
        ),
      );
      if (_disposed || revision != _saveRevision) return;
      if (_saveFailed) {
        _saveFailed = false;
        _notify();
      }
    } catch (_) {
      if (_disposed || revision != _saveRevision) return;
      _saveFailed = true;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
