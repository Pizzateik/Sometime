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

const _headerToFirstSectionGap = 24.0;
const _sectionToDividerGap = 8.0;
const _dividerToSectionGap = 24.0;

@immutable
class CrossSpaceDropTarget {
  const CrossSpaceDropTarget({required this.group, required this.index});

  final TodoGroup group;
  final int index;
}

@immutable
class TaskDragStartDetails {
  const TaskDragStartDetails({
    required this.sourceSpaceId,
    required this.todo,
    required this.pointer,
    required this.feedbackBounds,
    required this.grabOffset,
    required this.sourceGroup,
    required this.sourceIndex,
  });

  final String sourceSpaceId;
  final Todo todo;
  final Offset pointer;
  final Rect feedbackBounds;
  final Offset grabOffset;
  final TodoGroup sourceGroup;
  final int sourceIndex;
}

class TodoSpaceScreen extends StatefulWidget {
  const TodoSpaceScreen({
    required this.spaceId,
    required this.controller,
    required this.activePage,
    this.buttonBounds,
    this.focusTaskId,
    this.panelTop,
    this.onDragChanged,
    this.onTaskDragStart,
    this.onTaskDragUpdate,
    this.onTaskDragEnd,
    this.onDeleteHoverChanged,
    this.onDeleteMagnetChanged,
    this.onEditorVisibilityChanged,
    this.taskTutorialId,
    this.onTaskTutorialDismissed,
    this.dateFormatter = const TodoDateFormatter(),
    this.morningReminderMinutes = 9 * 60,
    this.showPermanentEmptyState = false,
    this.draggedTodo,
    this.dragSourceSpaceId,
    this.dragDestinationSpaceId,
    this.dragTargetGroup,
    this.dragTargetIndex,
    this.keepDragAlive = false,
    super.key,
  });

  final String spaceId;
  final String? focusTaskId;
  final TodoController controller;
  final bool activePage;
  final Rect? Function()? buttonBounds;
  final double? Function()? panelTop;
  final ValueChanged<bool>? onDragChanged, onDeleteHoverChanged;
  final ValueChanged<TaskDragStartDetails>? onTaskDragStart;
  final ValueChanged<Offset>? onTaskDragUpdate;
  final ValueChanged<bool>? onTaskDragEnd;
  final ValueChanged<Offset>? onDeleteMagnetChanged;
  final ValueChanged<bool>? onEditorVisibilityChanged;
  final String? taskTutorialId;
  final VoidCallback? onTaskTutorialDismissed;
  final TodoDateFormatter dateFormatter;
  final int morningReminderMinutes;
  final bool showPermanentEmptyState;
  final Todo? draggedTodo;
  final String? dragSourceSpaceId;
  final String? dragDestinationSpaceId;
  final TodoGroup? dragTargetGroup;
  final int? dragTargetIndex;
  final bool keepDragAlive;

  @override
  State<TodoSpaceScreen> createState() => TodoSpaceScreenState();
}

class TodoSpaceScreenState extends State<TodoSpaceScreen>
    with AutomaticKeepAliveClientMixin<TodoSpaceScreen> {
  bool _longPressArmed = false;
  bool _deleteHovered = false;
  bool _deleteMagnetEngaged = false;
  OverlayEntry? _dissolveOverlay;
  final _scrollController = ScrollController();
  bool _composerOpen = false;
  bool _completedExpanded = false;
  // Keep the pinned layout through the collapse animation. This prevents a
  // full-height completed list from jumping below the viewport for one frame.
  bool _completedLayoutExpanded = false;
  Timer? _completedLayoutTimer;
  final _completedKey = GlobalKey();
  final _dropSurfaceKey = GlobalKey();
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
  Offset? _pointer;
  Offset? _pointerDown;
  int? _pointerId;
  Offset _grabOffset = Offset.zero;
  Rect? _dragBounds;
  Todo? _dragTodo;
  String? _insertedId;
  GlobalKey? _insertedKey;
  late Set<String> _knownTodoIds;
  late bool _hadActiveTodos;
  bool _topResetScheduled = false;

  @override
  void initState() {
    super.initState();
    _knownTodoIds = widget.controller
        .spaceById(widget.spaceId)
        .todos
        .map((todo) => todo.id)
        .toSet();
    _hadActiveTodos = _spaceHasActiveTodos();
    if (widget.activePage && !_hadActiveTodos) _scheduleTopReset();
    final taskTutorialId = widget.taskTutorialId;
    if (taskTutorialId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _prepareTaskTutorial(taskTutorialId),
      );
    }
  }

  @override
  void dispose() {
    _completedLayoutTimer?.cancel();
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
    final currentSpace = widget.controller.spaceByIdOrNull(widget.spaceId);
    final ids =
        currentSpace?.todos.map((todo) => todo.id).toSet() ?? <String>{};
    if (_draggingTodoId != null && !ids.contains(_draggingTodoId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _endDrag(cancel: true);
      });
    }
    final added = ids.difference(_knownTodoIds);
    if (added.isNotEmpty) {
      _insertedId = added.last;
      _insertedKey = GlobalKey();
      _activeTodoId = null;
    }
    _knownTodoIds = ids;
    final hasActiveTodos = _spaceHasActiveTodos();
    if (widget.activePage &&
        ((!oldWidget.activePage && widget.activePage) ||
            (_hadActiveTodos && !hasActiveTodos)) &&
        !hasActiveTodos) {
      _scheduleTopReset();
    }
    _hadActiveTodos = hasActiveTodos;
    if (oldWidget.activePage && !widget.activePage && !widget.keepDragAlive) {
      final hadTutorial = _visibleTaskTutorialId != null;
      _visibleTaskTutorialId = null;
      if (hadTutorial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onTaskTutorialDismissed?.call();
        });
      }
      _endDrag(cancel: true);
      _activeTodoId = null;
      _resetCompletedLayout();
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
      _resetCompletedLayout();
    } else if (todo.isComplete && completed.length == 1) {
      _resetCompletedLayout();
    }
    _activeTodoId = null;
    widget.controller.toggleTodo(widget.spaceId, todo.id);
  }

  void _resetCompletedLayout() {
    _completedLayoutTimer?.cancel();
    _completedLayoutTimer = null;
    _completedExpanded = false;
    _completedLayoutExpanded = false;
  }

  void _setCompletedExpanded(bool expanded) {
    if (_completedExpanded == expanded) return;
    setState(() {
      _completedExpanded = expanded;
      if (expanded) {
        _completedLayoutTimer?.cancel();
        _completedLayoutTimer = null;
        _completedLayoutExpanded = true;
      }
    });
    if (!expanded) _scheduleCompletedLayoutTransition();
  }

  void _finishCompletedLayoutTransition() {
    _completedLayoutTimer = null;
    if (!mounted || _completedLayoutExpanded == _completedExpanded) return;
    setState(() => _completedLayoutExpanded = _completedExpanded);
  }

  void _scheduleCompletedLayoutTransition() {
    _completedLayoutTimer?.cancel();
    final duration = AppMotion.duration(context, AppMotion.color);
    if (duration == Duration.zero) {
      _finishCompletedLayoutTransition();
      return;
    }
    // Switch back after the shared size animation, not during its first frame.
    _completedLayoutTimer = Timer(
      duration + const Duration(milliseconds: 16),
      _finishCompletedLayoutTransition,
    );
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
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    return bounds.isFinite ? bounds : null;
  }

  CrossSpaceDropTarget? resolveTaskDropTarget(
    Offset position,
    TodoGroup sourceGroup,
    int sourceIndex,
    String draggedTodoId,
  ) {
    final space = widget.controller.spaceByIdOrNull(widget.spaceId);
    if (space == null) return null;
    final pageBounds = _bounds(_dropSurfaceKey);
    if (pageBounds == null || !pageBounds.contains(position)) return null;
    final sections = [
      for (final group in TodoGroup.values)
        (group: group, bounds: _bounds(_sectionKeys[group])),
    ];
    if (sections.any((entry) => entry.bounds == null)) return null;
    final firstSection = sections.first.bounds!;
    if (position.dy < firstSection.top) {
      final count = widget.controller
          .activeTodos(widget.spaceId, sourceGroup)
          .where((todo) => todo.id != draggedTodoId)
          .length;
      return CrossSpaceDropTarget(
        group: sourceGroup,
        index: sourceIndex.clamp(0, count),
      );
    }
    var group = sections.first.group;
    for (var i = 1; i < sections.length; i++) {
      final boundary =
          (sections[i - 1].bounds!.bottom + sections[i].bounds!.top) / 2;
      if (position.dy >= boundary) group = sections[i].group;
    }
    final todos = widget.controller
        .activeTodos(widget.spaceId, group)
        .where((todo) => todo.id != draggedTodoId);
    var index = 0;
    for (final todo in todos) {
      final bounds = _bounds(_rowKeys[todo.id]);
      if (bounds != null && position.dy > bounds.center.dy) index++;
    }
    return CrossSpaceDropTarget(group: group, index: index);
  }

  void updateExternalDrag(Offset position) {
    if (!_scrollController.hasClients) return;
    _autoScroll(position);
  }

  void cancelActiveDrag() => _endDrag(cancel: true);

  void _startDrag(Todo todo) {
    if (_draggingTodoId != null || todo.isComplete) return;
    _dragBounds = _bounds(_rowKeys[todo.id]);
    if (_dragBounds == null) return;
    _dragTodo = todo;
    _pointer = _pointerDown ?? _dragBounds!.center;
    _grabOffset = _pointer! - _dragBounds!.topLeft;
    final sourceIndex = widget.controller
        .activeTodos(widget.spaceId, todo.group)
        .indexWhere((entry) => entry.id == todo.id);
    setState(() {
      _activeTodoId = todo.id;
      _draggingTodoId = todo.id;
    });
    widget.onDragChanged?.call(true);
    widget.onTaskDragStart?.call(
      TaskDragStartDetails(
        sourceSpaceId: widget.spaceId,
        todo: todo,
        pointer: _pointer!,
        feedbackBounds: _dragBounds!,
        grabOffset: _grabOffset,
        sourceGroup: todo.group,
        sourceIndex: sourceIndex,
      ),
    );
  }

  void _updateDrag(Offset position) {
    if (_draggingTodoId == null) return;
    _pointer = position;
    final target = widget.buttonBounds?.call()?.inflate(28);
    final hovered = target?.contains(position) ?? false;
    if (_deleteHovered != hovered) {
      _deleteHovered = hovered;
      widget.onDeleteHoverChanged?.call(hovered);
      if (hovered) AppHaptics.strong();
    }
    _updateDeleteMagnet(position, target);
    widget.onTaskDragUpdate?.call(position);
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

  void _endDrag({bool cancel = false}) {
    if (_draggingTodoId == null) return;
    final todo = _dragTodo!;
    final delete = !cancel && _deleteHovered;
    if (delete) _showDissolve(todo);
    setState(() {
      _draggingTodoId = null;
      _dragTodo = null;
      _pointer = null;
      if (delete || !cancel) _activeTodoId = null;
    });
    _deleteHovered = false;
    _deleteMagnetEngaged = false;
    widget.onTaskDragEnd?.call(cancel);
    widget.onDeleteHoverChanged?.call(false);
    widget.onDeleteMagnetChanged?.call(Offset.zero);
    widget.onDragChanged?.call(false);
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
    final draggedTodo = widget.draggedTodo ?? _dragTodo;
    if (draggedTodo == null) return todos;
    final showsDrag =
        widget.dragSourceSpaceId == widget.spaceId ||
        widget.dragDestinationSpaceId == widget.spaceId;
    if (!showsDrag) return todos;
    todos.removeWhere((todo) => todo.id == draggedTodo.id);
    if (widget.dragDestinationSpaceId == widget.spaceId &&
        widget.dragTargetGroup == group) {
      todos.insert(
        (widget.dragTargetIndex ?? 0).clamp(0, todos.length),
        draggedTodo,
      );
    }
    return todos;
  }

  String? get _visibleDraggingTodoId {
    final draggedTodo = widget.draggedTodo;
    if (draggedTodo == null) return _draggingTodoId;
    if (widget.dragSourceSpaceId == widget.spaceId ||
        widget.dragDestinationSpaceId == widget.spaceId) {
      return draggedTodo.id;
    }
    return null;
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

  bool _spaceHasActiveTodos() => TodoGroup.values.any(
    (group) => widget.controller.activeTodos(widget.spaceId, group).isNotEmpty,
  );

  void _scheduleTopReset() {
    if (_topResetScheduled) return;
    _topResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _topResetScheduled = false;
      if (!mounted || !_scrollController.hasClients || _spaceHasActiveTodos()) {
        return;
      }
      final position = _scrollController.position;
      if ((position.pixels - position.minScrollExtent).abs() < 0.5) return;
      // Empty active categories always start at the top of the page.
      position.jumpTo(position.minScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentSpace = widget.controller.spaceByIdOrNull(widget.spaceId);
    if (currentSpace == null) return const SizedBox.shrink();
    final currentTodos = currentSpace.todos;
    if (_rowKeys.isNotEmpty) {
      final currentIds = {for (final todo in currentTodos) todo.id};
      _rowKeys.removeWhere((id, _) => !currentIds.contains(id));
    }
    final completed = widget.controller.completedTodos(widget.spaceId);
    final hasActiveTodos = _spaceHasActiveTodos();
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
      key: _dropSurfaceKey,
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
                      _collapseArmed = false;
                      _completedExpanded = false;
                    });
                    _scheduleCompletedLayoutTransition();
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
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          _headerToFirstSectionGap,
                          16,
                          0,
                        ),
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
                                  draggingTodoId: _visibleDraggingTodoId,
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
                                  const SizedBox(height: _sectionToDividerGap),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpace.md,
                                    ),
                                    child: DashedDivider(),
                                  ),
                                  const SizedBox(height: _dividerToSectionGap),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Keep the measured empty area outside the pinned child.
                      // Its first layout must not cause a scroll correction.
                      if (showEmptyState)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: _emptyStateHeight,
                            // The hint is decorative. Hide it before completed
                            // rows expand into the measured empty area.
                            child: _completedLayoutExpanded
                                ? const SizedBox.shrink()
                                : Center(
                                    child: Text(
                                      context.strings.emptySpace,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
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
                          // Completed tasks can use the measured empty area.
                          // The page stays at its top scroll position.
                          overlapBefore:
                              showEmptyState && _completedLayoutExpanded,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                            child: CompletedSection(
                              key: _completedKey,
                              collapseArmed: _collapseArmed,
                              todos: completed,
                              expanded: _completedExpanded,
                              dragging: _visibleDraggingTodoId != null,
                              noticeVisible: widget.controller.canUndoDeletion,
                              onToggleExpanded: () {
                                _clearActiveTodo();
                                _setCompletedExpanded(!_completedExpanded);
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

  @override
  bool get wantKeepAlive => true;
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
