$p='lib/app/todo_app.dart'; $s=Get-Content $p -Raw
$s=$s.Replace("import '../models/theme_preference.dart';","import '../models/theme_preference.dart';`nimport '../services/notification_service.dart';")
$s=$s.Replace('this.clock = systemClock,',"this.clock = systemClock,`n    this.enableNotifications = false,")
$s=$s.Replace('final AppClock clock;',"final AppClock clock;`n  final bool enableNotifications;")
$s=$s.Replace('late final ThemeController _theme;',"late final ThemeController _theme;`n  NotificationService? _notifications;")
$s=$s.Replace('unawaited(_todos.initialize());',"unawaited(_initialize());")
$s=$s.Replace('  @override'+"`r`n  void didChangeAppLifecycleState",@"
  Future<void> _initialize() async {
    await _todos.initialize();
    if (!mounted || !widget.enableNotifications) return;
    _notifications = NotificationService(_todos);
    await _notifications!.start();
  }

  @override
  void didChangeAppLifecycleState
"@)
$s=$s.Replace('unawaited(_todos.handleResume());',"unawaited(_todos.handleResume());`n      unawaited(_notifications?.resume());")
$s=$s.Replace('    _todos.dispose();',"    _notifications?.dispose();`n    _todos.dispose();")
Set-Content $p $s
$p='lib/main.dart'; $s=Get-Content $p -Raw; $s=$s.Replace('themeStorage: storage','themeStorage: storage, enableNotifications: true'); Set-Content $p $s
