import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../models/todo.dart';
import 'todo_item.dart';

class TodoSection extends StatelessWidget {
  const TodoSection({
    required this.group,
    required this.todos,
    required this.onToggle,
    required this.activeTodoId,
    required this.draggingTodoId,
    required this.onActivate,
    required this.onDeactivate,
    required this.onEdit,
    this.onPin,
    this.tutorialTaskId,
    this.tutorialLink,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.rowKeys,
    required this.isExiting,
    this.trailing,
    this.insertedId,
    this.insertedKey,
    this.onInsertEnd,
    this.progress,
    super.key,
  });

  final TodoGroup group;
  final List<Todo> todos;
  final ValueChanged<Todo> onToggle;
  final String? activeTodoId;
  final String? draggingTodoId;
  final ValueChanged<Todo> onActivate;
  final VoidCallback onDeactivate;
  final ValueChanged<Todo> onEdit;
  final Future<bool> Function(Todo)? onPin;
  final String? tutorialTaskId;
  final LayerLink? tutorialLink;
  final ValueChanged<Todo> onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final Map<String, GlobalKey> rowKeys;
  final bool Function(String) isExiting;
  final String? trailing;
  final String? insertedId;
  final GlobalKey? insertedKey;
  final VoidCallback? onInsertEnd;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.strings.groupName(group.index),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTypography.sectionTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: AppMotion.duration(context, AppMotion.color),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: progress == null
                            ? const SizedBox(
                                key: ValueKey('category-progress-hidden'),
                              )
                            : Text(
                                progress!,
                                key: ValueKey(progress),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.appTypography.metadata,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  key: const ValueKey('today-date'),
                  style: context.appTypography.metadata.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        for (var index = 0; index < todos.length; index++) ...[
          _TodoEntry(
            key: todos[index].id == insertedId
                ? insertedKey
                : ValueKey(todos[index].id),
            animate: todos[index].id == insertedId,
            exiting: isExiting(todos[index].id),
            onEnd: todos[index].id == insertedId ? onInsertEnd : null,
            child: SizedBox(
              key: rowKeys.putIfAbsent(todos[index].id, () => GlobalKey()),
              child: AnimatedSlide(
                offset:
                    draggingTodoId != null &&
                        todos
                            .take(index)
                            .any((todo) => todo.id == draggingTodoId)
                    ? const Offset(0, 0.18)
                    : Offset.zero,
                duration: AppMotion.duration(context, AppMotion.color),
                curve: AppMotion.curve,
                child: Offstage(
                  offstage: draggingTodoId == todos[index].id,
                  child: TodoItem(
                    todo: todos[index],
                    active: activeTodoId == todos[index].id,
                    dragging: draggingTodoId == todos[index].id,
                    onToggle: () => onToggle(todos[index]),
                    onActivate: () => onActivate(todos[index]),
                    onDeactivate: onDeactivate,
                    onEdit: () => onEdit(todos[index]),
                    onPin: onPin == null ? null : () => onPin!(todos[index]),
                    tutorialLink: todos[index].id == tutorialTaskId
                        ? tutorialLink
                        : null,
                    onDragStarted: () => onDragStarted(todos[index]),
                    onDragUpdate: onDragUpdate,
                    onDragEnd: onDragEnd,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (todos.every((todo) => todo.id == draggingTodoId))
          const SizedBox(height: AppSpace.xl),
      ],
    );
  }
}

class _TodoEntry extends StatelessWidget {
  const _TodoEntry({
    required this.child,
    required this.animate,
    required this.exiting,
    this.onEnd,
    super.key,
  });

  final Widget child;
  final bool animate;
  final bool exiting;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final removal = TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: exiting ? 0 : 1),
      duration: AppMotion.duration(context, const Duration(milliseconds: 280)),
      curve: Curves.easeInCubic,
      child: child,
      builder: (context, value, child) => ClipRect(
        clipBehavior: value == 1 ? Clip.none : Clip.hardEdge,
        child: Align(
          heightFactor: value,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: value > 0.35 ? 1 : value / 0.35,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 64),
              child: Transform.scale(
                scaleX: 0.94 + value * 0.06,
                scaleY: 0.84 + value * 0.16,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    if (!animate) return removal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: AppMotion.duration(context, AppMotion.insert),
      curve: AppMotion.curve,
      onEnd: onEnd,
      child: removal,
      builder: (context, progress, child) => ClipRect(
        clipBehavior: progress == 1 ? Clip.none : Clip.hardEdge,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: progress,
          child: Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
