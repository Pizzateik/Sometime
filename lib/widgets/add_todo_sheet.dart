import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../app/sometime_icons.dart';
import '../models/todo.dart';
import '../models/todo_space.dart' show isSameLocalDate;
import '../models/task_details.dart';
import '../utils/natural_datetime_parser.dart';
import 'add_todo_button.dart';
import 'pressable.dart';
import 'recognized_text_field.dart';
import 'todo_group_picker.dart';
import 'task_planning_fields.dart';
import 'sometime_action_icon.dart';

class AddTodoSheet extends StatefulWidget {
  const AddTodoSheet({
    required this.origin,
    required this.animation,
    required this.clock,
    this.morningReminderMinutes = 9 * 60,
    this.initialDraft,
    this.resolveOrigin,
    this.panelTop,
    super.key,
  });

  final Rect origin;
  final Animation<double> animation;
  final DateTime Function() clock;
  final int morningReminderMinutes;
  final TodoDraft? initialDraft;
  final Rect? Function()? resolveOrigin;
  final double? panelTop;

  static Future<TodoDraft?> show(
    BuildContext context,
    Rect origin, {
    required DateTime Function() clock,
    int morningReminderMinutes = 9 * 60,
    Rect? Function()? resolveOrigin,
    TodoDraft? initialDraft,
    double? panelTop,
  }) async {
    final route = _AddTodoRoute(
      origin: origin,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      clock: clock,
      morningReminderMinutes: morningReminderMinutes,
      resolveOrigin: resolveOrigin,
      initialDraft: initialDraft,
      panelTop: panelTop,
      closeLabel: context.strings.closeInput,
    );
    final result = await Navigator.of(context).push(route);
    // Keep the source button hidden until the reverse transition ends.
    await route.completed;
    return result;
  }

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoRoute extends PopupRoute<TodoDraft> {
  _AddTodoRoute({
    required this.origin,
    required this.reduceMotion,
    required this.clock,
    required this.morningReminderMinutes,
    this.resolveOrigin,
    this.initialDraft,
    this.panelTop,
    required this.closeLabel,
  });

  final Rect origin;
  final bool reduceMotion;
  final DateTime Function() clock;
  final int morningReminderMinutes;
  final Rect? Function()? resolveOrigin;
  final TodoDraft? initialDraft;
  final double? panelTop;
  final String closeLabel;

  @override
  Color get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => closeLabel;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : AppMotion.open;
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : AppMotion.close;
  @override
  Curve get barrierCurve => AppMotion.curve;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AddTodoSheet(
      origin: origin,
      animation: animation,
      clock: clock,
      morningReminderMinutes: morningReminderMinutes,
      resolveOrigin: resolveOrigin,
      initialDraft: initialDraft,
      panelTop: panelTop,
    );
  }
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  late final TextEditingController _textController;
  late final TextEditingController _descriptionController;
  late TaskDetails _details;
  bool _dateLocked = false;
  bool _timeLocked = false;
  bool _isPinned = false;
  int _datePulse = 0;
  int _timePulse = 0;
  List<TextRange> _titleRecognitionRanges = const [];
  List<TextRange> _descriptionRecognitionRanges = const [];
  final _focusNode = FocusNode(debugLabel: 'Task title');
  late TodoGroup _group;
  bool _closing = false;
  bool _submitted = false;
  double _displayedKeyboard = 0;
  double _frozenKeyboard = 0;
  double _panelDrag = 0;
  bool _panelDragging = false;

  Timer? _parseDebounceTimer;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialDraft?.title);
    _details = widget.initialDraft?.details ?? const TaskDetails();
    _dateLocked = _details.date != null;
    _timeLocked = _details.minutes != null;
    _isPinned = widget.initialDraft?.isPinned ?? false;
    _descriptionController = TextEditingController(text: _details.description);
    _group = widget.initialDraft?.group ?? TodoGroup.today;
    _textController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    widget.animation.addStatusListener(_onAnimationStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.animation.isCompleted) _focusNode.requestFocus();
    });
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _focusNode.requestFocus();
    } else if (status == AnimationStatus.reverse) {
      setState(() {
        _closing = true;
        _frozenKeyboard = _displayedKeyboard;
      });
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _submit() {
    _parseDebounceTimer?.cancel();
    _parseDateTime();
    final title = _textController.text.trim();
    if (_submitted || _closing || title.isEmpty) return;
    _submitted = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      TodoDraft(
        title: title,
        group: _group,
        details: TaskDetails(
          description: _descriptionController.text.trim(),
          date: _details.date,
          minutes: _details.minutes,
          recurrence: _details.recurrence,
          reminder: _details.effectiveReminder,
        ),
        isPinned: _isPinned,
      ),
    );
  }

  void _onTextChanged() {
    _parseDebounceTimer?.cancel();
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) {
      _parseDateTime();
      return;
    }
    _parseDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _parseDateTime();
    });
  }

  void _parseDateTime() {
    if (!mounted) return;
    if (_dateLocked && _timeLocked) {
      if (_titleRecognitionRanges.isEmpty &&
          _descriptionRecognitionRanges.isEmpty) {
        return;
      }
      setState(() {
        _titleRecognitionRanges = const [];
        _descriptionRecognitionRanges = const [];
      });
      return;
    }
    final suggestion = NaturalDateTimeParser.parse(
      title: _textController.text,
      description: _descriptionController.text,
      now: widget.clock(),
      languageCode: context.strings.locale.languageCode,
      morningReminderMinutes: widget.morningReminderMinutes,
    );
    var date = _details.date;
    var minutes = _details.minutes;
    if (!_dateLocked &&
        suggestion.date != null &&
        !_sameDate(date, suggestion.date!)) {
      date = suggestion.date;
    }
    if (!_timeLocked &&
        suggestion.minutes != null &&
        minutes != suggestion.minutes) {
      minutes = suggestion.minutes;
    }
    final dateChanged = !_sameDate(date, _details.date);
    final timeChanged = minutes != _details.minutes;
    final activeSourceRanges = <NaturalDateTimeSourceRange>[
      if (!_dateLocked && suggestion.date != null) ?suggestion.dateSourceRange,
      if (!_timeLocked && suggestion.minutes != null)
        ?suggestion.timeSourceRange,
    ];
    final titleRanges = _rangesFor(
      NaturalDateTimeSource.title,
      _textController.text,
      activeSourceRanges,
    );
    final descriptionRanges = _rangesFor(
      NaturalDateTimeSource.description,
      _descriptionController.text,
      activeSourceRanges,
    );
    final rangesChanged =
        !_sameRanges(titleRanges, _titleRecognitionRanges) ||
        !_sameRanges(descriptionRanges, _descriptionRecognitionRanges);
    if (!dateChanged && !timeChanged && !rangesChanged) return;
    setState(() {
      if (dateChanged) _datePulse++;
      if (timeChanged) _timePulse++;
      _details = TaskDetails(
        description: _details.description,
        date: date,
        minutes: minutes,
        recurrence: _details.recurrence,
        reminder: _details.reminder,
      );
      _titleRecognitionRanges = titleRanges;
      _descriptionRecognitionRanges = descriptionRanges;
    });
  }

  static List<TextRange> _rangesFor(
    NaturalDateTimeSource source,
    String text,
    List<NaturalDateTimeSourceRange> ranges,
  ) => NaturalDateTimeParser.mergeSourceRanges(
    text: text,
    ranges: ranges.where((range) => range.source == source),
  ).map((range) => TextRange(start: range.start, end: range.end)).toList();

  static bool _sameRanges(List<TextRange> first, List<TextRange> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _sameDate(DateTime? first, DateTime? second) {
    if (first == null || second == null) return first == second;
    return isSameLocalDate(first, second);
  }

  void _lockDate() {
    if (!mounted) return;
    setState(() => _dateLocked = true);
    _parseDateTime();
  }

  void _unlockDate() {
    if (!mounted) return;
    setState(() => _dateLocked = false);
    _parseDateTime();
  }

  void _lockTime() {
    if (!mounted) return;
    setState(() => _timeLocked = true);
    _parseDateTime();
  }

  void _unlockTime() {
    if (!mounted) return;
    setState(() => _timeLocked = false);
    _parseDateTime();
  }

  @override
  void dispose() {
    _parseDebounceTimer?.cancel();
    widget.animation.removeStatusListener(_onAnimationStatus);
    _textController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _textController.dispose();
    _descriptionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.appColors;
    final keyboard = _closing ? _frozenKeyboard : media.viewInsets.bottom;
    return PopScope(
      canPop: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: appSystemUiFor(context),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: widget.initialDraft?.title.isNotEmpty != true
              ? context.strings.newTask
              : context.strings.editTask,
          explicitChildNodes: true,
          child: LayoutBuilder(
            builder: (context, constraints) => TweenAnimationBuilder<double>(
              tween: Tween(end: keyboard),
              duration: AppMotion.duration(context, AppMotion.complete),
              curve: AppMotion.curve,
              builder: (context, keyboardInset, _) {
                _displayedKeyboard = keyboardInset;
                final width = math.min(
                  constraints.maxWidth - media.viewPadding.horizontal - 16,
                  AppSpace.contentWidth,
                );
                final safeBottom = keyboardInset > 0
                    ? 0.0
                    : media.viewPadding.bottom;
                final top = widget.panelTop ?? media.viewPadding.top + 88;
                final height = math.max(0.0, constraints.maxHeight - top - 8);
                final destination = Rect.fromLTWH(
                  media.viewPadding.left +
                      (constraints.maxWidth -
                              media.viewPadding.horizontal -
                              width) /
                          2,
                  top,
                  width,
                  height,
                );

                return AnimatedBuilder(
                  animation: widget.animation,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: keyboardInset + safeBottom,
                      ),
                      child: _buildForm(context),
                    ),
                  ),
                  builder: (context, child) {
                    final curve = _closing
                        ? Curves.easeInCubic
                        : AppMotion.curve;
                    final progress = curve.transform(widget.animation.value);
                    final origin =
                        widget.resolveOrigin?.call() ?? widget.origin;
                    final rect = Rect.lerp(origin, destination, progress)!;
                    final radius = BorderRadius.lerp(
                      BorderRadius.circular(AddTodoButton.radius),
                      BorderRadius.circular(28),
                      progress,
                    )!;
                    final contentOpacity = const Interval(
                      0.32,
                      1,
                    ).transform(progress);
                    final iconOpacity =
                        1 - const Interval(0, 0.35).transform(progress);

                    return TweenAnimationBuilder<double>(
                      tween: Tween(end: _panelDrag),
                      duration: AppMotion.duration(
                        context,
                        _panelDragging ? Duration.zero : AppMotion.complete,
                      ),
                      curve: Curves.easeOutBack,
                      builder: (context, drag, _) => Transform.translate(
                        offset: Offset(0, drag),
                        child: Transform.scale(
                          scale: MediaQuery.disableAnimationsOf(context)
                              ? 1
                              : 1 -
                                    (drag / math.max(height, 1) * 0.025).clamp(
                                      0,
                                      0.025,
                                    ),
                          child: Stack(
                            children: [
                              Positioned.fromRect(
                                rect: rect,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: radius,
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.appColors.shadow
                                            .withValues(alpha: 0.12),
                                        blurRadius: lerpDouble(
                                          18,
                                          36,
                                          progress,
                                        )!,
                                        offset: Offset(
                                          0,
                                          lerpDouble(7, -4, progress)!,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: radius,
                                    child: ColoredBox(
                                      color: Color.lerp(
                                        context.appColors.accent,
                                        colors.creationSurface,
                                        const Interval(
                                          0,
                                          0.65,
                                        ).transform(progress),
                                      )!,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (iconOpacity > 0)
                                            Center(
                                              child: Opacity(
                                                opacity: iconOpacity,
                                                child: Transform.rotate(
                                                  angle: progress * math.pi / 4,
                                                  alignment: Alignment.center,
                                                  child: SometimeActionIconBox(
                                                    glyph: SometimeActionGlyph
                                                        .plus,
                                                    color: context
                                                        .appColors
                                                        .onAccent,
                                                    size: 26,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          OverflowBox(
                                            alignment: Alignment.topLeft,
                                            minWidth: width,
                                            maxWidth: width,
                                            minHeight: height,
                                            maxHeight: height,
                                            child: IgnorePointer(
                                              ignoring:
                                                  progress < 1 || _closing,
                                              child: Opacity(
                                                opacity: contentOpacity,
                                                child: Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    12 * (1 - contentOpacity),
                                                  ),
                                                  child: child,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.appColors;
    final titleStyle = context.appTypography.taskTitle.copyWith(
      fontSize: 26,
      height: 1.35,
    );
    final descriptionStyle = context.appTypography.secondary;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final form = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    onVerticalDragStart: (_) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _panelDragging = true);
                    },
                    onVerticalDragUpdate: (details) => setState(() {
                      _panelDrag = math.max(0, _panelDrag + details.delta.dy);
                    }),
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (_panelDrag > 120 || velocity > 850) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          _panelDragging = false;
                          _panelDrag = 0;
                        });
                      }
                    },
                    onVerticalDragCancel: () => setState(() {
                      _panelDragging = false;
                      _panelDrag = 0;
                    }),
                    child: SizedBox(
                      height: 20,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outline.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: RecognizedTextField(
                                    controller: _textController,
                                    ranges: _titleRecognitionRanges,
                                    textStyle: titleStyle,
                                    highlightColor: colors.recognitionHighlight,
                                    highlightKey: const ValueKey(
                                      'todo-title-recognition-highlight',
                                    ),
                                    child: TextField(
                                      key: const ValueKey('todo-title-field'),
                                      controller: _textController,
                                      focusNode: _focusNode,
                                      minLines: 1,
                                      maxLines: 3,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textInputAction: TextInputAction.done,
                                      keyboardType: TextInputType.text,
                                      keyboardAppearance: Theme.of(context)
                                          .brightness,
                                      inputFormatters: [
                                        FilteringTextInputFormatter
                                            .singleLineFormatter,
                                      ],
                                      cursorWidth: 1.5,
                                      cursorRadius: const Radius.circular(1),
                                      style: titleStyle,
                                      decoration: InputDecoration(
                                        hintText: context.strings.title,
                                        hintStyle: TextStyle(
                                          color: colors.secondary,
                                        ),
                                      ),
                                      onSubmitted: (_) => _focusNode.unfocus(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Pressable(
                                label: context.strings.closeInput,
                                onPressed: () => Navigator.of(context).pop(),
                                radius: 12,
                                builder: (context, state) => Container(
                                  width: AppSpace.touch,
                                  height: AppSpace.touch,
                                  decoration: BoxDecoration(
                                    color: state.pressed || state.hovered
                                        ? colors.track
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    SometimeIcons.x,
                                    size: 20,
                                    color: colors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RecognizedTextField(
                            controller: _descriptionController,
                            ranges: _descriptionRecognitionRanges,
                            textStyle: descriptionStyle,
                            highlightColor: colors.recognitionHighlight,
                            highlightKey: const ValueKey(
                              'todo-description-recognition-highlight',
                            ),
                            child: TextField(
                              key: const ValueKey('todo-description-field'),
                              controller: _descriptionController,
                              minLines: 1,
                              maxLines: 3,
                              maxLength: 300,
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.sentences,
                              cursorWidth: 1.5,
                              cursorRadius: const Radius.circular(1),
                              style: descriptionStyle,
                              decoration: InputDecoration(
                                hintText: context.strings.description,
                                counterText: '',
                                hintStyle: TextStyle(color: colors.secondary),
                              ),
                              onSubmitted: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xl),
                          TodoGroupPicker(
                            value: _group,
                            onChanged: (value) =>
                                setState(() => _group = value),
                          ),
                          const SizedBox(height: AppSpace.xl),
                          TaskPlanningFields(
                            value: _details,
                            datePulse: _datePulse,
                            timePulse: _timePulse,
                            isPinned: _isPinned,
                            clock: widget.clock,
                            onDateSelected: _lockDate,
                            onDateCleared: _unlockDate,
                            onTimeSelected: _lockTime,
                            onTimeCleared: _unlockTime,
                            onChanged: (value) {
                              if (mounted) setState(() => _details = value);
                            },
                            onPinChanged: (value) {
                              if (mounted) setState(() => _isPinned = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, _) {
                        final canSubmit = value.text.trim().isNotEmpty;
                        return Pressable(
                          radius: AddTodoButton.radius,
                          label: widget.initialDraft?.title.isNotEmpty != true
                              ? context.strings.addTask
                              : context.strings.saveChanges,
                          onPressed: canSubmit ? _submit : null,
                          builder: (context, state) => AnimatedContainer(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.color,
                            ),
                            width: AddTodoButton.width,
                            height: AddTodoButton.height,
                            decoration: BoxDecoration(
                              color: canSubmit
                                  ? context.appColors.accent
                                  : colors.track,
                              borderRadius: BorderRadius.circular(
                                AddTodoButton.radius,
                              ),
                            ),
                            child: SometimeActionIconBox(
                              glyph: SometimeActionGlyph.arrowUp,
                              size: 22,
                              color: canSubmit
                                  ? context.appColors.onAccent
                                  : colors.secondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
              if (constraints.maxHeight < 180) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: SizedBox(height: 260, child: form),
                );
              }
              return form;
            },
          ),
        ),
      ),
    );
  }
}
