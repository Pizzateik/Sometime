$ErrorActionPreference = 'Stop'
function Update-Source($path, [scriptblock]$change) {
  $absolute = Join-Path $PWD $path
  $source = [IO.File]::ReadAllText($absolute)
  [IO.File]::WriteAllText($absolute, (& $change $source))
}
Update-Source 'lib/app/app_theme.dart' { param($s)
  $s = $s -replace "  final isApple =[\s\S]*?final displayFamily = isApple \? 'CupertinoSystemDisplay' : family;", "  const family = 'Geist';`n  const displayFamily = family;"
  $s = $s.Replace('FontWeight.w400', 'FontWeight.w500')
  $s = $s.Replace('    splashFactory:', "    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.controlRadius)))),`n    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(64, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.controlRadius)))),`n    splashFactory:")
  $s.Replace("import 'package:flutter/foundation.dart';`n", '').Replace("import 'package:flutter/foundation.dart';`r`n", '')
}
Update-Source 'lib/app/todo_app.dart' { param($s)
  $s.Replace("'assets/fonts/OFL-CormorantGaramond.txt'", "'assets/fonts/OFL-Geist.txt'").Replace("['Cormorant Garamond']", "['Geist']").Replace("yield LicenseEntryWithLineBreaks(['Geist'], license);", "yield LicenseEntryWithLineBreaks(['Geist'], license);`n        yield LicenseEntryWithLineBreaks(['Parisienne'], await rootBundle.loadString('assets/fonts/OFL-Parisienne.txt'));")
}
Update-Source 'lib/screens/main_pager_screen.dart' { param($s)
  $s = $s -replace 'fontWeight: FontWeight.lerp\(\s*FontWeight.w600,\s*FontWeight.w700,\s*active,\s*\)', 'fontWeight: FontWeight.w600'
  $s.Replace('painter.width.ceilToDouble()', 'painter.width')
}
Update-Source 'lib/widgets/sometime_input.dart' { param($s)
  $s.Replace("      TextButton(`r`n        onPressed: () => Navigator.pop(context, _controller.text)", "      FilledButton(`r`n        onPressed: () => Navigator.pop(context, _controller.text)")
}
$mapping = @{
  add='plus'; add_rounded='plus'; block='prohibit'; person_outline_rounded='user';
  tune_rounded='palette'; notifications_none_rounded='bell'; language_rounded='globe'; lock_outline_rounded='shield';
  delete_outline_rounded='trash'; check_rounded='check'; check_circle_rounded='checkCircle'; chevron_right_rounded='caretRight';
  north_east_rounded='arrowUpRight'; phone_iphone_rounded='deviceMobile'; arrow_upward_rounded='arrowUp'; close_rounded='x';
  keyboard_arrow_up_rounded='caretUp'; drag_handle_rounded='dotsSixVertical'; edit_outlined='pencilSimple';
  push_pin_outlined='pushPin'; push_pin_rounded='pushPinActive'
}
$icons = "import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';`n`nabstract final class SometimeIcons {`n"
foreach ($name in ($mapping.Values | Sort-Object -Unique)) {
  $value = if ($name -eq 'pushPinActive') { 'PhosphorIconsFill.pushPin' } else { "PhosphorIconsRegular.$name" }
  $icons += "  static const $name = $value;`n"
}
foreach ($name in @('downloadSimple','export','import','code','fileText','heart','hardDrive')) { $icons += "  static const $name = PhosphorIconsRegular.$name;`n" }
$icons += "}`n"
[IO.File]::WriteAllText((Join-Path $PWD 'lib/app/sometime_icons.dart'), $icons)
foreach ($file in Get-ChildItem lib -Filter '*.dart' -Recurse) {
  $s = [IO.File]::ReadAllText($file.FullName)
  if ($s -notmatch '\bIcons\.') { continue }
  foreach ($key in $mapping.Keys) { $s = $s -replace "\bIcons\.$key\b", "SometimeIcons.$($mapping[$key])" }
  $s = "import '../app/sometime_icons.dart';`n" + $s
  [IO.File]::WriteAllText($file.FullName, $s)
}
