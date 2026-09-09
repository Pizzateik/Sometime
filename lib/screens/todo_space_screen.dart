import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../services/notification_service.dart';
import '../services/app_haptics.dart';
import '../services/task_pin_coordinator.dart';
import '../app/todo_date_formatter.dart';
import '../models/todo.dart';
import '../state/todo_controller.dart';

import '../widgets/add_todo_sheet.dart';
import '../widgets/completed_section.dart';
import '../widgets/bottom_pinned_sliver.dart';
import '../widgets/dissolving_todo.dart';
import '../widgets/dashed_divider.dart';
import '../widgets/first_task_edit_tutorial.dart';
import '../widgets/todo_section.dart';
import '../widgets/todo_item.dart';

class TodoSpaceScreen extends StatefulWidget {
  const TodoSpaceScreen({
    required this.spaceId,
    required this.controller,
    required this.activePage,
    this.buttonBounds,
    this.focusTaskId,
    this.panelTop,
    this.onDragChanged,
    this.onDeleteHoverChanged,
    this.onDeleteMagnetChanged,
    this.onEditorVisibilityChanged,
    this.taskTutorialId,
    this.onTaskTutorialDismissed,
    this.dateFormatter = const TodoDateFormatter(),
    this.morningReminderMinutes = 9 * 60,
    this.showPermanentEmptyState = false,
    super.key,
  });

  final String spaceId;
  final String? focusTaskId;
  final TodoController controller;
  final bool activePage;
  final Rect? Function()? buttonBounds;
  final double? Function()? panelTop;
  final ValueChanged<bool>? onDragChanged, onDeleteHoverChanged;
  final ValueChanged<Offset>? onDeleteMagnetChanged;
  final ValueChanged<bool>? onEditorVisibilityChanged;
  final String? taskTutorialId;
  final VoidCallback? onTaskTutorialDismissed;
  final TodoDateFormatter dateFormatter;
  final int morningReminderMinutes;
  final bool showPermanentEmptyState;

  @override
  State<TodoSpaceScreen> createState() => _TodoSpaceScreenState();
}

class _TodoSpaceScreenState extends State<TodoSpaceScreen> {
  bool _longPressArmed = false;
  bool _deleteHovered = false;
  bool _deleteMagnetEngaged = false;
  OverlayEntry? _dissolveOverlay;
  final _scrollController = ScrollController();
  bool _composerOpen = false;
  bool _completedExpanded = false;
  final _completedKey = GlobalKey();
  bool _emptyStateMeasureScheduled = false;
  double _emptyStateHeight = 72;
  bool _pullFromActiveContent = false;
  bool _collapseArmed = false;
  bool _saveErrorShown = false;
  String? _activeTodoId;
  String? _visibleTaskTutorialId;
  final _tutorialLink = LayerLink();
  String? _draggingTodoId;
  final _sectionKeys = {
    for (final group in TodoGroup.values) group: GlobalKey(),
  };
  final _rowKeys = <String, GlobalKey>{};
  Timer? _dragTimer;
  Offset? _pointer;
  Offset? _pointerDown;
  int? _pointerId;
  Offset _grabOffset = Offset.zero;
  Rect? _dragBounds;
  Todo? _dragTodo;
  TodoGroup? _targetGroup;
  int _targetIndex = 0;
  TodoGroup? _sourceGroup;
  int _sourceIndex = 0;
  OverlayEntry? _dragOverlay;
  String? _insertedId;
  GlobalKey? _insertedKey;
  late Set<String> _knownTodoIds;

  @override
  void initState() {
    super.initState();
    _knownTodoIds = widget.controller
        .spaceById(widget.spaceId)
        .todos
        .map((todo) => todo.id)
        .toSet();
    final taskTutorialId = widget.taskTutorialId;
    if (taskTutorialId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _prepareTaskTutorial(taskTutorialId),
      );
    }
  }

  @override
  void dispose() {
    _dragTimer?.cancel();
    _dragOverlay?.remove();
    _dissolveOverlay?.remove();
    _scrollController.dispose();
    _rowKeys.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(TodoSpaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.taskTutorialId != oldWidget.taskTutorialId) {
      if (widget.taskTutorialId == null) {
        _visibleTaskTutorialId = null;
      } else {
        final taskId = widget.taskTutorialId!;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _prepareTaskTutorial(taskId),
        );
      }
    }
    if (widget.focusTaskId != null &&
        widget.focusTaskId != oldWidget.focusTaskId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final row = _rowKeys[widget.focusTaskId]?.currentContext;
        if (row != null) {
          setState(() => _activeTodoId = widget.focusTaskId);
          Scrollable.ensureVisible(
            row,
            duration: AppMotion.open,
            alignment: 0.35,
          );
        }
      });
    }
    final ids = widget.controller
        .spaceById(widget.spaceId)
        .todos
        .map((todo) => todo.id)
        .toSet();
    final added = ids.difference(_knownTodoIds);
    if (added.isNotEmpty) {
      _insertedId = added.last;
      _insertedKey = GlobalKey();
      _activeTodoId = null;
    }
    _knownTodoIds = ids;
    if (oldWidget.activePage && !widget.activePage) {
      final hadTutorial = _visibleTaskTutorialId != null;
      _visibleTaskTutorialId = null;
      if (hadTutorial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onTaskTutorialDismissed?.call();
        });
      }
      _endDrag(cancel: true);
      _activeTodoId = null;
      _completedExpanded = false;
      _pullFromActiveContent = false;
      _collapseArmed = false;
    }
    if (widget.controller.saveFailed && !_saveErrorShown) {
      _saveErrorShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.strings.taskSaveError),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: context.strings.retry,
                onPressed: () => unawaited(widget.controller.retrySave()),
              ),
            ),
          );
      });
    } else if (!widget.controller.saveFailed) {
      _saveErrorShown = false;
    }
  }

  void _prepareTaskTutorial(String taskId) {
    if (!mounted || widget.taskTutorialId != taskId || !widget.activePage) {
      return;
    }
    final todo = widget.controller
        .spaceById(widget.spaceId)
        .todos
        .where((todo) => todo.id == taskId && !todo.isComplete)
        .firstOrNull;
    if (todo == null) return;
    final row = _rowKeys[taskId]?.currentContext;
    setState(() {
      _activeTodoId = taskId;
      _visibleTaskTutorialId = taskId;
    });
    if (row != null) {
      unawaited(
        Scrollable.ensureVisible(
          row,
          duration: AppMotion.open,
          curve: AppMotion.curve,
          alignment: 0.35,
        ),
      );
    }
  }

  void _dismissTaskTutorial() {
    if (_visibleTaskTutorialId == null) return;
    setState(() => _visibleTaskTutorialId = null);
    widget.onTaskTutorialDismissed?.call();
  }

  Rect _editorOrigin() {
    final button = widget.buttonBounds?.call();
    if (button != null) return button;
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width - 80, size.height - 80, 56, 56);
  }

  Future<void> _openEditor(Todo todo) async {
    if (_composerOpen) return;
    widget.onEditorVisibilityChanged?.call(true);
    setState(() {
      _composerOpen = true;
      _activeTodoId = null;
    });
    final draft = await AddTodoSheet.show(
      context,
      _editorOrigin(),
      clock: widget.controller.clock,
      resolveOrigin: widget.buttonBounds,
      panelTop: widget.panelTop?.call(),
      morningReminderMinutes: widget.morningReminderMinutes,
      initialDraft: TodoDraft(
        title: todo.title,
        group: todo.group,
        details: todo.details,
        isPinned: todo.isPinned,
      ),
    );
    if (!mounted) return;
    widget.onEditorVisibilityChanged?.call(false);
    setState(() => _composerOpen = false);
    if (draft == null) return;
    final pinState = todo.isPinned;
    widget.controller.updateTodo(
      widget.spaceId,
      todo.id,
      draft.copyWith(isPinned: pinState),
    );
    try {
      await widget.controller.flush();
    } catch (_) {
      return;
    }
    if (draft.isPinned != pinState) {
      await applyTaskPinAfterSave(
        controller: widget.controller,
        spaceId: widget.spaceId,
        todoId: todo.id,
        currentPinned: pinState,
        targetPinned: draft.isPinned,
      );
    }
    if (mounted) setState(() => _activeTodoId = null);
  }

  void _toggle(Todo todo) {
    final completed = widget.controller.completedTodos(widget.spaceId);
    if (!todo.isComplete && completed.isEmpty) {
      _completedExpanded = false;
    } else if (todo.isComplete && completed.length == 1) {
      _completedExpanded = false;
    }
    _activeTodoId = null;
    widget.controller.toggleTodo(widget.spaceId, todo.id);
  }

  void _handleTodoTap(Todo todo) {
    if (_activeTodoId != null) {
      setState(() => _activeTodoId = null);
      return;
    }
    _toggle(todo);
  }

  void _activateTodo(Todo todo) {
    if (todo.isComplete) return;
    _longPressArmed = true;
    setState(() => _activeTodoId = todo.id);
  }

  void _clearActiveTodo() {
    if (!mounted || _activeTodoId == null) return;
    setState(() => _activeTodoId = null);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        !_completedExpanded ||
        !_pullFromActiveContent ||
        _draggingTodoId != null) {
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final pull =
          notification.metrics.minScrollExtent - notification.metrics.pixels;
      final armed = pull >= 42;
      if (_collapseArmed != armed) {
        setState(() => _collapseArmed = armed);
      }
    }
    return false;
  }

  Rect? _bounds(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _startDrag(Todo todo) {
    if (_draggingTodoId != null || todo.isComplete) return;
    _dragBounds = _bounds(_rowKeys[todo.id]);
    if (_dragBounds == null) return;
    _dragTodo = todo;
    _pointer = _pointerDown ?? _dragBounds!.center;
    _grabOffset = _pointer! - _dragBounds!.topLeft;
    _targetGroup = todo.group;
    _targetIndex = widget.controller
        .activeTodos(widget.spaceId, todo.group)
        .indexWhere((entry) => entry.id == todo.id);
    _sourceGroup = todo.group;
    _sourceIndex = _targetIndex;
    setState(() {
      _activeTodoId = todo.id;
      _draggingTodoId = todo.id;
    });
    widget.onDragChanged?.call(true);
    _dragOverlay = OverlayEntry(
      builder: (context) {
        final position = _pointer! - _grabOffset;
        return Positioned(
          left: position.dx,
          top: position.dy,
          width: _dragBounds!.width,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.none,
              child: TodoItem(
                todo: todo,
                active: true,
                dragging: true,
                deleteHovered: _deleteHovered,
                onToggle: () {},
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_dragOverlay!);
    _dragTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_pointer == null || !mounted || _deleteHovered) return;
      _autoScroll(_pointer!);
      _resolveTarget(_pointer!);
    });
  }

  void _updateDrag(Offset position) {
    if (_draggingTodoId == null) return;
    _pointer = position;
    _dragOverlay?.markNeedsBuild();
    final target = widget.buttonBounds?.call()?.inflate(28);
    final hovered = target?.contains(position) ?? false;
    if (_deleteHovered != hovered) {
      _deleteHovered = hovered;
      widget.onDeleteHoverChanged?.call(hovered);
      _dragOverlay?.markNeedsBuild();
      if (hovered) AppHaptics.strong();
    }
    _updateDeleteMagnet(position, target);
    if (!hovered) _resolveTarget(position);
  }

  void _updateDeleteMagnet(Offset position, Rect? target) {
    if (target == null) return;
    final dx = position.dx < target.left
        ? target.left - position.dx
        : position.dx > target.right
        ? position.dx - target.right
        : 0.0;
    final dy = position.dy < target.top
        ? target.top - position.dy
        : position.dy > target.bottom
        ? position.dy - target.bottom
        : 0.0;
    final distance = Offset(dx, dy).distance;
    final range = _deleteMagnetEngaged ? 160.0 : 120.0;
    if (distance > range) {
      _deleteMagnetEngaged = false;
      widget.onDeleteMagnetChanged?.call(Offset.zero);
      return;
    }
    _deleteMagnetEngaged = true;
    final direction = position - target.center;
    final length = direction.distance;
    if (length == 0) return;
    final pull = (1 - distance / range).clamp(0.0, 1.0);
    widget.onDeleteMagnetChanged?.call(direction / length * (2.5 + 4.5 * pull));
  }

  void _resolveTarget(Offset position) {
    final sections = [
      for (final group in TodoGroup.values)
        (group: group, bounds: _bounds(_sectionKeys[group])),
    ];
    if (sections.any((entry) => entry.bounds == null)) return;
    var group = sections.first.group;
    for (var i = 1; i < sections.length; i++) {
      final boundary =
          (sections[i - 1].bounds!.bottom + sections[i].bounds!.top) / 2;
      if (position.dy >= boundary) group = sections[i].group;
    }
    final todos = widget.controller
        .activeTodos(widget.spaceId, group)
        .where((todo) => todo.id != _draggingTodoId)
        .toList();
    var index = 0;
    for (final todo in todos) {
      final bounds = _bounds(_rowKeys[todo.id]);
      if (bounds != null && position.dy > bounds.center.dy) index++;
    }
    final categoryChanged = _targetGroup != null && _targetGroup != group;
    if (_targetGroup == group && _targetIndex == index) return;
    setState(() {
      _targetGroup = group;
      _targetIndex = index;
    });
    if (categoryChanged) AppHaptics.selection();
  }

  void _endDrag({bool cancel = false}) {
    if (_draggingTodoId == null) return;
    final todo = _dragTodo!;
    final delete = !cancel && _deleteHovered;
    if (delete) _showDissolve(todo);
    final group = _targetGroup!;
    final moved = group != _sourceGroup || _targetIndex != _sourceIndex;
    var index = _targetIndex;
    final source = widget.controller.activeTodos(widget.spaceId, todo.group);
    final oldIndex = source.indexWhere((entry) => entry.id == todo.id);
    if (todo.group == group && oldIndex <= index) index++;
    _dragTimer?.cancel();
    _dragOverlay?.remove();
    _dragOverlay = null;
    setState(() {
      _draggingTodoId = null;
      _dragTodo = null;
      _pointer = null;
      if (delete || (!cancel && moved)) _activeTodoId = null;
    });
    _deleteHovered = false;
    _deleteMagnetEngaged = false;
    widget.onDeleteHoverChanged?.call(false);
    widget.onDeleteMagnetChanged?.call(Offset.zero);
    widget.onDragChanged?.call(false);
    if (delete) {
      widget.controller.deleteTodo(widget.spaceId, todo.id);
    } else if (!cancel && moved) {
      widget.controller.moveTodo(
        widget.spaceId,
        todo.id,
        group: group,
        index: index,
      );
    }
  }

  void _showDissolve(Todo todo) {
    _dissolveOverlay?.remove();
    final position = _pointer! - _grabOffset;
    final width = _dragBounds!.width;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy,
        width: width,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: DissolvingTodo(
              onEnd: () {
                if (_dissolveOverlay != entry) return;
                entry.remove();
                _dissolveOverlay = null;
              },
              child: TodoItem(todo: todo, active: true, onToggle: () {}),
            ),
          ),
        ),
      ),
    );
    _dissolveOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _autoScroll(Offset globalPosition) {
    if (!_scrollController.hasClients) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final localY = box.globalToLocal(globalPosition).dy;
    const topEdge = 72.0;
    final bottomEdge = box.size.height - 96;
    var delta = 0.0;
    if (localY < topEdge) {
      delta = -5 * ((topEdge - localY) / topEdge).clamp(0.35, 1.0);
    } else if (localY > bottomEdge) {
      delta =
          5 *
          ((localY - bottomEdge) / (box.size.height - bottomEdge)).clamp(
            0.35,
            1.0,
          );
    }
    if (delta == 0) return;
    final position = _scrollController.position;
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  List<Todo> _visibleOrder(TodoGroup group) {
    final todos = widget.controller.activeTodos(widget.spaceId, group).toList();
    if (_dragTodo == null) return todos;
    todos.removeWhere((todo) => todo.id == _draggingTodoId);
    if (_targetGroup == group) {
      todos.insert(_targetIndex.clamp(0, todos.length), _dragTodo!);
    }
    return todos;
  }

  void _revealInsertedTodo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final itemContext = _insertedKey?.currentContext;
      if (itemContext == null ||
          itemContext.findRenderObject()?.attached != true) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          itemContext,
          duration: AppMotion.duration(context, AppMotion.close),
          curve: AppMotion.curve,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  void _scheduleEmptyStateMeasurement() {
    if (_emptyStateMeasureScheduled) return;
    _emptyStateMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emptyStateMeasureScheduled = false;
      if (!mounted) return;
      final lastSection = _bounds(_sectionKeys[TodoGroup.someday]);
      if (lastSection == null) return;
      final screenBottom =
          MediaQuery.sizeOf(context).height -
          MediaQuery.viewPaddingOf(context).bottom;
      final completed = _bounds(_completedKey);
      final contentBottom = completed == null
          ? screenBottom
          : screenBottom - AppSpace.xl - AppSpace.xl - completed.height;
      final available = contentBottom - lastSection.bottom;
      final nextHeight = math.max(72.0, available);
      if ((nextHeight - _emptyStateHeight).abs() < 0.5) return;
      setState(() => _emptyStateHeight = nextHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTodos = widget.controller.spaceById(widget.spaceId).todos;
    if (_rowKeys.isNotEmpty) {
      final currentIds = {for (final todo in currentTodos) todo.id};
      _rowKeys.removeWhere((id, _) => !currentIds.contains(id));
    }
    final completed = widget.controller.completedTodos(widget.spaceId);
    final hasActiveTodos = TodoGroup.values.any(
      (group) =>
          widget.controller.activeTodos(widget.spaceId, group).isNotEmpty,
    );
    final showEmptyState = widget.showPermanentEmptyState && !hasActiveTodos;
    if (showEmptyState) _scheduleEmptyStateMeasurement();
    final date = widget.dateFormatter.format(
      widget.controller.currentLocalDate,
      Localizations.localeOf(context),
    );
    final tutorialWidth =
        (MediaQuery.sizeOf(context).width -
                MediaQuery.viewPaddingOf(context).horizontal -
                32)
            .clamp(1.0, AppSpace.contentWidth - 32)
            .toDouble();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpace.contentWidth),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _activeTodoId == null ? null : _clearActiveTodo,
              child: Listener(
                onPointerDown: (event) {
                  _dismissTaskTutorial();
                  if (_pointerId != null) return;
                  _pointerId = event.pointer;
                  _pointerDown = event.position;
                  final completedBounds = _bounds(_completedKey);
                  _pullFromActiveContent =
                      _completedExpanded &&
                      completedBounds != null &&
                      event.position.dy < completedBounds.top;
                  _collapseArmed = false;
                },
                onPointerMove: (event) {
                  if (event.pointer != _pointerId) return;
                  if (_longPressArmed &&
                      _draggingTodoId == null &&
                      _activeTodoId != null &&
                      _pointerDown != null &&
                      (event.position - _pointerDown!).distance > 6) {
                    final todo = widget.controller
                        .spaceById(widget.spaceId)
                        .todos
                        .where((todo) => todo.id == _activeTodoId)
                        .firstOrNull;
                    if (todo == null) return;
                    _startDrag(todo);
                  }
                  _updateDrag(event.position);
                },
                onPointerUp: (event) {
                  if (event.pointer != _pointerId) return;
                  if (_collapseArmed && _draggingTodoId == null) {
                    setState(() {
                      _completedExpanded = false;
                      _collapseArmed = false;
                    });
                  }
                  _pullFromActiveContent = false;
                  _endDrag();
                  _pointerId = null;
                  _longPressArmed = false;
                },
                onPointerCancel: (event) {
                  if (event.pointer != _pointerId) return;
                  _endDrag(cancel: true);
                  _pullFromActiveContent = false;
                  if (_collapseArmed) setState(() => _collapseArmed = false);
                  _pointerId = null;
                  _longPressArmed = false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    key: PageStorageKey('todo-scroll-${widget.spaceId}'),
                    controller: _scrollController,
                    physics: _completedExpanded
                        ? const _CompletedScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          )
                        : const _TodoScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final group in TodoGroup.values) ...[
                                TodoSection(
                                  key: _sectionKeys[group],
                                  group: group,
                                  trailing: group == TodoGroup.today
                                      ? date
                                      : null,
                                  todos: _visibleOrder(group),
                                  activeTodoId: _activeTodoId,
                                  draggingTodoId: _draggingTodoId,
                                  isExiting:
                                      widget.controller.isCompletionExiting,
                                  onToggle: _handleTodoTap,
                                  onActivate: _activateTodo,
                                  onDeactivate: _clearActiveTodo,
                                  onEdit: _openEditor,
                                  onPin: (todo) async {
                                    var succeeded = true;
                                    if (!todo.isPinned) {
                                      succeeded =
                                          await NotificationService.current
                                              ?.requestPermission() ??
                                          false;
                                    }
                                    if (!mounted) return false;
                                    widget.controller.setPinned(
                                      widget.spaceId,
                                      todo.id,
                                      !todo.isPinned,
                                    );
                                    return succeeded;
                                  },
                                  onDragStarted: _startDrag,
                                  onDragUpdate: _updateDrag,
                                  onDragEnd: _endDrag,
                                  rowKeys: _rowKeys,
                                  insertedId: _insertedId,
                                  insertedKey: _insertedKey,
                                  onInsertEnd: _revealInsertedTodo,
                                  tutorialTaskId: _visibleTaskTutorialId,
                                  tutorialLink: _tutorialLink,
                                ),
                                if (group != TodoGroup.someday) ...[
                                  const SizedBox(height: AppSpace.md),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpace.md,
                                    ),
                                    child: DashedDivider(),
                                  ),
                                  const SizedBox(height: AppSpace.xxl),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (showEmptyState)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: _emptyStateHeight,
                            child: Center(
                              child: Text(
                                context.strings.emptySpace,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.appColors.secondary,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      if (completed.isNotEmpty)
                        BottomPinnedSliver(
                          bottomInset: AppSpace.xl,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                            child: CompletedSection(
                              key: _completedKey,
                              collapseArmed: _collapseArmed,
                              todos: completed,
                              expanded: _completedExpanded,
                              dragging: _draggingTodoId != null,
                              noticeVisible: widget.controller.canUndoDeletion,
                              onToggleExpanded: () {
                                _clearActiveTodo();
                                setState(
                                  () =>
                                      _completedExpanded = !_completedExpanded,
                                );
                              },
                              onToggleTodo: _toggle,
                            ),
                          ),
                        )
                      else if (!showEmptyState)
                        SliverToBoxAdapter(child: const SizedBox(height: 104)),
                    ],
                  ),
                ),
              ),
            ),
            if (_visibleTaskTutorialId != null)
              OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: CompositedTransformFollower(
                  link: _tutorialLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.topLeft,
                  offset: const Offset(0, 12),
                  child: SizedBox(
                    width: tutorialWidth,
                    child: FirstTaskEditTutorial(
                      key: const ValueKey('first-task-edit-tutorial'),
                      showPin:
                          !kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.android,
                      onDismiss: _dismissTaskTutorial,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompletedScrollPhysics extends BouncingScrollPhysics {
  const _CompletedScrollPhysics({super.parent});

  @override
  _CompletedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _CompletedScrollPhysics(parent: buildParent(ancestor));

  @override
  double frictionFactor(double overscrollFraction) =>
      super.frictionFactor(overscrollFraction) * 0.45;
}

class _TodoScrollPhysics extends BouncingScrollPhysics {
  const _TodoScrollPhysics({super.parent});

  @override
  _TodoScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _TodoScrollPhysics(parent: buildParent(ancestor));

  @override
  double frictionFactor(double overscrollFraction) =>
      super.frictionFactor(overscrollFraction) * 0.7;
}
