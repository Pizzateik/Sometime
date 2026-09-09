import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sometime_icons.dart';

abstract final class AppBackgrounds {
  static const deleteAccent = Color(0xFFFF303B);
  static const offWhite = Color(0xFFFAFAF8);
  static const pureWhite = Color(0xFFFFFFFF);
  static const oledBlack = Color(0xFF000000);
  static const softDark = Color(0xFF121212);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.text,
    required this.secondary,
    required this.outline,
    required this.track,
    required this.hover,
    required this.focus,
    this.scheme,
  });

  factory AppPalette.light(Color background) => AppPalette(
    background: background,
    surface: const Color(0xFFFFFFFF),
    ink: const Color(0xFF000000),
    text: const Color(0xFF343834),
    secondary: const Color(0xFF696D66),
    outline: const Color(0xFF92968E),
    track: const Color(0xFFEBECE7),
    hover: const Color(0x0A000000),
    focus: const Color(0xFF858D7D),
  );

  factory AppPalette.dark(Color background) => AppPalette(
    background: background,
    surface: background == AppBackgrounds.oledBlack
        ? const Color(0xFF111111)
        : const Color(0xFF1C1C1C),
    ink: Color(0xFFFFFFFF),
    text: Color(0xFFEFEFEA),
    secondary: Color(0xFFA9AAA4),
    outline: Color(0xFF777A73),
    track: Color(0xFF1C1C1B),
    hover: Color(0x12FFFFFF),
    focus: Color(0xFFB8C0B3),
  );

  factory AppPalette.fromScheme(ColorScheme scheme) => AppPalette(
    scheme: scheme,
    background: scheme.surface,
    surface: scheme.surfaceContainer,
    ink: scheme.onSurface,
    text: scheme.onSurface,
    secondary: scheme.onSurfaceVariant,
    outline: scheme.outline,
    track: scheme.outlineVariant,
    hover: scheme.onSurface.withValues(alpha: 0.06),
    focus: scheme.primary,
  );

  final ColorScheme? scheme;
  Color get accent => scheme?.primary ?? ink;
  Color get onAccent => scheme?.onPrimary ?? background;
  Color get selected => scheme?.primaryContainer ?? hover;
  Color get onSelected => scheme?.onPrimaryContainer ?? text;
  Color get destructive => AppBackgrounds.deleteAccent;
  Color get onDestructive => scheme?.onError ?? surface;
  Color get shadow => scheme?.shadow ?? const Color(0xFF000000);
  Color get creationSurface => scheme?.surfaceContainerHigh ?? surface;
  Color get pill => scheme?.surfaceContainerHighest ?? hover;
  Color get activeBorder =>
      scheme?.primary ??
      (background.computeLuminance() < 0.1
          ? const Color(0xFF555555)
          : Colors.transparent);
  Color get taskSurface => scheme?.surfaceContainerLow ?? background;
  Color get disabled => scheme?.onSurface.withValues(alpha: 0.38) ?? secondary;
  Color get strongSelection => scheme?.primary ?? ink;
  Color get onStrongSelection =>
      scheme?.onPrimary ?? (ink == Colors.black ? Colors.white : Colors.black);
  Color get settingsAvatar => scheme?.primary ?? ink;
  Color get onSettingsAvatar => scheme?.onPrimary ?? background;

  final Color background;
  final Color surface;
  final Color ink;
  final Color text;
  final Color secondary;
  final Color outline;
  final Color track;
  final Color hover;
  final Color focus;

  @override
  AppPalette copyWith({
    ColorScheme? scheme,
    Color? background,
    Color? surface,
    Color? ink,
    Color? text,
    Color? secondary,
    Color? outline,
    Color? track,
    Color? hover,
    Color? focus,
  }) => AppPalette(
    scheme: scheme ?? this.scheme,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    text: text ?? this.text,
    secondary: secondary ?? this.secondary,
    outline: outline ?? this.outline,
    track: track ?? this.track,
    hover: hover ?? this.hover,
    focus: focus ?? this.focus,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      scheme: scheme != null && other.scheme != null
          ? ColorScheme.lerp(scheme!, other.scheme!, t)
          : (t < 0.5 ? scheme : other.scheme),
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      track: Color.lerp(track, other.track, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get appColors => Theme.of(this).extension<AppPalette>()!;
}

abstract final class AppSpace {
  static const controlRadius = 12.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 40.0;
  static const touch = 48.0;
  static const contentWidth = 560.0;
  static const settingsMainAxis = 28.0;
  static const settingsRowIndent = 10.0;
}

abstract final class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const color = Duration(milliseconds: 180);
  static const complete = Duration(milliseconds: 220);
  static const insert = Duration(milliseconds: 280);
  static const open = Duration(milliseconds: 300);
  static const close = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

SystemUiOverlayStyle appSystemUiFor(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final background = context.appColors.background;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: background,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );
}

ColorScheme sometimeColorScheme(
  Brightness brightness, {
  Color seed = const Color(0xFFFF5C5C),
}) => ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
ThemeData buildAppTheme({
  required Brightness brightness,
  required Color background,
  ColorScheme? colorScheme,
}) {
  final dark = brightness == Brightness.dark;
  final palette = colorScheme != null
      ? AppPalette.fromScheme(colorScheme)
      : dark
      ? AppPalette.dark(background)
      : AppPalette.light(background);
  const family = 'Geist';
  const displayFamily = family;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(SometimeIcons.arrowLeft),
    ),
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    fontFamily: family,
    fontFamilyFallback: const [
      'Noto Sans CJK JP',
      'Noto Sans JP',
      'Hiragino Sans',
      'Hiragino Kaku Gothic ProN',
      'sans-serif',
    ],
    extensions: [palette],
    colorScheme:
        colorScheme ??
        (dark
            ? ColorScheme.dark(
                primary: palette.ink,
                onPrimary: palette.background,
                surface: palette.surface,
                onSurface: palette.text,
                secondary: palette.secondary,
                outline: palette.outline,
              )
            : ColorScheme.light(
                primary: palette.ink,
                onPrimary: palette.surface,
                surface: palette.surface,
                onSurface: palette.text,
                secondary: palette.secondary,
                outline: palette.outline,
              )),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: palette.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: palette.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: palette.text,
      ),
      labelLarge: TextStyle(
        fontFamily: family,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: palette.text,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colorScheme?.primary ?? palette.ink,
      selectionColor: (colorScheme?.primary ?? palette.ink).withValues(
        alpha: 0.12,
      ),
      selectionHandleColor: colorScheme?.primary ?? palette.ink,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
        ),
      ),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(
        fontFamily: family,
        color: palette.background,
        fontSize: 14,
      ),
      actionTextColor: palette.background,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(AppSpace.xl),
    ),
  );
}
