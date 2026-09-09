import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app_theme.dart';
import 'package:todo_app/app/todo_app.dart';
import 'package:todo_app/models/app_settings.dart';
import 'package:todo_app/models/theme_preference.dart';
import 'package:todo_app/widgets/pressable.dart';

import 'support/memory_todo_storage.dart';

class _OnboardingStorage extends MemoryTodoStorage
    implements AppSettingsStorage {
  _OnboardingStorage() : super(useSampleData: false);

  AppSettings? appSettings;

  @override
  Future<AppSettings?> loadAppSettings() async => appSettings;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    appSettings = settings;
  }
}

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is Pressable && widget.label == label,
);

Future<void> _start(
  WidgetTester tester,
  _OnboardingStorage storage, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.platformDispatcher.clearLocalesTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.view.reset();
  });
  await tester.pumpWidget(
    TodoApp(
      storage: storage,
      themeStorage: storage,
      clock: () => DateTime(2026, 9, 7),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Continue saves the name and onboarding completion', (
    tester,
  ) async {
    final storage = _OnboardingStorage();
    await _start(tester, storage);

    expect(find.text('Welcome to Sometime'), findsOneWidget);
    expect(tester.widget<Pressable>(_button('Continue')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'EIK');
    await tester.pump();
    expect(tester.widget<Pressable>(_button('Continue')).onPressed, isNotNull);
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    expect(storage.appSettings?.displayName, 'Eik');
    expect(storage.appSettings?.initial, 'E');
    expect(storage.appSettings?.hasCompletedOnboarding, isTrue);
    expect(storage.appSettings?.hasSeenFirstEmptyHomeHint, isFalse);
    expect(find.byKey(const ValueKey('main-space-pager')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _start(tester, storage);
    expect(find.text('Welcome to Sometime'), findsNothing);
    expect(find.byKey(const ValueKey('main-space-pager')), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);
    expect(storage.appSettings?.hasSeenFirstEmptyHomeHint, isTrue);
  });

  testWidgets('Skip persists an empty name in the dark Soft default', (
    tester,
  ) async {
    final storage = _OnboardingStorage();
    await _start(
      tester,
      storage,
      locale: const Locale('de'),
      brightness: Brightness.dark,
    );

    expect(find.text('Willkommen bei Sometime'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(TextField))).brightness,
      Brightness.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(TextField))).scaffoldBackgroundColor,
      AppBackgrounds.softDark,
    );
    await tester.tap(_button('Überspringen'));
    await tester.pumpAndSettle();

    expect(storage.appSettings?.displayName, isNull);
    expect(storage.appSettings?.hasCompletedOnboarding, isTrue);
    expect(find.text('Noch nichts hier'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-space-pager')), findsOneWidget);
  });

  testWidgets('Creating the first task hides the empty home hint permanently', (
    tester,
  ) async {
    final storage = _OnboardingStorage();
    await _start(tester, storage);
    await tester.tap(_button('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tester.tap(_button('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'First task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(_button('Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet'), findsNothing);
    expect(storage.appSettings?.hasSeenFirstEmptyHomeHint, isTrue);
    expect(storage.todos, hasLength(1));
  });

  testWidgets('Leaving the empty home for Settings consumes the hint', (
    tester,
  ) async {
    final storage = _OnboardingStorage();
    await _start(tester, storage);
    await tester.tap(_button('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(-390, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(storage.appSettings?.hasSeenFirstEmptyHomeHint, isTrue);

    await tester.drag(
      find.byKey(const ValueKey('main-space-pager')),
      const Offset(390, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsNothing);
  });

  testWidgets('Material You uses the semantic secondary hint color', (
    tester,
  ) async {
    final storage = _OnboardingStorage()
      ..appearancePreference = const AppearancePreference(
        mode: AppearanceMode.light,
        style: AppearanceStyle.materialYou,
      );
    await _start(tester, storage);
    await tester.tap(_button('Skip'));
    await tester.pumpAndSettle();

    final hint = tester.widget<Text>(find.text('Nothing here yet'));
    final palette = Theme.of(tester.element(find.text('Nothing here yet')))
        .extension<AppPalette>()!;
    expect(hint.style?.color, palette.secondary);
  });

  testWidgets('The empty home hint fits small and large screens', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(840, 1180)]) {
      final storage = _OnboardingStorage();
      await _start(tester, storage, size: size);
      await tester.tap(_button('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
