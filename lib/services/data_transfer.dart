import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/theme_preference.dart';
import '../models/todo_storage.dart';
import '../state/settings_controller.dart';
import '../state/theme_controller.dart';
import '../state/todo_controller.dart';
import 'backup_data.dart';
import 'notification_service.dart';

Future<ShareResult> shareFile(
  BuildContext context,
  Uint8List bytes,
  String name,
  String type,
) {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.attached && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: type, name: name)],
      fileNameOverrides: [name],
      sharePositionOrigin: origin,
    ),
  );
}

class DataTransfer {
  const DataTransfer(this.todos, this.settings, this.theme);
  final TodoController todos;
  final SettingsController settings;
  final ThemeController theme;

  BackupData get backup => BackupData(
    todos.snapshot,
    settings.value,
    AppearancePreference(
      mode: theme.mode,
      style: theme.style,
      seedColor: theme.seedColor.toARGB32(),
      colorSource: theme.colorSource,
    ),
  );

  Future<ShareResult> export(BuildContext context) {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return shareFile(
      context,
      Uint8List.fromList(utf8.encode(backup.encode())),
      'sometime-backup-$day.json',
      'application/json',
    );
  }

  Future<BackupData?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Sometime JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > BackupData.maxBytes) {
      throw const FormatException('The backup is too large.');
    }
    return BackupData.decode(await file.readAsString());
  }

  Future<void> import(BackupData data) async {
    final storage = todos.storage;
    if (storage is! LocalTodoStorage ||
        !identical(storage, settings.storage) ||
        !identical(storage, theme.storage)) {
      throw StateError('The local storage is not available.');
    }
    await todos.flush();
    final entitlement = settings.value;
    await storage.replaceLocalData(
      data.snapshot,
      data.settings.copyWith(
        isSupporter: entitlement.isSupporter,
        supporterDebugOnly: entitlement.supporterDebugOnly,
        supportDate: entitlement.supportDate,
      ),
      data.appearance,
    );
    await settings.initialize();
    await theme.initialize();
    await todos.initialize();
    todos.rollForwardRoutines();
    NotificationService.current?.refresh();
  }
}
