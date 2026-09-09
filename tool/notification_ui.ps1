$p='lib/widgets/task_planning_fields.dart'; $s=Get-Content $p -Raw
$s=$s.Replace("import '../models/task_details.dart';","import '../models/task_details.dart';`nimport '../services/notification_service.dart';")
$s=$s.Replace('recurrence: rule,',"recurrence: rule,`n      reminder: value.reminder,")
$s=$s.Replace('recurrence: value.recurrence,',"recurrence: value.recurrence,`n          reminder: value.reminder,")
$s=$s.Replace("        const SizedBox(height: 28),",@"
        if (value.date != null) ...[
          const SizedBox(height: 20),
          Text('Reminder', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<ReminderRule>(
              tooltip: 'Reminder',
              initialValue: value.effectiveReminder,
              onSelected: (reminder) async {
                if (reminder != ReminderRule.none) {
                  await NotificationService.current?.requestPermission();
                }
                onChanged(TaskDetails(description: value.description,
                  date: value.date, minutes: value.minutes,
                  recurrence: value.recurrence, reminder: reminder));
              },
              itemBuilder: (_) => [
                for (final reminder in ReminderRule.options(value.minutes != null))
                  PopupMenuItem(value: reminder, child: Text(reminder.label)),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: colors.hover,
                  borderRadius: BorderRadius.circular(12)),
                child: Text(value.effectiveReminder.label,
                  style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
"@)
Set-Content $p $s
$p='lib/widgets/add_todo_sheet.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('recurrence: _details.recurrence,',"recurrence: _details.recurrence,`n          reminder: _details.effectiveReminder,")
Set-Content $p $s
$p='lib/widgets/todo_item.dart'; $s=Get-Content $p -Raw
$s=$s.Replace("import '../models/todo.dart';","import '../models/todo.dart';`nimport '../models/task_details.dart';")
$s=$s.Replace('this.onEdit,',"this.onEdit,`n    this.onPin,")
$s=$s.Replace('      onEdit,',"      onEdit,`n      onPin,")
$s=$s.Replace('child: Text('+"`r`n                                  taskDetailsLabel(context, todo.details),",@"
child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (todo.details.effectiveReminder != ReminderRule.none) ...[
                                    Icon(Icons.notifications_none_rounded, size: 12, color: colors.secondary),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(child: Text(
                                  taskDetailsLabel(context, todo.details),
"@)
$s=$s.Replace("                                      ),`r`n                              ),`r`n                            ),`r`n                        ],", "                                      ),`r`n                              )),]),`r`n                            ),`r`n                        ],")
# Wrap the existing edit control and the pin control in one hit area.
$s=$s.Replace('key: editKey,'+"`r`n                                  child: Pressable(","key: editKey,`n                                  child: Row(mainAxisSize: MainAxisSize.min, children: [Pressable(")
$s=$s.Replace("                                  ),`r`n                                ),`r`n                              )`r`n                            : const SizedBox",@"
                                  ),
                                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && widget.onPin != null)
                                    Pressable(
                                      label: todo.isPinned ? 'Unpin' : 'Pin to notification',
                                      onPressed: widget.onPin,
                                      builder: (context, state) => SizedBox(
                                        width: 40, height: 40,
                                        child: Icon(todo.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                          size: 19, color: todo.isPinned ? colors.focus : colors.secondary),
                                      ),
                                    ),
                                  ]),
                                ),
                              )
                            : const SizedBox
"@)
Set-Content $p $s
$p='lib/widgets/todo_section.dart'; $s=Get-Content $p -Raw
$s=$s.Replace('required this.onEdit,',"required this.onEdit,`n    this.onPin,")
$s=$s.Replace('final ValueChanged<Todo> onEdit;',"final ValueChanged<Todo> onEdit;`n  final ValueChanged<Todo>? onPin;")
$s=$s.Replace('onEdit: () => onEdit(todos[index]),',"onEdit: () => onEdit(todos[index]),`n                    onPin: onPin == null ? null : () => onPin!(todos[index]),")
Set-Content $p $s
$p='lib/screens/todo_space_screen.dart'; $s=Get-Content $p -Raw
$s=$s.Replace("import '../app/app_theme.dart';","import '../app/app_theme.dart';`nimport '../services/notification_service.dart';")
$s=$s.Replace('onEdit: _openEditor,',@"
onEdit: _openEditor,
                                  onPin: (todo) async {
                                    HapticFeedback.selectionClick();
                                    if (!todo.isPinned) {
                                      await NotificationService.current?.requestPermission();
                                    }
                                    if (!mounted) return;
                                    widget.controller.setPinned(widget.spaceId, todo.id, !todo.isPinned);
                                  },
"@)
Set-Content $p $s
