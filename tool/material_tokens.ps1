$p='lib/app/app_theme.dart'; $s=(Get-Content $p -Raw).Replace("`r`n","`n")
$s=$s.Replace('    required this.focus,',"    required this.focus,`n    this.scheme,")
$s=$s.Replace('  final Color background;',@"
  final ColorScheme? scheme;
  Color get accent => scheme?.primary ?? ink;
  Color get onAccent => scheme?.onPrimary ?? background;
  Color get selected => scheme?.primaryContainer ?? hover;
  Color get onSelected => scheme?.onPrimaryContainer ?? text;
  Color get destructive => scheme?.error ?? AppBackgrounds.deleteAccent;
  Color get onDestructive => scheme?.onError ?? surface;
  Color get shadow => scheme?.shadow ?? const Color(0xFF000000);
  Color get creationSurface => scheme?.surfaceContainerHigh ?? surface;
  Color get pill => scheme?.surfaceContainerHighest ?? hover;
  Color get activeBorder => scheme?.primary ?? outline;
  Color get disabled => scheme?.onSurface.withValues(alpha: 0.38) ?? secondary;

  final Color background;
"@)
$start=$s.IndexOf('    background: scheme.brightness'); $end=$s.IndexOf('    surface: scheme.surfaceContainer,',$start)
$s=$s.Substring(0,$start)+"    scheme: scheme,`n    background: scheme.surface,`n"+$s.Substring($end)
$s=$s.Replace('    Color? background,',"    ColorScheme? scheme,`n    Color? background,")
$s=$s.Replace('    background: background ?? this.background,',"    scheme: scheme ?? this.scheme,`n    background: background ?? this.background,")
$s=$s.Replace('      background: Color.lerp(background, other.background, t)!,',"      scheme: scheme != null && other.scheme != null ? ColorScheme.lerp(scheme!, other.scheme!, t) : (t < 0.5 ? scheme : other.scheme),`n      background: Color.lerp(background, other.background, t)!,")
$start=$s.IndexOf('ColorScheme sometimeColorScheme'); $end=$s.IndexOf('ThemeData buildAppTheme', $start)
$s=$s.Substring(0,$start)+@"
ColorScheme sometimeColorScheme(Brightness brightness, {Color seed = const Color(0xFF566F8E)}) =>
    ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

"@+$s.Substring($end)
Set-Content $p $s
$p='lib/models/theme_preference.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('required this.style});','required this.style, this.seedColor = 0xFF566F8E});')
$s=$s.Replace('  final AppearanceMode mode;',"  final int seedColor;`n  final AppearanceMode mode;")
Set-Content $p $s
$p='lib/models/todo_storage.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('return AppearancePreference(mode: mode.single, style: style.single);',"return AppearancePreference(mode: mode.single, style: style.single,`n      seedColor: await _preferences.getInt('material-you-seed.v1') ?? 0xFF566F8E);")
$s=$s.Replace('await _preferences.setString(appearanceStyleKey, preference.style.name);',"await _preferences.setString(appearanceStyleKey, preference.style.name);`n      await _preferences.setInt('material-you-seed.v1', preference.seedColor);")
Set-Content $p $s
$p='lib/state/theme_controller.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('  bool _saveFailed = false;',"  Color seedColor = const Color(0xFF566F8E);`n  bool dynamicColorsAvailable = false;`n  ColorScheme? dynamicLight;`n  ColorScheme? dynamicDark;`n  bool _saveFailed = false;")
$s=$s.Replace('_style = appearance.style;',"_style = appearance.style;`n        seedColor = Color(appearance.seedColor);")
$s=$s.Replace('AppearancePreference(mode: _mode, style: _style),','AppearancePreference(mode: _mode, style: _style, seedColor: seedColor.toARGB32()),')
$s=$s.Replace('  Future<void> retrySave()',@"
  Future<void> setSeedColor(Color value) async {
    seedColor = value.withValues(alpha: 1);
    _notify();
    await _save();
  }

  Future<void> retrySave()
"@)
Set-Content $p $s
$p='lib/app/todo_app.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('          return MaterialApp(',@"
          _theme.dynamicColorsAvailable = android && lightDynamic != null && darkDynamic != null;
          _theme.dynamicLight = android ? lightDynamic : null;
          _theme.dynamicDark = android ? darkDynamic : null;
          return MaterialApp(
"@)
$s=$s.Replace('sometimeColorScheme(Brightness.light)','sometimeColorScheme(Brightness.light, seed: _theme.seedColor)').Replace('sometimeColorScheme(Brightness.dark)','sometimeColorScheme(Brightness.dark, seed: _theme.seedColor)')
$s=$s.Replace('todoController: _todos,',"todoController: _todos,`n              notifications: _notifications,")
Set-Content $p $s
# Widgets use the semantic palette for controls.
Get-ChildItem lib/widgets,lib/screens -Filter '*.dart' | ForEach-Object {
  $s=Get-Content $_.FullName -Raw
  $s=$s.Replace('Theme.of(context).colorScheme.onPrimaryContainer','context.appColors.onSelected').Replace('Theme.of(context).colorScheme.primaryContainer','context.appColors.selected')
  $s=$s.Replace('Theme.of(context).colorScheme.onPrimary','context.appColors.onAccent').Replace('Theme.of(context).colorScheme.primary','context.appColors.accent')
  $s=$s.Replace('AppBackgrounds.deleteAccent','context.appColors.destructive').Replace('Colors.black.withValues','context.appColors.shadow.withValues')
  Set-Content $_.FullName $s
}
$p='lib/widgets/add_todo_button.dart'; $s=Get-Content $p -Raw
$start=$s.IndexOf('    final buttonColor'); $end=$s.IndexOf('    final targetWidth',$start)
$s=$s.Substring(0,$start)+"    final buttonColor = colors.accent;`n    final buttonInk = colors.onAccent;`n"+$s.Substring($end)
Set-Content $p $s
$p='lib/widgets/add_todo_sheet.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('                                colors.surface,','                                colors.creationSurface,')
$s=[regex]::Replace($s,'Theme.of\(context\)\s*\.colorScheme\s*\.onPrimary','context.appColors.onAccent')
Set-Content $p $s
$p='lib/widgets/todo_item.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('fill: colors.ink,','fill: colors.accent,').Replace('check: colors.background,','check: colors.onAccent,').Replace('color: colors.hover,','color: colors.pill,')
Set-Content $p $s
