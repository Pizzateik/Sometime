import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/app_haptics.dart';

bool _isAlphabetic(String value) => value.toUpperCase() != value.toLowerCase();

String _normalizeAllUppercaseName(String value) {
  final characters = value.characters.toList(growable: false);
  var hasLetter = false;
  var allLettersUppercase = true;
  for (final character in characters) {
    if (!_isAlphabetic(character)) continue;
    hasLetter = true;
    if (character != character.toUpperCase()) {
      allLettersUppercase = false;
      break;
    }
  }
  if (!hasLetter || !allLettersUppercase) return value;

  var firstLetter = true;
  return characters.map((character) {
    if (!_isAlphabetic(character)) return character;
    if (firstLetter) {
      firstLetter = false;
      return character.toUpperCase();
    }
    return character.toLowerCase();
  }).join();
}

class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.storage,
    this.promptForDisplayName = true,
    Random? random,
  }) : _random = random ?? Random.secure();

  final AppSettingsStorage storage;
  final bool promptForDisplayName;
  final Random _random;
  AppSettings _value = const AppSettings();
  bool _ready = false;
  bool saveFailed = false;
  int _saveRevision = 0;

  Future<void> retrySave() => _save();
  bool _disposed = false;

  AppSettings get value => _value;
  bool get ready => _ready;
  bool get shouldShowOnboarding =>
      promptForDisplayName && _ready && !_value.hasCompletedOnboarding;

  Future<void> initialize() async {
    try {
      _value = await storage.loadAppSettings() ?? const AppSettings();
    } catch (_) {
      _value = const AppSettings();
    }
    AppHaptics.enabled = _value.hapticsEnabled;
    _ready = true;
    _notify();
  }

  Future<void> setDisplayName(String? name) async {
    _value = _withDisplayName(_value, name);
    await _save();
  }

  Future<void> completeOnboarding(String? name) async {
    _value = _withDisplayName(
      _value,
      name,
    ).copyWith(hasCompletedOnboarding: true);
    await _save();
  }

  Future<void> markFirstEmptyHomeHintSeen() async {
    if (_value.hasSeenFirstEmptyHomeHint) return;
    _value = _value.copyWith(hasSeenFirstEmptyHomeHint: true);
    await _save();
  }

  Future<void> markTaskEditTutorialSeen() async {
    if (_value.hasSeenTaskEditTutorial) return;
    _value = _value.copyWith(hasSeenTaskEditTutorial: true);
    await _save();
  }

  Future<void> markSpaceManagementTutorialSeen() async {
    if (_value.hasSeenSpaceManagementTutorial) return;
    _value = _value.copyWith(hasSeenSpaceManagementTutorial: true);
    await _save();
  }

  AppSettings _withDisplayName(AppSettings settings, String? name) {
    final trimmed = name?.trim();
    final limited = trimmed?.characters.take(10).toString();
    final normalized = limited == null
        ? null
        : _normalizeAllUppercaseName(limited);
    return settings.copyWith(
      displayName: normalized == null || normalized.isEmpty ? null : normalized,
      clearDisplayName: normalized == null || normalized.isEmpty,
    );
  }

  Future<void> skipDisplayName() => setDisplayName(null);

  Future<void> setHaptics(bool enabled) async {
    _value = _value.copyWith(hapticsEnabled: enabled);
    AppHaptics.enabled = enabled;
    await _save();
  }

  Future<void> setMorningReminderMinutes(int minutes) async {
    _value = _value.copyWith(morningReminderMinutes: minutes);
    await _save();
  }

  Future<void> setLanguage(String language) async {
    if (!const {
      'system',
      'de',
      'en',
      'es',
      'pt-BR',
      'fr',
      'ja',
    }.contains(language)) {
      return;
    }
    _value = _value.copyWith(language: language);
    await _save();
  }

  Future<void> debugSetSupporter(
    bool enabled, {
    required int shapeCount,
    required int gradientCount,
  }) async {
    if (!kDebugMode) return;
    if (enabled) {
      await grantSupporter(
        debugOnly: true,
        shapeCount: shapeCount,
        gradientCount: gradientCount,
      );
      return;
    }
    _value = AppSettings(
      displayName: _value.displayName,
      hasCompletedOnboarding: _value.hasCompletedOnboarding,
      hasSeenFirstEmptyHomeHint: _value.hasSeenFirstEmptyHomeHint,
      hasSeenTaskEditTutorial: _value.hasSeenTaskEditTutorial,
      hasSeenSpaceManagementTutorial: _value.hasSeenSpaceManagementTutorial,
      hapticsEnabled: _value.hapticsEnabled,
      morningReminderMinutes: _value.morningReminderMinutes,
      language: _value.language,
    );
    await _save();
  }

  Future<bool> rerollMembership({
    required int shapeCount,
    required int gradientCount,
  }) async {
    if (!_value.isSupporter || shapeCount < 1 || gradientCount < 1) {
      return false;
    }
    final oldShape = _value.membershipShapeIndex;
    final oldGradient = _value.membershipGradientIndex;
    var shape = _random.nextInt(shapeCount);
    var gradient = _random.nextInt(gradientCount);
    if (shapeCount * gradientCount > 1) {
      while (shape == oldShape && gradient == oldGradient) {
        shape = _random.nextInt(shapeCount);
        gradient = _random.nextInt(gradientCount);
      }
    }
    _value = _value.copyWith(
      membershipShapeIndex: shape,
      membershipGradientIndex: gradient,
    );
    await _save();
    return true;
  }

  Future<void> debugRegenerateMembership({
    required int shapeCount,
    required int gradientCount,
  }) async {
    if (!kDebugMode || !_value.isSupporter) return;
    _value = _value.copyWith(
      membershipShapeIndex: _random.nextInt(shapeCount),
      membershipGradientIndex: _random.nextInt(gradientCount),
      supportDate: DateTime.now(),
    );
    await _save();
  }

  Future<void> grantSupporter({
    required int shapeCount,
    required int gradientCount,
    DateTime? date,
    bool debugOnly = false,
  }) async {
    if (shapeCount < 1 || gradientCount < 1) return;
    final needsStyle =
        _value.membershipShapeIndex == null ||
        _value.membershipGradientIndex == null;
    _value = _value.copyWith(
      isSupporter: true,
      supporterDebugOnly: debugOnly,
      supportDate: _value.supportDate ?? date ?? DateTime.now(),
      membershipShapeIndex: needsStyle
          ? _random.nextInt(shapeCount)
          : _value.membershipShapeIndex,
      membershipGradientIndex: needsStyle
          ? _random.nextInt(gradientCount)
          : _value.membershipGradientIndex,
    );
    await _save();
  }

  Future<void> resetLocalPreferences() async {
    _value = AppSettings(
      hasCompletedOnboarding: _value.hasCompletedOnboarding,
      hasSeenFirstEmptyHomeHint: _value.hasSeenFirstEmptyHomeHint,
      hasSeenTaskEditTutorial: _value.hasSeenTaskEditTutorial,
      hasSeenSpaceManagementTutorial: _value.hasSeenSpaceManagementTutorial,
      isSupporter: _value.isSupporter,
      supporterDebugOnly: _value.supporterDebugOnly,
      supportDate: _value.supportDate,
      membershipShapeIndex: _value.membershipShapeIndex,
      membershipGradientIndex: _value.membershipGradientIndex,
    );
    AppHaptics.enabled = true;
    await _save();
  }

  Future<void> _save() async {
    _notify();
    final revision = ++_saveRevision;
    try {
      await storage.saveAppSettings(_value);
      if (_disposed || revision != _saveRevision) return;
      saveFailed = false;
    } catch (_) {
      if (_disposed || revision != _saveRevision) return;
      saveFailed = true;
    }
    _notify();
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
