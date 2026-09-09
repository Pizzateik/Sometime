import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../models/todo.dart';
import 'sometime_segmented_control.dart';

class TodoGroupPicker extends StatelessWidget {
  const TodoGroupPicker({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final TodoGroup value;
  final ValueChanged<TodoGroup> onChanged;
  @override
  Widget build(BuildContext context) => SometimeSegmentedControl<TodoGroup>(
    values: TodoGroup.values,
    value: value,
    label: (group) => context.strings.groupName(group.index),
    onChanged: onChanged,
  );
}
