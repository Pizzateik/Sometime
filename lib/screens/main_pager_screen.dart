import '../app/sometime_icons.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../services/app_haptics.dart';
import '../services/notification_service.dart';
import '../services/task_pin_coordinator.dart';
import '../services/widget_bridge.dart';
import '../models/todo.dart';
import '../models/todo_space.dart';
import '../state/theme_controller.dart';
import '../state/settings_controller.dart';
import '../state/todo_controller.dart';
import '../services/support_purchase_service.dart';
import '../widgets/pressable.dart';
import '../widgets/add_todo_button.dart';
import '../widgets/add_todo_sheet.dart';
import '../widgets/first_empty_home_hint.dart';
import '../widgets/sometime_input.dart';
import '../widgets/space_management_tutorial.dart';
import '../widgets/sometime_action_icon.dart';
import '../widgets/todo_item.dart';
import 'settings_screen.dart';
import 'todo_space_screen.dart';

class _TaskDragSession {
  _TaskDragSession(TaskDragStartDetails details)
    : sourceSpaceId = details.sourceSpaceId,
      todo = details.todo,
      pointer = details.pointer,
      feedbackBounds = details.feedbackBounds,
      grabOffset = details.grabOffset,
      sourceGroup = details.sourceGroup,
      sourceIndex = details.sourceIndex,
      destinationSpaceId = details.sourceSpaceId,
      targetGroup = details.sourceGroup,
      targetIndex = details.sourceIndex;

  final String sourceSpaceId;
  final Todo todo;
  final Rect feedbackBounds;
  final Offset grabOffset;
  final TodoGroup sourceGroup;
  final int sourceIndex;
  Offset pointer;
  String destinationSpaceId;
  TodoGroup targetGroup;
  int targetIndex;
  bool validDrop = false;
}

class MainPagerScreen extends StatefulWidget {
  const MainPagerScreen({
    required this.todoController,
    required this.themeController,
    required this.settingsController,
    required this.purchaseService,
    this.notifications,
    this.animateFirstEntrance = false,
    this.onFirstEntranceCompleted,
    super.key,
  });

  final TodoController todoController;
  final ThemeController themeController;
  final SettingsController settingsController;
  final SupportPurchaseService purchaseService;
  final NotificationService? notifications;
  final bool animateFirstEntrance;
  final VoidCallback? onFirstEntranceCompleted;

  @override
  State<MainPagerScreen> createState() => _MainPagerScreenState();
}

class _MainPagerScreenState extends State<MainPagerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController = PageController();
  late final AnimationController _firstEntrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final CurvedAnimation _firstStageHeader = _firstStage(0, 0.48);
  late final CurvedAnimation _firstStageBody = _firstStage(0.12, 0.78);
  late final CurvedAnimation _firstStageTutorialText = _firstStage(0.22, 0.62);
  late final CurvedAnimation _firstStageTutorialArrow = _firstStage(0.48, 0.92);
  late final CurvedAnimation _firstStageButton = _firstStage(0.35, 1);
  late final AnimationController _spaceDwellProgress = AnimationController(
    vsync: this,
    duration: crossSpaceDwellDuration,
  );
  int _currentPage = 0;
  bool _manageSpaces = false;
  bool _firstEntranceStarted = false;
  final _buttonKey = GlobalKey();
  final _headerKey = GlobalKey();
  final _spaceTutorialLink = LayerLink();
  final _spaceTutorialKey = GlobalKey();
  final _spaceNameKeys = <String, GlobalKey>{};
  final _emptyHintLayerKey = GlobalKey();
  Rect? _emptyHintButtonRect;
  bool _emptyHintMeasureScheduled = false;
  bool _firstEmptyHomeSessionStarted = false;
  String? _taskTutorialSpaceId;
  String? _taskTutorialId;
  bool _spaceTutorialVisible = false;
  bool _spaceTutorialPending = false;
  bool _spaceTutorialMeasurementScheduled = false;
  Rect? _spaceTutorialTargetRect;
  static const crossSpaceDwellDuration = Duration(milliseconds: 1050);
  Timer? _spaceDwellTimer;
  String? _hoveredSpaceId;
  bool _dragOverSpaceHeader = false;
  final _spacePageKeys = <String, GlobalKey<TodoSpaceScreenState>>{};
  _TaskDragSession? _taskDrag;
  OverlayEntry? _taskDragOverlay;
  Timer? _taskDragTickTimer;

  String? get _dragSourceSpaceId => _taskDrag?.sourceSpaceId;
  String? get _dragPreviewSpaceId => _taskDrag?.destinationSpaceId;

  String? _notificationTask;
  String? _lastNotificationProblem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenNotifications();
    widget.settingsController.addListener(_settingsChanged);
    widget.todoController.addListener(_validateDragState);
    _spaceDwellProgress.addListener(_refreshTaskDragOverlay);
    WidgetBridge.target.addListener(_widgetOpened);
    WidgetsBinding.instance.addPostFrameCallback((_) => _widgetOpened());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_firstEmptyHomeSessionStarted && _hasNoTasks && _isFirstHomeEligible) {
      _firstEmptyHomeSessionStarted = true;
    }
    if (_firstEntranceStarted) return;
    _firstEntranceStarted = true;
    if (!widget.animateFirstEntrance) {
      _firstEntrance.value = 1;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _firstEntrance.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFirstEntranceCompleted?.call();
      });
      return;
    }
    _firstEntrance.forward().whenComplete(() {
      if (mounted) widget.onFirstEntranceCompleted?.call();
    });
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

  bool _settingsSaveProblem = false;

  void _settingsChanged() {
    if (!mounted) return;
    final failed = widget.settingsController.saveFailed;
    if (failed && !_settingsSaveProblem) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.settingsSaveError),
          action: SnackBarAction(
            label: context.strings.retry,
            onPressed: widget.settingsController.retrySave,
          ),
        ),
      );
    }
    _settingsSaveProblem = failed;
  }

  void _notificationChanged() {
    final problem = widget.notifications?.problem;
    if (problem == null) {
      _lastNotificationProblem = null;
      return;
    }
    if (!mounted || problem == _lastNotificationProblem) return;
    _lastNotificationProblem = problem;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.notificationProblem(problem)),
        action: SnackBarAction(
          label: context.strings.settings,
          onPressed: () {
            widget.notifications?.openSettings();
          },
        ),
      ),
    );
  }

  void _widgetOpened() {
    final target = WidgetBridge.target.value;
    if (!mounted || target == null || !_pageController.hasClients) return;
    final index = widget.todoController.spaces.indexWhere(
      (s) => s.id == target.space,
    );
    WidgetBridge.target.value = null;
    if (index < 0) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _notificationTask = target.task);
    _pageController.jumpToPage(index);
    if (target.create) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _addTodo(
            initialGroup: TodoGroup.values
                .where((g) => g.name == target.category)
                .firstOrNull,
            allowTaskTutorial: false,
          );
        }
      });
    }
  }

  void _notificationOpened() {
    final target = widget.notifications?.openTask.value;
    if (!mounted || target == null || !_pageController.hasClients) return;
    final index = widget.todoController.spaces.indexWhere(
      (s) => s.id == target.spaceId,
    );
    if (index < 0) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _notificationTask = target.taskId);
    _showPage(index);
    widget.notifications?.openTask.value = null;
  }

  double? _panelTop() {
    final box = _headerKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy + box.size.height + 12;
  }

  bool _composerOpen = false;
  bool get _dragging => _taskDrag != null;
  bool _deleteHovered = false;
  final _deleteMagnetOffset = ValueNotifier<Offset>(Offset.zero);
  final _navigationKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _spaceDwellTimer?.cancel();
    _taskDragTickTimer?.cancel();
    _taskDragOverlay?.remove();
    _finishFirstEmptyHomeSession(updateUi: false);
    WidgetsBinding.instance.removeObserver(this);
    widget.notifications?.removeListener(_notificationChanged);
    widget.notifications?.openTask.removeListener(_notificationOpened);
    widget.settingsController.removeListener(_settingsChanged);
    widget.todoController.removeListener(_validateDragState);
    _spaceDwellProgress.removeListener(_refreshTaskDragOverlay);
    _pageController.dispose();
    _firstStageHeader.dispose();
    _firstStageBody.dispose();
    _firstStageTutorialText.dispose();
    _firstStageTutorialArrow.dispose();
    _firstStageButton.dispose();
    _firstEntrance.dispose();
    _spaceDwellProgress.dispose();
    WidgetBridge.target.removeListener(_widgetOpened);
    _deleteMagnetOffset.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _finishFirstEmptyHomeSession();
      _dismissTaskTutorial(showSpaceTutorial: false);
      final sourceState = _spacePageKeys[_dragSourceSpaceId]?.currentState;
      if (sourceState != null) {
        sourceState.cancelActiveDrag();
      } else {
        _finishTaskDrag(cancel: true);
      }
    }
  }

  void _validateDragState() {
    if (!_dragging || !mounted) return;
    final spaces = widget.todoController.spaces;
    final drag = _taskDrag!;
    final source = widget.todoController.spaceByIdOrNull(drag.sourceSpaceId);
    final sourceHasTask =
        source?.todos.any((todo) => todo.id == drag.todo.id) ?? false;
    if (!sourceHasTask) {
      final sourceState = _spacePageKeys[_dragSourceSpaceId]?.currentState;
      if (sourceState != null) {
        sourceState.cancelActiveDrag();
      } else {
        _finishTaskDrag(cancel: true);
      }
      return;
    }
    if (spaces.any((space) => space.id == _dragPreviewSpaceId)) return;
    final sourceIndex = spaces.indexWhere(
      (space) => space.id == _dragSourceSpaceId,
    );
    _clearSpaceDwell(updateHeader: false);
    setState(() {
      drag.destinationSpaceId = drag.sourceSpaceId;
      drag.targetGroup = drag.sourceGroup;
      drag.targetIndex = drag.sourceIndex;
      drag.validDrop = false;
      _hoveredSpaceId = null;
      _dragOverSpaceHeader = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sourceIndex >= 0) _showPage(sourceIndex);
    });
  }

  bool get _isFirstHomeEligible =>
      widget.settingsController.value.hasCompletedOnboarding &&
      !widget.settingsController.value.hasSeenFirstEmptyHomeHint;

  bool get _hasNoTasks {
    final controller = widget.todoController;
    return controller.archive.isEmpty &&
        controller.spaces.every((space) => space.todos.isEmpty);
  }

  bool get _showFirstEmptyHomeHint =>
      _firstEmptyHomeSessionStarted &&
      _isFirstHomeEligible &&
      _hasNoTasks &&
      !_composerOpen &&
      _currentPage < widget.todoController.spaces.length;

  void _finishFirstEmptyHomeSession({bool updateUi = true}) {
    if (!_firstEmptyHomeSessionStarted || !_isFirstHomeEligible) return;
    _firstEmptyHomeSessionStarted = false;
    if (updateUi && mounted) setState(() {});
    unawaited(widget.settingsController.markFirstEmptyHomeHintSeen());
  }

  void _dismissTaskTutorial({bool showSpaceTutorial = true}) {
    if (_taskTutorialId == null) return;
    setState(() {
      _taskTutorialSpaceId = null;
      _taskTutorialId = null;
    });
    if (showSpaceTutorial) _scheduleSpaceTutorial();
  }

  void _scheduleSpaceTutorial() {
    if (!_spaceTutorialPending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_spaceTutorialPending) return;
      if (_currentPage >= widget.todoController.spaces.length ||
          _manageSpaces ||
          _composerOpen ||
          _taskTutorialId != null) {
        if (_currentPage >= widget.todoController.spaces.length) {
          _spaceTutorialPending = false;
        }
        return;
      }
      _spaceTutorialPending = false;
      setState(() {
        _spaceTutorialVisible = true;
        _spaceTutorialTargetRect = null;
      });
      unawaited(widget.settingsController.markSpaceManagementTutorialSeen());
    });
  }

  void _dismissSpaceTutorial() {
    if (!_spaceTutorialVisible) return;
    setState(() {
      _spaceTutorialVisible = false;
      _spaceTutorialTargetRect = null;
    });
  }

  void _enterSpaceManagement() {
    if (_manageSpaces) return;
    _dismissTaskTutorial(showSpaceTutorial: false);
    _spaceTutorialPending = false;
    if (_spaceTutorialVisible) {
      _spaceTutorialVisible = false;
    }
    unawaited(widget.settingsController.markSpaceManagementTutorialSeen());
    AppHaptics.medium();
    setState(() => _manageSpaces = true);
  }

  void _setComposerOpen(bool value) {
    if (_composerOpen == value) return;
    setState(() => _composerOpen = value);
    if (!value) _scheduleSpaceTutorial();
  }

  void _scheduleEmptyHintMeasurement() {
    if (_emptyHintMeasureScheduled) return;
    _emptyHintMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emptyHintMeasureScheduled = false;
      if (!mounted || !_firstEmptyHomeSessionStarted) return;
      final buttonBounds = _buttonBounds();
      final layer = _emptyHintLayerKey.currentContext?.findRenderObject();
      if (buttonBounds == null || layer is! RenderBox || !layer.hasSize) return;
      final topLeft = layer.globalToLocal(buttonBounds.topLeft);
      final bottomRight = layer.globalToLocal(buttonBounds.bottomRight);
      final next = Rect.fromPoints(topLeft, bottomRight);
      if (_emptyHintButtonRect == next) return;
      setState(() => _emptyHintButtonRect = next);
    });
  }

  void _showSettings(int pageIndex) {
    _showPage(pageIndex);
  }

  void _showPage(int pageIndex) {
    setState(() => _manageSpaces = false);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(pageIndex);
      return;
    }
    _pageController.animateToPage(
      pageIndex,
      duration: AppMotion.open,
      curve: AppMotion.curve,
    );
  }

  void _startTaskDrag(TaskDragStartDetails details) {
    if (_taskDrag != null) return;
    final drag = _TaskDragSession(details);
    setState(() => _taskDrag = drag);
    final overlay = Overlay.of(context, rootOverlay: true);
    _taskDragOverlay = OverlayEntry(
      builder: (context) {
        final activeDrag = _taskDrag;
        if (activeDrag == null) return const SizedBox.shrink();
        final overlayBox = overlay.context.findRenderObject();
        final globalTopLeft = activeDrag.pointer - activeDrag.grabOffset;
        final position = overlayBox is RenderBox && overlayBox.attached
            ? overlayBox.globalToLocal(globalTopLeft)
            : globalTopLeft;
        return Positioned(
          left: position.dx,
          top: position.dy,
          width: activeDrag.feedbackBounds.width,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.none,
              child: TodoItem(
                todo: activeDrag.todo,
                active: true,
                dragging: true,
                deleteHovered: _deleteHovered,
                spaceSwitchArmed: _hoveredSpaceId != null,
                spaceSwitchProgress: _spaceDwellProgress.value,
                onToggle: () {},
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_taskDragOverlay!);
    _taskDragTickTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateActiveDropSurface(),
    );
    _handleTaskDragPosition(details.pointer, false);
  }

  void _refreshTaskDragOverlay() {
    _taskDragOverlay?.markNeedsBuild();
  }

  void _updateTaskDrag(Offset position) {
    if (_taskDrag == null) return;
    _handleTaskDragPosition(position, _deleteHovered);
  }

  void _endTaskDrag(bool cancel) {
    _finishTaskDrag(cancel: cancel);
  }

  void _finishTaskDrag({required bool cancel}) {
    final drag = _taskDrag;
    if (drag == null) return;
    final delete = !cancel && _deleteHovered;
    final validDrop = !cancel && !delete && drag.validDrop;
    _taskDragTickTimer?.cancel();
    _taskDragTickTimer = null;
    _taskDragOverlay?.remove();
    _taskDragOverlay = null;
    _clearSpaceDwell(updateHeader: false);
    setState(() {
      _taskDrag = null;
      _deleteHovered = false;
      _dragOverSpaceHeader = false;
      _hoveredSpaceId = null;
    });
    if (delete) {
      widget.todoController.deleteTodo(drag.sourceSpaceId, drag.todo.id);
      return;
    }
    if (!validDrop) return;
    if (drag.destinationSpaceId != drag.sourceSpaceId) {
      widget.todoController.moveTodoToSpace(
        drag.sourceSpaceId,
        drag.todo.id,
        drag.destinationSpaceId,
        group: drag.targetGroup,
        index: drag.targetIndex,
      );
      return;
    }
    final moved =
        drag.targetGroup != drag.sourceGroup ||
        drag.targetIndex != drag.sourceIndex;
    if (!moved) return;
    var index = drag.targetIndex;
    if (drag.targetGroup == drag.sourceGroup && drag.sourceIndex <= index) {
      index++;
    }
    widget.todoController.moveTodo(
      drag.sourceSpaceId,
      drag.todo.id,
      group: drag.targetGroup,
      index: index,
    );
  }

  bool _handleTaskDragPosition(Offset position, bool deleteHovered) {
    final drag = _taskDrag;
    if (drag == null) return false;
    drag.pointer = position;
    _taskDragOverlay?.markNeedsBuild();
    if (deleteHovered) {
      drag.validDrop = false;
      _clearSpaceDwell();
      if (_dragOverSpaceHeader) setState(() => _dragOverSpaceHeader = false);
      return false;
    }
    final spaces = widget.todoController.spaces;
    final currentSpaceId = _dragPreviewSpaceId;
    final hits = <({String id, Rect bounds})>[];
    for (final space in spaces) {
      final box = _spaceNameKeys[space.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final bounds = Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(box.size.bottomRight(Offset.zero)),
      ).inflate(12);
      if (!bounds.isFinite) continue;
      if (bounds.contains(position)) {
        hits.add((id: space.id, bounds: bounds));
      }
    }
    hits.sort(
      (a, b) => (a.bounds.center - position).distance.compareTo(
        (b.bounds.center - position).distance,
      ),
    );
    final hitId = hits.firstOrNull?.id;
    final targetId = hitId == currentSpaceId ? null : hitId;
    final overHeader = hitId != null;
    if (_dragOverSpaceHeader != overHeader) {
      setState(() => _dragOverSpaceHeader = overHeader);
    }
    if (_hoveredSpaceId == targetId) {
      if (!overHeader) _updateActiveDropSurface();
      return overHeader;
    }
    _clearSpaceDwell(updateHeader: false);
    if (targetId == null) {
      if (mounted) setState(() => _hoveredSpaceId = null);
      if (!overHeader) _updateActiveDropSurface();
      return overHeader;
    }
    setState(() => _hoveredSpaceId = targetId);
    _taskDragOverlay?.markNeedsBuild();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _spaceDwellProgress.forward(from: 0);
    }
    _spaceDwellTimer = Timer(crossSpaceDwellDuration, () {
      if (!mounted || !_dragging || _hoveredSpaceId != targetId) return;
      final index = widget.todoController.spaces.indexWhere(
        (space) => space.id == targetId,
      );
      if (index < 0 || _dragPreviewSpaceId == targetId) {
        _clearSpaceDwell();
        return;
      }
      _spaceDwellTimer = null;
      _spaceDwellProgress
        ..stop()
        ..value = 1;
      AppHaptics.selection();
      setState(() {
        _hoveredSpaceId = null;
        drag.destinationSpaceId = targetId;
        drag.targetGroup = drag.sourceGroup;
        final count = widget.todoController
            .activeTodos(targetId, drag.sourceGroup)
            .where((todo) => todo.id != drag.todo.id)
            .length;
        drag.targetIndex = drag.sourceIndex.clamp(0, count);
        drag.validDrop = false;
      });
      _taskDragOverlay?.markNeedsBuild();
      _showPage(index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _spaceDwellProgress.animateBack(
          0,
          duration: AppMotion.duration(
            context,
            const Duration(milliseconds: 160),
          ),
          curve: AppMotion.curve,
        );
        if (_taskDrag == drag) _updateActiveDropSurface();
      });
    });
    if (!overHeader) _updateActiveDropSurface();
    return overHeader;
  }

  void _clearSpaceDwell({bool updateHeader = true}) {
    _spaceDwellTimer?.cancel();
    _spaceDwellTimer = null;
    _spaceDwellProgress.stop();
    final fadeFeedback =
        updateHeader &&
        mounted &&
        !MediaQuery.disableAnimationsOf(context) &&
        _spaceDwellProgress.value > 0;
    if (fadeFeedback) {
      _spaceDwellProgress.animateBack(
        0,
        duration: AppMotion.duration(
          context,
          const Duration(milliseconds: 140),
        ),
        curve: AppMotion.curve,
      );
    } else {
      _spaceDwellProgress.value = 0;
    }
    if (!updateHeader || !mounted || _hoveredSpaceId == null) return;
    setState(() => _hoveredSpaceId = null);
    _taskDragOverlay?.markNeedsBuild();
  }

  void _updateActiveDropSurface() {
    final drag = _taskDrag;
    if (drag == null || _deleteHovered || _dragOverSpaceHeader) return;
    final state = _spacePageKeys[drag.destinationSpaceId]?.currentState;
    if (state == null) {
      drag.validDrop = false;
      return;
    }
    state.updateExternalDrag(drag.pointer);
    final target = state.resolveTaskDropTarget(
      drag.pointer,
      drag.sourceGroup,
      drag.sourceIndex,
      drag.todo.id,
    );
    if (target == null) {
      if (drag.validDrop) {
        setState(() => drag.validDrop = false);
      }
      return;
    }
    final categoryChanged = drag.targetGroup != target.group;
    if (drag.validDrop &&
        drag.targetGroup == target.group &&
        drag.targetIndex == target.index) {
      return;
    }
    setState(() {
      drag.targetGroup = target.group;
      drag.targetIndex = target.index;
      drag.validDrop = true;
    });
    if (categoryChanged) AppHaptics.selection();
  }

  Future<void> _createSpace() async {
    if (!widget.todoController.canAddSpace) return;
    final result = await showDialog<_SpaceDialogResult>(
      context: context,
      builder: (context) => const _NewSpaceDialog(),
    );
    if (!mounted || result?.name == null) return;
    if (!widget.todoController.canAddSpace) return;
    final id = widget.todoController.addSpace(result!.name!);
    setState(() => _manageSpaces = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPage(
        widget.todoController.spaces.indexWhere((space) => space.id == id),
      );
    });
  }

  Future<void> _renameSpace(int index) async {
    if (index < 0 || index >= widget.todoController.spaces.length) return;
    final space = widget.todoController.spaces[index];
    final result = await showDialog<_SpaceDialogResult>(
      context: context,
      builder: (context) => _NewSpaceDialog(
        initialName: space.name,
        allowDelete: widget.todoController.spaces.length > 1,
      ),
    );
    if (!mounted || result == null) return;
    if (result.delete) {
      await _deleteSpace(space.id);
      return;
    }
    final name = result.name;
    if (name == null) return;
    widget.todoController.renameSpace(space.id, name);
    setState(() => _manageSpaces = false);
  }

  Future<void> _deleteSpace(String spaceId) async {
    final spaces = widget.todoController.spaces;
    if (spaces.length <= 1) return;
    final index = spaces.indexWhere((space) => space.id == spaceId);
    if (index < 0) return;
    final currentPage = _pageController.hasClients
        ? (_pageController.page ?? _currentPage).round()
        : _currentPage;
    final targetPage =
        (index < currentPage
                ? currentPage - 1
                : index == currentPage
                ? currentPage > 0
                      ? currentPage - 1
                      : 0
                : currentPage)
            .toInt();
    final deleted = await widget.todoController.deleteSpace(spaceId);
    if (!deleted) return;
    await widget.notifications?.removeSpace(spaceId);
    if (!mounted) return;
    final validTarget = targetPage
        .clamp(0, widget.todoController.spaces.length)
        .toInt();
    setState(() {
      _manageSpaces = false;
      _currentPage = validTarget;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) _showPage(validTarget);
    });
  }

  Rect? _buttonBounds() {
    final box = _buttonKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    return Rect.fromLTRB(
      anchor.right -
          (_dragging ? AddTodoButton.deleteWidth : AddTodoButton.width),
      anchor.top,
      anchor.right,
      anchor.bottom,
    );
  }

  Future<void> _addTodo({
    TodoGroup? initialGroup,
    bool allowTaskTutorial = true,
  }) async {
    if (_composerOpen) return;
    final spaces = widget.todoController.spaces;
    final page = _pageController.hasClients ? _pageController.page ?? 0 : 0.0;
    final index = page.round();
    if (index >= spaces.length) return;
    final spaceId = spaces[index].id;
    final origin = _buttonBounds();
    if (origin == null) return;
    _dismissTaskTutorial(showSpaceTutorial: false);
    final shouldShowSpaceTutorial =
        _hasNoTasks &&
        !widget.settingsController.value.hasSeenSpaceManagementTutorial;
    setState(() {
      _composerOpen = true;
      _manageSpaces = false;
    });
    final draft = await AddTodoSheet.show(
      context,
      origin,
      clock: widget.todoController.clock,
      morningReminderMinutes:
          widget.settingsController.value.morningReminderMinutes,
      resolveOrigin: _buttonBounds,
      panelTop: _panelTop(),
      initialDraft: initialGroup == null
          ? null
          : TodoDraft(title: '', group: initialGroup),
    );
    if (!mounted) return;
    setState(() {
      _composerOpen = false;
      _spaceTutorialVisible = false;
    });
    if (draft == null) return;
    final shouldMarkEmptyHint =
        _firstEmptyHomeSessionStarted && _isFirstHomeEligible && _hasNoTasks;
    final shouldShowTaskTutorial =
        allowTaskTutorial &&
        !widget.settingsController.value.hasSeenTaskEditTutorial;
    final wantsPin = draft.isPinned;
    final id = widget.todoController.addTodo(
      spaceId,
      wantsPin ? draft.copyWith(isPinned: false) : draft,
    );
    try {
      await widget.todoController.flush();
    } catch (_) {
      return;
    }
    if (shouldMarkEmptyHint) {
      _firstEmptyHomeSessionStarted = false;
      await widget.settingsController.markFirstEmptyHomeHintSeen();
    }
    if (shouldShowSpaceTutorial) _spaceTutorialPending = true;
    if (wantsPin && mounted) {
      await applyTaskPinAfterSave(
        controller: widget.todoController,
        spaceId: spaceId,
        todoId: id,
        currentPinned: false,
        targetPinned: true,
      );
    }
    if (shouldShowTaskTutorial && mounted) {
      setState(() {
        _taskTutorialSpaceId = spaceId;
        _taskTutorialId = id;
      });
      unawaited(widget.settingsController.markTaskEditTutorialSeen());
    } else if (shouldShowSpaceTutorial && mounted) {
      _scheduleSpaceTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.todoController,
      builder: (context, _) {
        final controller = widget.todoController;
        return AnnotatedRegion(
          value: appSystemUiFor(context),
          child: Scaffold(
            body: switch ((controller.isReady, controller.loadFailed)) {
              (_, true) => _LoadError(onRetry: controller.initialize),
              (false, false) => const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              (true, false) => _buildPager(context),
            },
          ),
        );
      },
    );
  }

  Widget _buildPager(BuildContext context) {
    final spaces = widget.todoController.spaces;
    final settingsIndex = spaces.length;
    final tutorialSpace = _currentPage < spaces.length
        ? spaces[_currentPage]
        : null;
    if (_spaceTutorialVisible && tutorialSpace != null) {
      _scheduleSpaceTutorialTargetMeasurement(tutorialSpace.id);
    }
    return SafeArea(
      maintainBottomViewPadding: true,
      child: Stack(
        children: [
          Column(
            children: [
              _HomeEntrance(
                animation: _firstStageHeader,
                child: Align(
                  key: _headerKey,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpace.contentWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
                      child: _SharedHeader(
                        spaces: spaces,
                        navigationKeys: _navigationKeys,
                        navigationTextKeys: _spaceNameKeys,
                        hoveredSpaceId: _hoveredSpaceId,
                        dwellProgress: _spaceDwellProgress,
                        taskDragging: _dragging,
                        spaceTutorialLink: _spaceTutorialLink,
                        manageSpaces: _manageSpaces,
                        onRename: _renameSpace,
                        onManage: (_) => _enterSpaceManagement(),
                        onDismiss: () {
                          if (mounted && _manageSpaces) {
                            setState(() => _manageSpaces = false);
                          }
                        },
                        onCreate: _createSpace,
                        pageController: _pageController,
                        settingsPageIndex: settingsIndex,
                        onOpenPage: _showPage,
                        onShowSettings: () => _showSettings(settingsIndex),
                        settingsController: widget.settingsController,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _HomeEntrance(
                  animation: _firstStageBody,
                  child: PageView(
                    key: const ValueKey('main-space-pager'),
                    controller: _pageController,
                    physics: _dragging
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    dragStartBehavior: DragStartBehavior.down,
                    onPageChanged: (index) {
                      if (index >= spaces.length) {
                        _finishFirstEmptyHomeSession();
                      }
                      if (_currentPage != index) {
                        setState(() {
                          _currentPage = index;
                          _manageSpaces = false;
                        });
                        _scheduleSpaceTutorial();
                      }
                    },
                    children: [
                      for (var index = 0; index < spaces.length; index++)
                        TodoSpaceScreen(
                          key: _spacePageKeys.putIfAbsent(
                            spaces[index].id,
                            () => GlobalKey<TodoSpaceScreenState>(),
                          ),
                          spaceId: spaces[index].id,
                          focusTaskId: _notificationTask,
                          controller: widget.todoController,
                          activePage: _currentPage == index,
                          morningReminderMinutes: widget
                              .settingsController
                              .value
                              .morningReminderMinutes,
                          showPermanentEmptyState: !_isFirstHomeEligible,
                          buttonBounds: _buttonBounds,
                          panelTop: _panelTop,
                          onTaskDragStart: _startTaskDrag,
                          onTaskDragUpdate: _updateTaskDrag,
                          onTaskDragEnd: _endTaskDrag,
                          draggedTodo: _taskDrag?.todo,
                          dragSourceSpaceId: _dragSourceSpaceId,
                          dragDestinationSpaceId: _dragPreviewSpaceId,
                          dragTargetGroup: _taskDrag?.targetGroup,
                          dragTargetIndex: _taskDrag?.targetIndex,
                          keepDragAlive:
                              _dragging &&
                              _dragSourceSpaceId == spaces[index].id,
                          onDeleteHoverChanged: (value) =>
                              setState(() => _deleteHovered = value),
                          onDeleteMagnetChanged: (value) =>
                              _deleteMagnetOffset.value = value,
                          onEditorVisibilityChanged: _setComposerOpen,
                          taskTutorialId:
                              _taskTutorialSpaceId == spaces[index].id
                              ? _taskTutorialId
                              : null,
                          onTaskTutorialDismissed: _dismissTaskTutorial,
                        ),
                      SettingsScreen(
                        themeController: widget.themeController,
                        settingsController: widget.settingsController,
                        todoController: widget.todoController,
                        purchaseService: widget.purchaseService,
                        notifications: widget.notifications,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showFirstEmptyHomeHint) ...[
            Builder(
              builder: (context) {
                _scheduleEmptyHintMeasurement();
                return Positioned.fill(
                  child: SizedBox.expand(
                    key: _emptyHintLayerKey,
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        final page = _pageController.hasClients
                            ? _pageController.page ?? 0
                            : 0.0;
                        final onTodoPage = page < spaces.length - 0.01;
                        if (!onTodoPage) return const SizedBox.shrink();
                        return IgnorePointer(
                          child: FirstEmptyHomeHint(
                            label: context.strings.firstEmptyHomeHint,
                            textAnimation: _firstStageTutorialText,
                            arrowAnimation: _firstStageTutorialArrow,
                            buttonRect: _emptyHintButtonRect,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
          if (_spaceTutorialVisible &&
              !_manageSpaces &&
              _currentPage < spaces.length)
            Positioned.fill(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: CompositedTransformFollower(
                  link: _spaceTutorialLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.topLeft,
                  offset: const Offset(0, 4),
                  child: SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 56)
                        .clamp(240.0, 320.0)
                        .toDouble(),
                    child: SpaceManagementTutorial(
                      key: const ValueKey('space-management-tutorial'),
                      measurementKey: _spaceTutorialKey,
                      onDismiss: _dismissSpaceTutorial,
                      arrowTargetBounds: _spaceTutorialTargetRect,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.todoController.canUndoDeletion &&
              !_dragging &&
              !_composerOpen &&
              _currentPage < spaces.length)
            Positioned(
              left: 24,
              right: 96,
              bottom: AppSpace.xl,
              child: Container(
                height: 56,
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: context.appColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          context.strings.deletedEntry,
                          style: context.appTypography.body.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.todoController.undoDeletion,
                      child: Text(
                        context.strings.undo,
                        style: context.appTypography.buttonLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: AppSpace.xl,
            bottom: AppSpace.xl,
            child: _HomeEntrance(
              animation: _firstStageButton,
              scale: true,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) {
                  final page = _pageController.hasClients
                      ? _pageController.page ?? 0
                      : 0.0;
                  var progress = (page - (settingsIndex - 1)).clamp(0.0, 1.0);
                  if (progress < 0.001) progress = 0;
                  if (progress > 0.999) progress = 1;
                  return IgnorePointer(
                    ignoring: _composerOpen || progress > 0,
                    child: Opacity(
                      opacity: _composerOpen ? 0 : 1 - progress,
                      child: AnimatedContainer(
                        key: _buttonKey,
                        duration: AppMotion.duration(context, AppMotion.color),
                        curve: AppMotion.curve,
                        width: _dragging
                            ? AddTodoButton.deleteWidth
                            : AddTodoButton.width,
                        height: AddTodoButton.height,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<Offset>(
                            valueListenable: _deleteMagnetOffset,
                            builder: (context, offset, child) =>
                                TweenAnimationBuilder<Offset>(
                                  tween: Tween(end: offset),
                                  duration: AppMotion.duration(
                                    context,
                                    offset == Offset.zero
                                        ? AppMotion.color
                                        : AppMotion.press,
                                  ),
                                  curve: AppMotion.curve,
                                  child: child,
                                  builder: (context, value, child) =>
                                      Transform.translate(
                                        offset: value,
                                        child: child,
                                      ),
                                ),
                            child: RepaintBoundary(
                              child: AddTodoButton(
                                dragging: _dragging,
                                deleteHovered: _deleteHovered,
                                onPressed: progress == 0 ? _addTodo : () {},
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleSpaceTutorialTargetMeasurement(String spaceId) {
    if (_spaceTutorialMeasurementScheduled) return;
    _spaceTutorialMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spaceTutorialMeasurementScheduled = false;
      if (!mounted ||
          !_spaceTutorialVisible ||
          _currentPage >= widget.todoController.spaces.length ||
          widget.todoController.spaces[_currentPage].id != spaceId) {
        return;
      }
      final nameRenderObject = _spaceNameKeys[spaceId]?.currentContext
          ?.findRenderObject();
      final tutorialRenderObject = _spaceTutorialKey.currentContext
          ?.findRenderObject();
      if (nameRenderObject is! RenderBox ||
          tutorialRenderObject is! RenderBox ||
          !nameRenderObject.attached ||
          !tutorialRenderObject.attached ||
          !nameRenderObject.hasSize ||
          !tutorialRenderObject.hasSize) {
        return;
      }
      final targetRect = MatrixUtils.transformRect(
        nameRenderObject.getTransformTo(tutorialRenderObject),
        Offset.zero & nameRenderObject.size,
      );
      if (_spaceTutorialTargetRect != targetRect) {
        setState(() => _spaceTutorialTargetRect = targetRect);
      }
    });
  }

  CurvedAnimation _firstStage(double start, double end) => CurvedAnimation(
    parent: _firstEntrance,
    curve: Interval(start, end, curve: AppMotion.curve),
  );
}

class _HomeEntrance extends StatelessWidget {
  const _HomeEntrance({
    required this.animation,
    required this.child,
    this.scale = false,
  });

  final Animation<double> animation;
  final Widget child;
  final bool scale;

  @override
  Widget build(BuildContext context) {
    Widget result = SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
    if (scale) {
      result = ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
        child: result,
      );
    }
    return FadeTransition(opacity: animation, child: result);
  }
}

class _SharedHeader extends StatelessWidget {
  const _SharedHeader({
    required this.spaces,
    required this.navigationKeys,
    required this.navigationTextKeys,
    required this.hoveredSpaceId,
    required this.dwellProgress,
    required this.taskDragging,
    required this.spaceTutorialLink,
    required this.manageSpaces,
    required this.onRename,
    required this.onManage,
    required this.onDismiss,
    required this.onCreate,
    required this.pageController,
    required this.settingsPageIndex,
    required this.onOpenPage,
    required this.onShowSettings,
    required this.settingsController,
  });

  final bool manageSpaces;
  final ValueChanged<int> onRename;
  final ValueChanged<int> onManage;
  final VoidCallback onDismiss, onCreate;
  final List<TodoSpace> spaces;
  final Map<String, GlobalKey> navigationKeys;
  final Map<String, GlobalKey> navigationTextKeys;
  final String? hoveredSpaceId;
  final Animation<double> dwellProgress;
  final bool taskDragging;
  final LayerLink spaceTutorialLink;
  final PageController pageController;
  final int settingsPageIndex;
  final ValueChanged<int> onOpenPage;
  final VoidCallback onShowSettings;
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        pageController,
        settingsController,
        dwellProgress,
      ]),
      builder: (context, _) {
        final page = pageController.hasClients ? pageController.page ?? 0 : 0.0;
        final settingsProgress = settingsPageIndex == 0
            ? 1.0
            : (page - (settingsPageIndex - 1)).clamp(0.0, 1.0);
        final colors = context.appColors;
        return LayoutBuilder(
          builder: (context, constraints) {
            final available =
                (constraints.maxWidth -
                        AppSpace.md -
                        AppSpace.touch -
                        (manageSpaces
                            ? spaces.length >= TodoController.maxSpaces
                                  ? 48
                                  : AppSpace.md + 44
                            : 0) -
                        (spaces.length - 1) * 12)
                    .clamp(1.0, double.infinity);
            var fontScale = 1.0;
            var widths = <double>[];
            for (final candidate in [1.0, 0.9, 0.8, 0.7]) {
              fontScale = candidate;
              widths = [
                for (var i = 0; i < spaces.length; i++)
                  (() {
                    const active = 1.0;
                    final painter = TextPainter(
                      text: TextSpan(
                        text: spaces[i].name,
                        style: context.appTypography.spaceActive.copyWith(
                          fontSize:
                              lerpDouble(
                                18,
                                spaces.length == 1 ? 24 : 22,
                                active,
                              )! *
                              candidate,
                        ),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final width = painter.width;
                    painter.dispose();
                    return width;
                  })(),
              ];
              if (widths.fold<double>(0, (sum, width) => sum + width) <=
                  available) {
                break;
              }
            }
            final total = widths.fold<double>(0, (sum, width) => sum + width);
            final fit = total > available ? available / total : 1.0;
            final activeIndex = spaces.isEmpty
                ? 0
                : page.round().clamp(0, spaces.length - 1).toInt();
            return Transform.translate(
              offset: const Offset(0, -AppSpace.spaceHeaderLift),
              child: Row(
                children: [
                  Expanded(
                    child: TapRegion(
                      groupId: 'space-management',
                      onTapOutside: (_) => onDismiss(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < spaces.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 12),
                            Builder(
                              builder: (context) {
                                final item = _SpaceNavigationItem(
                                  key: navigationKeys.putIfAbsent(
                                    spaces[index].id,
                                    () => GlobalKey(),
                                  ),
                                  nameKey: navigationTextKeys.putIfAbsent(
                                    spaces[index].id,
                                    () => GlobalKey(),
                                  ),
                                  maxWidth: widths[index] * fit,
                                  fontScale: fontScale,
                                  name: spaces[index].name,
                                  index: index,
                                  page: page,
                                  settingsProgress: settingsProgress,
                                  singleSpace: spaces.length == 1,
                                  onPressed: () {
                                    if (taskDragging) return;
                                    if (manageSpaces) {
                                      onRename(index);
                                    } else {
                                      onOpenPage(index);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!taskDragging) onManage(index);
                                  },
                                  tutorialLink:
                                      !manageSpaces && index == activeIndex
                                      ? spaceTutorialLink
                                      : null,
                                  dwellHovered:
                                      hoveredSpaceId == spaces[index].id,
                                  dwellProgress: dwellProgress.value,
                                );
                                return item;
                              },
                            ),
                          ],
                          if (manageSpaces)
                            if (spaces.length >= TodoController.maxSpaces)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  SometimeIcons.prohibit,
                                  size: 21,
                                  semanticLabel: context.strings.maxSpaces,
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: AppSpace.md),
                                  _SpaceManagementAddButton(
                                    key: const ValueKey('add-space'),
                                    onPressed: onCreate,
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Transform.scale(
                    key: ValueKey(
                      'profile-scale-${spaces.length == 1 ? spaces.first.id : 'shared'}',
                    ),
                    scale: 1 + settingsProgress * 0.12,
                    child: Pressable(
                      label: context.strings.openSettings,
                      selected: settingsProgress == 1,
                      onPressed: onShowSettings,
                      radius: 24,
                      builder: (context, state) => SizedBox.square(
                        dimension: AppSpace.touch,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(
                                colors.track,
                                colors.settingsAvatar,
                                settingsProgress,
                              ),
                            ),
                            child: Center(
                              child: settingsController.value.initial == null
                                  ? Icon(
                                      SometimeIcons.user,
                                      size: 20,
                                      color: Color.lerp(
                                        colors.secondary,
                                        colors.onSettingsAvatar,
                                        settingsProgress,
                                      ),
                                    )
                                  : Text(
                                      settingsController.value.initial!,
                                      style: context.appTypography.avatarInitial
                                          .copyWith(
                                            fontSize: 15,
                                            color: Color.lerp(
                                              colors.secondary,
                                              colors.onSettingsAvatar,
                                              settingsProgress,
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SpaceManagementAddButton extends StatefulWidget {
  const _SpaceManagementAddButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  State<_SpaceManagementAddButton> createState() =>
      _SpaceManagementAddButtonState();
}

class _SpaceManagementAddButtonState extends State<_SpaceManagementAddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _releaseAnimation = AnimationController(
    vsync: this,
    duration: AppMotion.press,
  );
  bool _activating = false;

  @override
  void dispose() {
    _releaseAnimation.dispose();
    super.dispose();
  }

  void _activateAfterRelease() {
    if (_activating) return;
    _activating = true;
    final delay = AppMotion.duration(context, AppMotion.press);
    if (delay == Duration.zero) {
      _finishActivation();
      return;
    }
    _releaseAnimation
      ..duration = delay
      ..forward(from: 0).whenComplete(_finishActivation);
  }

  void _finishActivation() {
    if (!mounted) return;
    _activating = false;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duration(context, const Duration(milliseconds: 180)),
      curve: AppMotion.curve,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.scale(
          alignment: Alignment.center,
          scale: 0.88 + progress * 0.12,
          child: Transform.rotate(
            angle: (1 - progress) * 0.16,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
      child: Pressable(
        label: context.strings.newSpace,
        onPressed: _activateAfterRelease,
        scale: 0.94,
        radius: AppSpace.controlRadius,
        builder: (context, state) => SizedBox(
          width: 44,
          height: AppSpace.touch,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.press),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: state.pressed || state.hovered
                    ? Color.alphaBlend(colors.hover, colors.track)
                    : colors.track,
                borderRadius: BorderRadius.circular(AppSpace.controlRadius),
              ),
              child: SometimeActionIconBox(
                dimension: 30,
                glyph: SometimeActionGlyph.plus,
                size: 20,
                color: colors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceNavigationItem extends StatelessWidget {
  const _SpaceNavigationItem({
    required this.name,
    required this.index,
    required this.page,
    required this.settingsProgress,
    required this.singleSpace,
    required this.maxWidth,
    required this.fontScale,
    required this.onPressed,
    required this.onLongPress,
    required this.nameKey,
    required this.dwellHovered,
    required this.dwellProgress,
    this.tutorialLink,
    super.key,
  });

  final String name;
  final int index;
  final double page;
  final double settingsProgress;
  final bool singleSpace;
  final double maxWidth;
  final double fontScale;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final GlobalKey nameKey;
  final bool dwellHovered;
  final double dwellProgress;
  final LayerLink? tutorialLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeProgress =
        (1 - (page - index).abs()).clamp(0.0, 1.0) * (1 - settingsProgress);
    final activeSize = singleSpace ? 24.0 : 22.0;
    final size = lerpDouble(18, activeSize, activeProgress)! * fontScale;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final hoverEmphasis = dwellHovered
        ? reducedMotion
              ? 0.35
              : 0.25 + dwellProgress * 0.75
        : 0.0;
    final emphasis = math.max(activeProgress, hoverEmphasis);
    final textStyle = TextStyle.lerp(
      context.appTypography.spaceInactive,
      context.appTypography.spaceActive,
      emphasis,
    )!.copyWith(color: Color.lerp(colors.inactiveSpace, colors.ink, emphasis));
    final text = Text(
      name,
      key: nameKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle.copyWith(fontSize: activeSize * fontScale),
    );
    final hoverText = Transform.scale(
      alignment: Alignment.centerLeft,
      scale: reducedMotion ? 1 : 1 + 0.02 * hoverEmphasis,
      child: text,
    );
    final targetEmphasis = dwellHovered
        ? reducedMotion
              ? 0.7
              : 0.25 + dwellProgress * 0.75
        : 0.35;
    final targetIndicator = Positioned(
      left: -AppSpace.sm,
      top: -AppSpace.xs,
      right: -AppSpace.sm,
      bottom: -AppSpace.xs,
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: ValueKey('space-dwell-indicator-$index'),
          opacity: dwellHovered ? 1 : 0,
          duration: AppMotion.duration(context, AppMotion.press),
          curve: AppMotion.curve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.hover.withValues(
                alpha: 0.04 + 0.04 * targetEmphasis,
              ),
              border: Border.all(
                color: colors.outline.withValues(
                  alpha: 0.28 + 0.32 * targetEmphasis,
                ),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
    final targetText = Stack(
      clipBehavior: Clip.none,
      children: [targetIndicator, hoverText],
    );
    return Pressable(
      label: context.strings.openSpace(name),
      selected: activeProgress > 0.5,
      onPressed: onPressed,
      onLongPress: onLongPress,
      hapticOnLongPress: false,
      scale: 1,
      radius: 10,
      builder: (context, state) => SizedBox(
        height: AppSpace.touch,
        width: maxWidth,
        child: Transform(
          origin: const Offset(0, 34),
          transform: Matrix4.diagonal3Values(
            size / (activeSize * fontScale),
            size / (activeSize * fontScale),
            1,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Baseline(
              baseline: 34,
              baselineType: TextBaseline.alphabetic,
              child: tutorialLink == null
                  ? targetText
                  : CompositedTransformTarget(
                      link: tutorialLink!,
                      child: targetText,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.strings.loadError,
              style: context.appTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            Pressable(
              label: context.strings.retry,
              onPressed: onRetry,
              builder: (context, state) => Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpace.touch,
                  maxWidth: 160,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.track,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  context.strings.retry,
                  style: context.appTypography.buttonLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSpaceDialog extends StatefulWidget {
  const _NewSpaceDialog({this.initialName, this.allowDelete = false});
  final String? initialName;
  final bool allowDelete;

  @override
  State<_NewSpaceDialog> createState() => _NewSpaceDialogState();
}

class _NewSpaceDialogState extends State<_NewSpaceDialog> {
  late final _input = TextEditingController(text: widget.initialName);
  bool _confirmingDelete = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _input.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, _SpaceDialogResult(name: name));
    }
  }

  void _delete() {
    setState(() => _confirmingDelete = true);
  }

  void _confirmDelete() {
    Navigator.pop(context, const _SpaceDialogResult(delete: true));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _confirmingDelete
          ? context.strings.deleteSpaceQuestion
          : widget.initialName == null
          ? context.strings.newSpace
          : context.strings.renameSpace,
    ),
    content: _confirmingDelete
        ? Text(context.strings.deleteSpaceExplanation)
        : SometimeInput(
            controller: _input,
            maxLength: TodoSpace.maxNameLength,
            autofocus: true,
            hint: context.strings.nameHint,
            onSubmitted: (_) => _submit(),
          ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    actions: [
      SizedBox(
        width: double.infinity,
        child: _confirmingDelete
            ? Row(
                children: [
                  Expanded(
                    child: _SpaceDialogAction(
                      label: context.strings.cancel,
                      onPressed: () =>
                          setState(() => _confirmingDelete = false),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: _SpaceDialogAction(
                      label: context.strings.delete,
                      destructive: true,
                      onPressed: _confirmDelete,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SpaceDialogAction(
                          label: context.strings.cancel,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: _SpaceDialogAction(
                          label: widget.initialName == null
                              ? context.strings.create
                              : context.strings.save,
                          primary: true,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                  if (widget.allowDelete) ...[
                    const SizedBox(height: AppSpace.sm),
                    _SpaceDialogAction(
                      label: context.strings.deleteSpace,
                      icon: SometimeIcons.trash,
                      destructive: true,
                      onPressed: _delete,
                    ),
                  ],
                ],
              ),
      ),
    ],
  );
}

class _SpaceDialogAction extends StatelessWidget {
  const _SpaceDialogAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool destructive;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final background = destructive
        ? colors.destructive
        : primary
        ? colors.strongSelection
        : colors.pill;
    final foreground = destructive
        ? colors.onDestructive
        : primary
        ? colors.onStrongSelection
        : colors.text;
    return Pressable(
      label: label,
      onPressed: onPressed,
      scale: 0.97,
      radius: AppSpace.controlRadius,
      builder: (context, state) => AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.press),
        constraints: const BoxConstraints(minHeight: AppSpace.touch),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: state.pressed || state.hovered
              ? Color.alphaBlend(colors.hover, background)
              : background,
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.buttonLabel.copyWith(
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceDialogResult {
  const _SpaceDialogResult({this.name, this.delete = false});

  final String? name;
  final bool delete;
}
