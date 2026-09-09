$p='lib/screens/main_pager_screen.dart'; $s=Get-Content $p -Raw
$s=$s.Replace("import '../app/app_theme.dart';","import '../app/app_theme.dart';`nimport '../services/notification_service.dart';")
$s=$s.Replace('required this.themeController,',"required this.themeController,`n    this.notifications,")
$s=$s.Replace('final ThemeController themeController;',"final ThemeController themeController;`n  final NotificationService? notifications;")
$s=$s.Replace('  double? _panelTop()',@"
  String? _notificationTask;
  String? _lastNotificationProblem;

  @override
  void initState() {
    super.initState();
    _listenNotifications();
  }

  @override
  void didUpdateWidget(MainPagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifications != widget.notifications) {
      oldWidget.notifications?.removeListener(_notificationChanged);
      oldWidget.notifications?.openTask.removeListener(_notificationOpened);
      _listenNotifications();
    }
  }

  void _listenNotifications() {
    widget.notifications?.addListener(_notificationChanged);
    widget.notifications?.openTask.addListener(_notificationOpened);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notificationChanged();
      _notificationOpened();
    });
  }

  void _notificationChanged() {
    final problem = widget.notifications?.problem;
    if (problem == null) { _lastNotificationProblem = null; return; }
    if (!mounted || problem == _lastNotificationProblem) return;
    _lastNotificationProblem = problem;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(problem),
      action: SnackBarAction(label: 'Settings', onPressed: () {
        widget.notifications?.openSettings();
      }),
    ));
  }

  void _notificationOpened() {
    final target = widget.notifications?.openTask.value;
    if (!mounted || target == null || !_pageController.hasClients) return;
    final index = widget.todoController.spaces.indexWhere((s) => s.id == target.spaceId);
    if (index < 0) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _notificationTask = target.taskId);
    _showPage(index);
    widget.notifications?.openTask.value = null;
  }

  double? _panelTop()
"@)
$s=$s.Replace('    _pageController.dispose();',"    widget.notifications?.removeListener(_notificationChanged);`n    widget.notifications?.openTask.removeListener(_notificationOpened);`n    _pageController.dispose();")
$s=$s.Replace('spaceId: spaces[index].id,',"spaceId: spaces[index].id,`n                        focusTaskId: _notificationTask,")
Set-Content $p $s
$p='lib/screens/todo_space_screen.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('this.buttonBounds,',"this.buttonBounds,`n    this.focusTaskId,")
$s=$s.Replace('  final String spaceId;',"  final String spaceId;`n  final String? focusTaskId;")
$s=$s.Replace('    super.didUpdateWidget(oldWidget);',@"
    super.didUpdateWidget(oldWidget);
    if (widget.focusTaskId != null && widget.focusTaskId != oldWidget.focusTaskId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final row = _rowKeys[widget.focusTaskId]?.currentContext;
        if (row != null) {
          setState(() => _activeTodoId = widget.focusTaskId);
          Scrollable.ensureVisible(row, duration: AppMotion.open, alignment: 0.35);
        }
      });
    }
"@)
Set-Content $p $s
$p='lib/screens/settings_screen.dart'; $s=(Get-Content $p -Raw).Replace("`r`n","`n")
$s=$s.Replace("import 'package:flutter/foundation.dart';",'')
$s=$s.Replace('style: AppearanceStyle.values[index],',"style: AppearanceStyle.values[index],`n                          controller: controller,")
$s=$s.Replace("                Text('Mode',",@"
                if (controller.style == AppearanceStyle.materialYou && !controller.dynamicColorsAvailable) ...[
                  _SettingsEntry(icon: Icons.palette_outlined,
                    label: 'Material You Color',
                    onPressed: () => _pickSeed(context)),
                  Align(alignment: Alignment.centerLeft,
                    child: Container(width: 28, height: 28,
                      decoration: BoxDecoration(color: controller.seedColor,
                        shape: BoxShape.circle, border: Border.all(color: context.appColors.outline)))),
                  const SizedBox(height: 24),
                ],
                Text('Mode',
"@)
$pos=$s.IndexOf('  @override', $s.IndexOf('class AppearanceScreen'))
$s=$s.Insert($pos,@"
  Future<void> _pickSeed(BuildContext context) async {
    final selected = await showDialog<Color>(context: context,
      builder: (_) => _SeedPicker(initial: controller.seedColor));
    if (selected != null) await controller.setSeedColor(selected);
  }

"@)
$s=$s.Replace('    required this.style,',"    required this.style,`n    required this.controller,")
$s=$s.Replace('  final AppearanceStyle style;',"  final AppearanceStyle style;`n  final ThemeController controller;")
$start=$s.IndexOf('    final label =', $s.IndexOf('class _StyleCard')); $end=$s.IndexOf('    return Pressable(', $start)
$s=$s.Substring(0,$start)+@"
    final label = style.label;
    final dark = switch (style) {
      AppearanceStyle.normal => AppBackgrounds.oledBlack,
      AppearanceStyle.soft => AppBackgrounds.softDark,
      AppearanceStyle.materialYou => (controller.dynamicDark ??
        sometimeColorScheme(Brightness.dark, seed: controller.seedColor)).primaryContainer,
    };
    final light = switch (style) {
      AppearanceStyle.normal => AppBackgrounds.pureWhite,
      AppearanceStyle.soft => AppBackgrounds.offWhite,
      AppearanceStyle.materialYou => (controller.dynamicLight ??
        sometimeColorScheme(Brightness.light, seed: controller.seedColor)).primaryContainer,
    };
"@+$s.Substring($end)
$s+=@"

class _SeedPicker extends StatefulWidget {
  const _SeedPicker({required this.initial});
  final Color initial;
  @override
  State<_SeedPicker> createState() => _SeedPickerState();
}

class _SeedPickerState extends State<_SeedPicker> {
  late HSVColor color = HSVColor.fromColor(widget.initial);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Material You Color'),
    content: SizedBox(width: 280, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(height: 44, decoration: BoxDecoration(color: color.toColor(), borderRadius: BorderRadius.circular(12))),
      const SizedBox(height: 16),
      for (final component in ['Hue', 'Saturation', 'Brightness']) ...[
        Align(alignment: Alignment.centerLeft, child: Text(component)),
        Slider(label: component, value: switch (component) {
          'Hue' => color.hue / 360, 'Saturation' => color.saturation, _ => color.value,
        }, onChanged: (value) => setState(() {
          color = switch (component) {
            'Hue' => color.withHue(value * 360),
            'Saturation' => color.withSaturation(value),
            _ => color.withValue(value),
          };
        })),
      ],
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(context, color.toColor()), child: const Text('Use color')),
    ],
  );
}
"@
Set-Content $p $s
