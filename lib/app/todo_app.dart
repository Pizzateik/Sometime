import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../models/theme_preference.dart';
import '../models/app_settings.dart';
import '../membership/membership_assets.dart';
import '../services/app_haptics.dart';
import '../services/notification_service.dart';
import '../services/widget_bridge.dart';
import '../services/support_purchase_service.dart';
import '../models/todo_storage.dart';
import '../screens/main_pager_screen.dart';
import '../screens/onboarding_screen.dart';
import '../state/theme_controller.dart';
import '../state/settings_controller.dart';
import '../state/todo_controller.dart';
import 'app_config.dart';
import 'app_strings.dart';
import 'app_theme.dart';

DateTime systemClock() => DateTime.now();

class TodoApp extends StatefulWidget {
  const TodoApp({
    required this.storage,
    required this.themeStorage,
    this.clock = systemClock,
    this.enableNotifications = false,
    this.enableSupporterPurchases = AppConfig.enableSupporterPurchases,
    this.purchaseService,
    super.key,
  });

  final TodoStorage storage;
  final ThemePreferenceStorage themeStorage;
  final AppClock clock;
  final bool enableNotifications;
  final bool enableSupporterPurchases;
  final SupportPurchaseService? purchaseService;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> with WidgetsBindingObserver {
  static bool _fontLicenseRegistered = false;
  late final TodoController _todos;
  late final ThemeController _theme;
  late final SettingsController _settings;
  late final SupportPurchaseService _purchases;
  bool _animateFirstHomeEntrance = false;
  NotificationService? _notifications;
  WidgetBridge? _widgets;

  @override
  void initState() {
    super.initState();
    if (!_fontLicenseRegistered) {
      _fontLicenseRegistered = true;
      LicenseRegistry.addLicense(() async* {
        final license = await rootBundle.loadString(
          'assets/fonts/OFL-Geist.txt',
        );
        yield LicenseEntryWithLineBreaks(['Geist'], license);
        yield LicenseEntryWithLineBreaks([
          'Parisienne',
        ], await rootBundle.loadString('assets/fonts/OFL-Parisienne.txt'));
      });
    }
    _todos = TodoController(storage: widget.storage, clock: widget.clock);
    _theme = ThemeController(storage: widget.themeStorage);
    final localSettings = widget.themeStorage is AppSettingsStorage;
    _settings = SettingsController(
      storage: localSettings
          ? widget.themeStorage as AppSettingsStorage
          : MemoryAppSettingsStorage(),
      promptForDisplayName: localSettings,
    );
    _purchases =
        widget.purchaseService ??
        SupportPurchaseService(enabled: widget.enableSupporterPurchases);
    _purchases.onEntitlementConfirmed = () {
      AppHaptics.medium();
      unawaited(
        _settings.grantSupporter(
          shapeCount: MembershipAssets.shapes.length,
          gradientCount: MembershipAssets.gradients.length,
        ),
      );
    };
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
    unawaited(_theme.initialize());
  }

  Future<void> _initialize() async {
    await Future.wait([_todos.initialize(), _settings.initialize()]);
    if (!mounted) return;
    if (_purchases.enabled) unawaited(_purchases.initialize());
    _widgets = WidgetBridge(_todos, _settings, _theme)..start();
    if (!widget.enableNotifications) return;
    _notifications = NotificationService(_todos, _settings);
    await _notifications!.start();
    if (mounted) setState(() {});
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    _widgets?.refresh();
    unawaited(_notifications?.resume());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_todos.handleResume());
      unawaited(_notifications?.resume());
      unawaited(_widgets?.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifications?.dispose();
    _widgets?.dispose();
    _todos.dispose();
    _theme.dispose();
    _settings.dispose();
    _purchases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => AnimatedBuilder(
        animation: Listenable.merge([_theme, _settings]),
        builder: (context, _) {
          final lightBackground = _theme.style == AppearanceStyle.normal
              ? AppBackgrounds.pureWhite
              : AppBackgrounds.offWhite;
          final darkBackground = _theme.style == AppearanceStyle.normal
              ? AppBackgrounds.oledBlack
              : AppBackgrounds.softDark;
          final materialYou = _theme.style == AppearanceStyle.materialYou;
          final android =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
          _theme.dynamicColorsAvailable =
              android && lightDynamic != null && darkDynamic != null;
          _theme.dynamicLight = android ? lightDynamic : null;
          _theme.dynamicDark = android ? darkDynamic : null;
          return MaterialApp(
            title: 'Sometime',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
              brightness: Brightness.light,
              background: lightBackground,
              colorScheme: materialYou
                  ? (_theme.useSystemColors ? lightDynamic : null) ??
                        sometimeColorScheme(
                          Brightness.light,
                          seed: _theme.seedColor,
                        )
                  : null,
            ),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              background: darkBackground,
              colorScheme: materialYou
                  ? (_theme.useSystemColors ? darkDynamic : null) ??
                        sometimeColorScheme(
                          Brightness.dark,
                          seed: _theme.seedColor,
                        )
                  : null,
            ),
            themeMode: _theme.themeMode,
            themeAnimationDuration: AppMotion.color,
            themeAnimationCurve: AppMotion.curve,
            locale: switch (_settings.value.language) {
              'de' => const Locale('de'),
              'en' => const Locale('en'),
              'es' => const Locale('es'),
              'pt-BR' => const Locale('pt', 'BR'),
              'fr' => const Locale('fr'),
              'ja' => const Locale('ja'),
              _ => null,
            },
            supportedLocales: AppStrings.supportedLocales,
            localeResolutionCallback: (locale, supported) =>
                AppStrings.resolveLocale(locale),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _AppRoot(
              settingsReady: _settings.ready,
              showOnboarding: _settings.shouldShowOnboarding,
              animateFirstHomeEntrance: _animateFirstHomeEntrance,
              todoController: _todos,
              notifications: _notifications,
              themeController: _theme,
              settingsController: _settings,
              purchaseService: _purchases,
              onOnboardingCompleted: () {
                if (!_animateFirstHomeEntrance) {
                  setState(() => _animateFirstHomeEntrance = true);
                }
              },
              onFirstHomeEntranceCompleted: () {
                if (_animateFirstHomeEntrance && mounted) {
                  setState(() => _animateFirstHomeEntrance = false);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot({
    required this.settingsReady,
    required this.showOnboarding,
    required this.animateFirstHomeEntrance,
    required this.todoController,
    required this.notifications,
    required this.themeController,
    required this.settingsController,
    required this.purchaseService,
    required this.onOnboardingCompleted,
    required this.onFirstHomeEntranceCompleted,
  });

  final bool settingsReady;
  final bool showOnboarding;
  final bool animateFirstHomeEntrance;
  final TodoController todoController;
  final NotificationService? notifications;
  final ThemeController themeController;
  final SettingsController settingsController;
  final SupportPurchaseService purchaseService;
  final VoidCallback onOnboardingCompleted;
  final VoidCallback onFirstHomeEntranceCompleted;

  @override
  Widget build(BuildContext context) {
    final child = !settingsReady
        ? Scaffold(
            key: const ValueKey('app-loading'),
            backgroundColor: context.appColors.background,
          )
        : showOnboarding
        ? OnboardingScreen(
            key: const ValueKey('onboarding'),
            settingsController: settingsController,
            onCompleted: onOnboardingCompleted,
          )
        : MainPagerScreen(
            key: const ValueKey('todo-home'),
            todoController: todoController,
            notifications: notifications,
            themeController: themeController,
            settingsController: settingsController,
            purchaseService: purchaseService,
            animateFirstEntrance: animateFirstHomeEntrance,
            onFirstEntranceCompleted: onFirstHomeEntranceCompleted,
          );
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppMotion.open),
      reverseDuration: AppMotion.duration(context, AppMotion.close),
      switchInCurve: AppMotion.curve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
