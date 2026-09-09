import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.displayName,
    this.hasCompletedOnboarding = false,
    this.hasSeenFirstEmptyHomeHint = false,
    this.hasSeenTaskEditTutorial = false,
    this.hasSeenSpaceManagementTutorial = false,
    this.hapticsEnabled = true,
    this.morningReminderMinutes = 9 * 60,
    this.isSupporter = false,
    this.supporterDebugOnly = false,
    this.supportDate,
    this.membershipShapeIndex,
    this.membershipGradientIndex,
    this.membershipVersion = 1,
    this.language = 'system',
  });

  final String? displayName;
  final bool hasCompletedOnboarding;
  final bool hasSeenFirstEmptyHomeHint;
  final bool hasSeenTaskEditTutorial;
  final bool hasSeenSpaceManagementTutorial;
  final bool hapticsEnabled;
  final int morningReminderMinutes;
  final bool isSupporter;
  final bool supporterDebugOnly;
  final DateTime? supportDate;
  final int? membershipShapeIndex;
  final int? membershipGradientIndex;
  final int membershipVersion;
  final String language;

  String? get initial {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.characters.first.toUpperCase();
  }

  AppSettings copyWith({
    String? displayName,
    bool clearDisplayName = false,
    bool? hasCompletedOnboarding,
    bool? hasSeenFirstEmptyHomeHint,
    bool? hasSeenTaskEditTutorial,
    bool? hasSeenSpaceManagementTutorial,
    bool? hapticsEnabled,
    int? morningReminderMinutes,
    bool? isSupporter,
    bool? supporterDebugOnly,
    DateTime? supportDate,
    int? membershipShapeIndex,
    int? membershipGradientIndex,
    int? membershipVersion,
    String? language,
  }) => AppSettings(
    displayName: clearDisplayName ? null : displayName ?? this.displayName,
    hasCompletedOnboarding:
        hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    hasSeenFirstEmptyHomeHint:
        hasSeenFirstEmptyHomeHint ?? this.hasSeenFirstEmptyHomeHint,
    hasSeenTaskEditTutorial:
        hasSeenTaskEditTutorial ?? this.hasSeenTaskEditTutorial,
    hasSeenSpaceManagementTutorial:
        hasSeenSpaceManagementTutorial ?? this.hasSeenSpaceManagementTutorial,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    morningReminderMinutes:
        morningReminderMinutes ?? this.morningReminderMinutes,
    isSupporter: isSupporter ?? this.isSupporter,
    supporterDebugOnly: supporterDebugOnly ?? this.supporterDebugOnly,
    supportDate: supportDate ?? this.supportDate,
    membershipShapeIndex: membershipShapeIndex ?? this.membershipShapeIndex,
    membershipGradientIndex:
        membershipGradientIndex ?? this.membershipGradientIndex,
    membershipVersion: membershipVersion ?? this.membershipVersion,
    language: language ?? this.language,
  );

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'hasSeenFirstEmptyHomeHint': hasSeenFirstEmptyHomeHint,
    'hasSeenTaskEditTutorial': hasSeenTaskEditTutorial,
    'hasSeenSpaceManagementTutorial': hasSeenSpaceManagementTutorial,
    'hapticsEnabled': hapticsEnabled,
    'morningReminderMinutes': morningReminderMinutes,
    'isSupporter': isSupporter,
    'supporterDebugOnly': supporterDebugOnly,
    'supportDate': supportDate?.toIso8601String(),
    'membershipShapeIndex': membershipShapeIndex,
    'membershipGradientIndex': membershipGradientIndex,
    'membershipVersion': membershipVersion,
    'language': language,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final minutes = json['morningReminderMinutes'];
    final date = json['supportDate'];
    return AppSettings(
      displayName: json['displayName'] is String
          ? (json['displayName'] as String).trim()
          : null,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,
      hasSeenFirstEmptyHomeHint: json['hasSeenFirstEmptyHomeHint'] == true,
      hasSeenTaskEditTutorial: json['hasSeenTaskEditTutorial'] == true,
      hasSeenSpaceManagementTutorial:
          json['hasSeenSpaceManagementTutorial'] == true,
      hapticsEnabled: json['hapticsEnabled'] != false,
      morningReminderMinutes:
          minutes is int && minutes >= 0 && minutes < 24 * 60
          ? minutes
          : 9 * 60,
      isSupporter:
          json['isSupporter'] == true &&
          (kDebugMode || json['supporterDebugOnly'] != true),
      supporterDebugOnly: json['supporterDebugOnly'] == true,
      supportDate: date is String ? DateTime.tryParse(date) : null,
      membershipShapeIndex: json['membershipShapeIndex'] is int
          ? json['membershipShapeIndex'] as int
          : null,
      membershipGradientIndex: json['membershipGradientIndex'] is int
          ? json['membershipGradientIndex'] as int
          : null,
      membershipVersion: json['membershipVersion'] is int
          ? json['membershipVersion'] as int
          : 1,
      language: const {'system', 'de', 'en'}.contains(json['language'])
          ? json['language'] as String
          : 'system',
    );
  }
}

abstract interface class AppSettingsStorage {
  Future<AppSettings?> loadAppSettings();
  Future<void> saveAppSettings(AppSettings settings);
}

class MemoryAppSettingsStorage implements AppSettingsStorage {
  AppSettings? value;

  @override
  Future<AppSettings?> loadAppSettings() async => value;

  @override
  Future<void> saveAppSettings(AppSettings settings) async => value = settings;
}
