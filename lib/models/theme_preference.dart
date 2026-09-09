enum ThemePreference {
  system('System'),
  offWhite('Off White'),
  pureWhite('Reinweiß'),
  oledBlack('OLED Schwarz');

  const ThemePreference(this.label);

  final String label;
}

enum AppearanceMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const AppearanceMode(this.label);

  final String label;
}

enum AppearanceStyle {
  normal('Crisp'),
  soft('Soft'),
  materialYou('Material You');

  const AppearanceStyle(this.label);

  final String label;
}

enum MaterialColorSource { system, custom }

class AppearancePreference {
  const AppearancePreference({
    required this.mode,
    required this.style,
    this.seedColor = 0xFFFF5C5C,
    this.colorSource = MaterialColorSource.system,
  });

  final int seedColor;
  final MaterialColorSource colorSource;
  final AppearanceMode mode;
  final AppearanceStyle style;
}
