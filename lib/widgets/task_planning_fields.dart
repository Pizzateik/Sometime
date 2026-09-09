import '../app/sometime_icons.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/app_theme.dart';
import '../app/task_details_formatter.dart';
import '../models/task_details.dart';
import '../services/app_haptics.dart';
import '../services/notification_service.dart';
import 'pressable.dart';
import 'sometime_segmented_control.dart';

class TaskPlanningFields extends StatelessWidget {
  const TaskPlanningFields({
    required this.value,
    required this.onChanged,
    required this.isPinned,
    required this.onPinChanged,
    this.datePulse = 0,
    this.timePulse = 0,
    this.clock,
    this.onDateSelected,
    this.onDateCleared,
    this.onTimeSelected,
    this.onTimeCleared,
    super.key,
  });
  final TaskDetails value;
  final ValueChanged<TaskDetails> onChanged;
  final bool isPinned;
  final ValueChanged<bool> onPinChanged;
  final int datePulse;
  final int timePulse;
  final DateTime Function()? clock;
  final VoidCallback? onDateSelected;
  final VoidCallback? onDateCleared;
  final VoidCallback? onTimeSelected;
  final VoidCallback? onTimeCleared;

  bool get _showPin =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  DateTime get _now => clock?.call() ?? DateTime.now();

  void _change({
    DateTime? date,
    bool clearDate = false,
    int? minutes,
    bool clearTime = false,
    RecurrenceRule? recurrence,
    bool replaceRule = false,
    ReminderRule? reminder,
  }) {
    onChanged(
      TaskDetails(
        description: value.description,
        date: clearDate ? null : date ?? value.date,
        minutes: clearTime ? null : minutes ?? value.minutes,
        recurrence: replaceRule ? recurrence : value.recurrence,
        reminder: reminder ?? value.reminder,
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showDatePicker(
      context: context,
      initialDate: value.date ?? _now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (context.mounted && selected != null) {
      _change(date: selected);
      onDateSelected?.call();
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showTimePicker(
      context: context,
      initialTime: value.minutes == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: value.minutes! ~/ 60, minute: value.minutes! % 60),
    );
    if (context.mounted && selected != null) {
      _change(minutes: selected.hour * 60 + selected.minute);
      onTimeSelected?.call();
    }
  }

  Future<void> _pickReminder(BuildContext context) async {
    final options = ReminderRule.options(value.minutes != null);
    final selected = await showDialog<ReminderRule>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        backgroundColor: dialogContext.appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: dialogContext.appColors.track),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  Pressable(
                    label: dialogContext.strings.reminderName(option.index),
                    selected: option == value.effectiveReminder,
                    hapticOnTap: false,
                    onPressed: () => Navigator.pop(dialogContext, option),
                    builder: (context, state) => AnimatedContainer(
                      duration: AppMotion.duration(context, AppMotion.color),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: option == value.effectiveReminder
                            ? context.appColors.selected
                            : state.hovered
                            ? context.appColors.hover
                            : null,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.strings.reminderName(option.index),
                            ),
                          ),
                          if (option == value.effectiveReminder)
                            Icon(
                              SometimeIcons.check,
                              size: 18,
                              color: context.appColors.onSelected,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || selected == value.effectiveReminder) return;
    AppHaptics.selection();
    if (selected != ReminderRule.none) {
      await NotificationService.current?.requestPermission();
    }
    if (context.mounted) _change(reminder: selected);
  }

  RecurrenceRule _rule(RecurrenceType type, [RecurrenceRule? source]) {
    final current = source ?? value.recurrence;
    final base = value.date ?? DateTime.now();
    return RecurrenceRule(
      type: type,
      weekdays: current?.weekdays ?? [base.weekday],
      monthDay: current?.monthDay ?? base.day,
      yearMonth: current?.yearMonth ?? base.month,
      yearDay: current?.yearDay ?? base.day,
    );
  }

  Future<void> _pickYearly(BuildContext context, RecurrenceRule rule) async {
    final now = DateTime(2000);
    final initialDay = rule.yearDay.clamp(
      1,
      DateTime(now.year, rule.yearMonth + 1, 0).day,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, rule.yearMonth, initialDay),
      firstDate: DateTime(now.year),
      lastDate: DateTime(now.year, 12, 31),
    );
    if (context.mounted && selected != null) {
      _change(
        replaceRule: true,
        recurrence: RecurrenceRule(
          type: rule.type,
          weekdays: rule.weekdays,
          monthDay: rule.monthDay,
          yearMonth: selected.month,
          yearDay: selected.day,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final rule = value.recurrence;
    final labelStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Pill(
                label: value.date == null
                    ? strings.date
                    : MaterialLocalizations.of(context)
                          .formatShortMonthDay(value.date!),
                active: value.date != null,
                pulseId: datePulse,
                onPressed: () => _pickDate(context),
                onClear: value.date == null
                    ? null
                    : () {
                        _change(clearDate: true);
                        onDateCleared?.call();
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Pill(
                label: value.minutes == null
                    ? strings.time
                    : taskDetailsLabel(
                        context,
                        TaskDetails(minutes: value.minutes),
                      ),
                active: value.minutes != null,
                pulseId: timePulse,
                onPressed: () => _pickTime(context),
                onClear: value.minutes == null
                    ? null
                    : () {
                        _change(clearTime: true);
                        onTimeCleared?.call();
                      },
              ),
            ),
          ],
        ),
        if (value.date != null) ...[
          const SizedBox(height: 18),
          _PlanningOptionRow(
            icon: Icon(
              SometimeIcons.bell,
              size: 20,
              color: value.effectiveReminder != ReminderRule.none
                  ? context.appColors.focus
                  : context.appColors.secondary,
            ),
            label: strings.reminder,
            labelStyle: labelStyle,
            trailing: _Pill(
              label: strings.reminderName(value.effectiveReminder.index),
              active: value.effectiveReminder != ReminderRule.none,
              compact: true,
              onPressed: () => _pickReminder(context),
            ),
          ),
        ],
        if (_showPin) ...[
          const SizedBox(height: 22),
          _PinOption(isPinned: isPinned, onChanged: onPinChanged),
        ],
        const SizedBox(height: 22),
        _PlanningOptionRow(
          icon: Icon(
            SometimeIcons.arrowsClockwise,
            size: 20,
            color: rule != null
                ? context.appColors.focus
                : context.appColors.secondary,
          ),
          label: strings.routine,
          labelStyle: labelStyle,
          trailing: Pressable(
            label: strings.routine,
            checked: rule != null,
            hapticOnTap: false,
            onPressed: () {
              AppHaptics.selection();
              _change(
                replaceRule: true,
                recurrence: rule == null ? _rule(RecurrenceType.weekly) : null,
              );
            },
            builder: (context, state) => Transform.scale(
              scale: state.pressed ? 0.97 : 1,
              child: Switch.adaptive(
                value: rule != null,
                onChanged: (_) {
                  AppHaptics.selection();
                  _change(
                    replaceRule: true,
                    recurrence: rule == null
                        ? _rule(RecurrenceType.weekly)
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.open),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: rule == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    SometimeSegmentedControl<RecurrenceType>(
                      values: RecurrenceType.values,
                      value: rule.type,
                      label: (type) => switch (type) {
                        RecurrenceType.weekly => strings.weekly,
                        RecurrenceType.monthly => strings.monthly,
                        RecurrenceType.yearly => strings.yearly,
                      },
                      onChanged: (type) => _change(
                        replaceRule: true,
                        recurrence: _rule(type, rule),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (rule.type == RecurrenceType.weekly)
                      _WeekdayPicker(
                        rule: rule,
                        onChanged: (next) =>
                            _change(replaceRule: true, recurrence: next),
                      ),
                    if (rule.type == RecurrenceType.monthly)
                      _MonthDayGrid(
                        rule: rule,
                        onChanged: (next) =>
                            _change(replaceRule: true, recurrence: next),
                      ),
                    if (rule.type == RecurrenceType.yearly)
                      _Pill(
                        label: MaterialLocalizations.of(context)
                            .formatShortMonthDay(
                              DateTime(2000, rule.yearMonth, rule.yearDay),
                            ),
                        active: true,
                        onPressed: () => _pickYearly(context, rule),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      routineLabel(context, rule),
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: context.appColors.secondary),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PinOption extends StatelessWidget {
  const _PinOption({required this.isPinned, required this.onChanged});

  final bool isPinned;
  final ValueChanged<bool> onChanged;

  void _toggle() {
    AppHaptics.selection();
    onChanged(!isPinned);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final strings = context.strings;
    return _PlanningOptionRow(
      icon: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.color),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.82, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Icon(
            key: ValueKey(isPinned),
            isPinned ? SometimeIcons.pushPinActive : SometimeIcons.pushPin,
            size: 20,
            color: isPinned ? colors.focus : colors.secondary,
          ),
        ),
      ),
      label: strings.pinToNotification,
      labelStyle: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      trailing: Pressable(
        label: strings.pinToNotification,
        checked: isPinned,
        hapticOnTap: false,
        onPressed: _toggle,
        builder: (context, state) => Transform.scale(
          scale: state.pressed ? 0.97 : 1,
          child: Switch.adaptive(value: isPinned, onChanged: (_) => _toggle()),
        ),
      ),
    );
  }
}

class _PlanningOptionRow extends StatelessWidget {
  const _PlanningOptionRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.labelStyle,
  });

  final Widget icon;
  final String label;
  final Widget trailing;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 28,
        height: 48,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.only(top: 8), child: icon),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: labelStyle),
          ),
        ),
      ),
      const SizedBox(width: 8),
      trailing,
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onPressed,
    this.onClear,
    this.compact = false,
    this.pulseId = 0,
  });
  final String label;
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback? onClear;
  final bool compact;
  final int pulseId;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(pulseId),
    tween: Tween(begin: pulseId == 0 ? 1.0 : 1.03, end: 1.0),
    duration: AppMotion.duration(context, const Duration(milliseconds: 190)),
    curve: AppMotion.curve,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: Pressable(
      label: label,
      onPressed: onPressed,
      excludeChildSemantics: false,
      radius: AppSpace.controlRadius,
      scale: 0.975,
      builder: (context, state) => AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.press),
        width: compact ? null : double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: active
              ? context.appColors.strongSelection
              : context.appColors.pill,
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: onClear == null ? 14 : 36,
                vertical: 14,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active
                      ? context.appColors.onStrongSelection
                      : context.appColors.text,
                ),
              ),
            ),
            if (onClear != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Pressable(
                  label: '${context.strings.delete} $label',
                  onPressed: onClear,
                  builder: (context, state) => SizedBox(
                    width: 36,
                    child: Icon(
                      SometimeIcons.x,
                      size: 15,
                      color: active
                          ? context.appColors.onStrongSelection
                          : context.appColors.secondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.rule, required this.onChanged});
  final RecurrenceRule rule;
  final ValueChanged<RecurrenceRule> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = context.strings.weekdayInitials;
    return Row(
      children: [
        for (var day = 1; day <= 7; day++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AspectRatio(
                aspectRatio: 1,
                child: _DayButton(
                  semanticLabel: MaterialLocalizations.of(context)
                      .formatFullDate(DateTime(2026, 9, 7 + day - 1)),
                  label: labels[day - 1],
                  selected: rule.weekdays.contains(day),
                  onPressed: () {
                    final days = rule.weekdays.toSet();
                    if (!days.remove(day)) days.add(day);
                    if (days.isEmpty) return;
                    onChanged(
                      RecurrenceRule(
                        type: rule.type,
                        weekdays: days.toList()..sort(),
                        monthDay: rule.monthDay,
                        yearMonth: rule.yearMonth,
                        yearDay: rule.yearDay,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthDayGrid extends StatelessWidget {
  const _MonthDayGrid({required this.rule, required this.onChanged});
  final RecurrenceRule rule;
  final ValueChanged<RecurrenceRule> onChanged;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 7,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 5,
    crossAxisSpacing: 5,
    children: [
      for (var day = 1; day <= 31; day++)
        _DayButton(
          label: '$day',
          selected: rule.monthDay == day,
          onPressed: () => onChanged(
            RecurrenceRule(
              type: rule.type,
              weekdays: rule.weekdays,
              monthDay: day,
              yearMonth: rule.yearMonth,
              yearDay: rule.yearDay,
            ),
          ),
        ),
    ],
  );
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    this.semanticLabel,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final String? semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    label: semanticLabel ?? label,
    selected: selected,
    onPressed: onPressed,
    scale: 0.94,
    radius: 10,
    builder: (context, state) => AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.color),

      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? context.appColors.strongSelection
            : context.appColors.pill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected
              ? context.appColors.onStrongSelection
              : context.appColors.text,
        ),
      ),
    ),
  );
}
