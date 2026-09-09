import '../state/todo_controller.dart';
import 'notification_service.dart';

Future<bool> applyTaskPinAfterSave({
  required TodoController controller,
  required String spaceId,
  required String todoId,
  required bool currentPinned,
  required bool targetPinned,
}) async {
  if (currentPinned == targetPinned) return true;
  if (targetPinned) {
    final allowed =
        await NotificationService.current?.requestPermission() ?? false;
    if (!allowed) return false;
  }

  controller.setPinned(spaceId, todoId, targetPinned);
  try {
    await controller.flush();
    return true;
  } catch (_) {
    controller.setPinned(spaceId, todoId, currentPinned);
    try {
      await controller.flush();
    } catch (_) {
      // Keep the in-memory state aligned with the rollback when storage fails.
    }
    return false;
  }
}
