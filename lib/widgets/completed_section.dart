import '../app/sometime_icons.dart';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';
import '../models/todo.dart';
import 'dashed_divider.dart';
import 'pressable.dart';
import 'todo_item.dart';

class CompletedSection extends StatelessWidget {
  const CompletedSection({
    required this.todos,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggleTodo,
    this.dragging = false,
    this.noticeVisible = false,
    this.collapseArmed = false,
    super.key,
  });

  final List<Todo> todos;
  final bool expanded, dragging;
  final bool noticeVisible;
  final bool collapseArmed;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Todo> onToggleTodo;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: dragging ? 0.55 : 1,
    duration: AppMotion.color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.color),
          curve: AppMotion.curve,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.color),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
            child: expanded
                ? Column(
                    key: const ValueKey('completed-open'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpace.md),
                        child: DashedDivider(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            for (final todo in todos)
                              TodoItem(
                                key: ValueKey('completed-${todo.id}'),
                                todo: todo,
                                onToggle: () => onToggleTodo(todo),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('completed-closed')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 80),
          child: Visibility(
            visible: !noticeVisible,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Pressable(
              label: context.strings.completed,
              expanded: expanded,
              onPressed: dragging ? null : onToggleExpanded,
              scale: 0.99,
              radius: 12,
              builder: (context, state) => TweenAnimationBuilder<double>(
                key: ValueKey(todos.length),
                tween: Tween(begin: 1.025, end: 1),
                duration: AppMotion.duration(context, AppMotion.color),
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          collapseArmed
                              ? context.strings.releaseToClose
                              : context.strings.completed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: AppMotion.duration(context, AppMotion.color),
                        child: Icon(
                          SometimeIcons.caretUp,
                          color: context.appColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
