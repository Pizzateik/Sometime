$ErrorActionPreference = 'Stop'
function Edit-Text($path, $before, $after) {
  $text = [IO.File]::ReadAllText((Join-Path $PWD $path))
  if (-not $text.Contains($before)) { throw "Text not found in $path" }
  [IO.File]::WriteAllText((Join-Path $PWD $path), $text.Replace($before, $after))
}
Edit-Text 'pubspec.yaml' '    - assets/icon/' '    - assets/Own Assets/Icon/Android_Adaptive_Foreground.svg'
Edit-Text 'lib/widgets/task_planning_fields.dart' 'BorderRadius.circular(12)' 'BorderRadius.circular(AppSpace.controlRadius)'
Edit-Text 'lib/widgets/sometime_segmented_control.dart' 'color: colors.track,' 'color: colors.pill,'
Edit-Text 'lib/widgets/task_planning_fields.dart' 'alignment: Alignment.center,' "constraints: const BoxConstraints(minHeight: 44),`n      alignment: Alignment.center,"
Edit-Text 'lib/app/app_strings.dart' 'Wenn du Sometime gern verwendest, kannst du die weitere Entwicklung unterstützen.' 'Wenn dir Sometime gefällt, kannst du mich unterstützen und damit die weitere Entwicklung finanzieren.'
Edit-Text 'lib/app/app_strings.dart' 'If you enjoy Sometime, you can support its continued development.' 'If you enjoy using Sometime, you can support me and help fund its continued development.'
Edit-Text 'lib/app/app_strings.dart' 'Ich habe Sometime während meines Studiums entwickelt. Die meisten Todo-Apps vermischten Aufgaben für heute mit Dingen für viel später.\n\nSometime trennt diese Zeithorizonte ohne Projekte, Tags oder zusätzliche Verwaltung.' 'Hallo 👋 Ich bin Eik und habe Sometime während meines Studiums gebaut, weil viele Todo-Apps unterschiedliche Zeithorizonte vermischen. Aufgaben für heute stehen neben Dingen, die vielleicht erst in Wochen oder Monaten wichtig werden.\n\nSometime trennt diese Zeithorizonte, ohne dafür Projekte, Tags oder noch mehr Organisation einzuführen.'
Edit-Text 'lib/app/app_strings.dart' 'I built Sometime while studying. Most todo apps mixed today’s tasks with things for weeks or months later.\n\nSometime separates these time horizons without projects, tags, or more organization.' 'Hello 👋 I’m Eik, and I built Sometime while studying because most todo apps mixed different time horizons. Things I had to do today appeared alongside things I might want to do weeks or months later.\n\nSometime separates those time horizons without adding projects, tags, or more organization.'
Edit-Text 'lib/screens/settings_screen.dart' "import 'package:package_info_plus/package_info_plus.dart';" "import 'package:package_info_plus/package_info_plus.dart';`nimport 'package:flutter_svg/flutter_svg.dart';"
Edit-Text 'lib/screens/settings_screen.dart' "Image.asset('assets/icon/sometime_foreground.png')" 'SvgPicture.asset(AppConfig.iconForeground)'
