import '../models/todo.dart';

class CategoryProgressSession {
  CategoryProgressSession({
    required this.spaceId,
    required this.category,
    required Iterable<String> baselineTaskIds,
    required this.totalCount,
    required this.completedCount,
  }) : baselineTaskIds = Set.unmodifiable(baselineTaskIds);

  final String spaceId;
  final TodoGroup category;
  final Set<String> baselineTaskIds;
  final int totalCount;
  final int completedCount;

  CategoryProgressSession copyWith({int? completedCount}) =>
      CategoryProgressSession(
        spaceId: spaceId,
        category: category,
        baselineTaskIds: baselineTaskIds,
        totalCount: totalCount,
        completedCount: completedCount ?? this.completedCount,
      );
}

class CategoryProgressController {
  final _sessions =
      <({String spaceId, TodoGroup category}), CategoryProgressSession>{};

  CategoryProgressSession? sessionFor(String spaceId, TodoGroup category) =>
      _sessions[(spaceId: spaceId, category: category)];

  CategoryProgressSession recordCompletion({
    required String spaceId,
    required TodoGroup category,
    required Iterable<String> baselineTaskIds,
    required String taskId,
  }) {
    final key = (spaceId: spaceId, category: category);
    final current = _sessions[key];
    if (current == null) {
      final baseline = {...baselineTaskIds, taskId};
      final session = CategoryProgressSession(
        spaceId: spaceId,
        category: category,
        baselineTaskIds: baseline,
        totalCount: baseline.length,
        completedCount: 1,
      );
      _sessions[key] = session;
      return session;
    }
    if (!current.baselineTaskIds.contains(taskId)) return current;
    final session = current.copyWith(
      completedCount: (current.completedCount + 1).clamp(0, current.totalCount),
    );
    _sessions[key] = session;
    return session;
  }

  CategoryProgressSession? recordUncompletion({
    required String spaceId,
    required TodoGroup category,
    required String taskId,
  }) {
    final key = (spaceId: spaceId, category: category);
    final current = _sessions[key];
    if (current == null || !current.baselineTaskIds.contains(taskId)) {
      return current;
    }
    final session = current.copyWith(
      completedCount: (current.completedCount - 1).clamp(0, current.totalCount),
    );
    _sessions[key] = session;
    return session;
  }

  void reset(String spaceId, TodoGroup category) {
    _sessions.remove((spaceId: spaceId, category: category));
  }

  void resetSpace(String spaceId) {
    _sessions.removeWhere((key, _) => key.spaceId == spaceId);
  }

  void clear() => _sessions.clear();
}
