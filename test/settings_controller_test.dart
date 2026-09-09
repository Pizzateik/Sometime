import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/state/settings_controller.dart';

void main() {
  test('The display name uses a trimmed Unicode grapheme as its initial', () {
    expect(const AppSettings(displayName: '  Émile').initial, 'É');
    expect(const AppSettings(displayName: '  marie').initial, 'M');
    expect(const AppSettings(displayName: ' 👩🏽‍💻 Alex').initial, '👩🏽‍💻');
    expect(const AppSettings(displayName: '   ').initial, isNull);
  });

  test('The membership style is generated once and stays saved', () async {
    final storage = MemoryAppSettingsStorage();
    final controller = SettingsController(
      storage: storage,
      promptForDisplayName: false,
      random: Random(8),
    );
    await controller.initialize();
    await controller.grantSupporter(
      shapeCount: 3,
      gradientCount: 16,
      date: DateTime(2026, 9, 6),
    );
    final firstShape = controller.value.membershipShapeIndex;
    final firstGradient = controller.value.membershipGradientIndex;

    await controller.grantSupporter(
      shapeCount: 3,
      gradientCount: 16,
      date: DateTime(2030),
    );
    expect(controller.value.membershipShapeIndex, firstShape);
    expect(controller.value.membershipGradientIndex, firstGradient);
    expect(controller.value.supportDate, DateTime(2026, 9, 6));

    final restarted = SettingsController(
      storage: storage,
      promptForDisplayName: false,
    );
    await restarted.initialize();
    expect(restarted.value.membershipShapeIndex, firstShape);
    expect(restarted.value.membershipGradientIndex, firstGradient);
  });

  test('Invalid saved reminder times migrate to the morning default', () {
    final settings = AppSettings.fromJson({
      'morningReminderMinutes': 24 * 60,
      'hapticsEnabled': true,
    });
    expect(settings.morningReminderMinutes, 9 * 60);
    expect(settings.hapticsEnabled, isTrue);
  });

  test(
    'The language selection persists and invalid values use system',
    () async {
      final storage = MemoryAppSettingsStorage();
      final controller = SettingsController(
        storage: storage,
        promptForDisplayName: false,
      );
      await controller.initialize();
      await controller.setLanguage('en');

      final restarted = SettingsController(
        storage: storage,
        promptForDisplayName: false,
      );
      await restarted.initialize();
      expect(restarted.value.language, 'en');
      expect(AppSettings.fromJson({'language': 'fr'}).language, 'system');
    },
  );

  test('The first-task tutorial flag persists and defaults to false', () async {
    final storage = MemoryAppSettingsStorage();
    final controller = SettingsController(
      storage: storage,
      promptForDisplayName: false,
    );
    await controller.initialize();

    expect(controller.value.hasSeenTaskEditTutorial, isFalse);
    await controller.markTaskEditTutorialSeen();

    expect(controller.value.hasSeenTaskEditTutorial, isTrue);
    expect(controller.value.toJson()['hasSeenTaskEditTutorial'], isTrue);
    expect(
      AppSettings.fromJson({'hasSeenTaskEditTutorial': true})
          .hasSeenTaskEditTutorial,
      isTrue,
    );
    final restarted = SettingsController(
      storage: storage,
      promptForDisplayName: false,
    );
    await restarted.initialize();
    expect(restarted.value.hasSeenTaskEditTutorial, isTrue);
  });
}
