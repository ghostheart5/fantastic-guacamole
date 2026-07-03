import 'package:fantastic_guacamole/data/models/notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsProvider =
    NotifierProvider<NotificationController, List<ChronoNotification>>(
      NotificationController.new,
    );

class NotificationController extends Notifier<List<ChronoNotification>> {
  @override
  List<ChronoNotification> build() => <ChronoNotification>[];

  void push(ChronoNotification notification) {
    state = [notification, ...state];
  }

  void pushDecision(String taskTitle) {
    push(
      ChronoNotification(
        id: 'decision-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Decision Alert',
        message: 'Selected $taskTitle as the current focus target.',
        type: ChronoNotificationType.primaryDecisionAlert,
        priority: ChronoNotificationPriority.low,
        timestamp: DateTime.now(),
      ),
    );
  }

  void pushCompletionFeedback(String taskTitle) {
    push(
      ChronoNotification(
        id: 'complete-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Completion',
        message: '$taskTitle completed. Recomputing next move.',
        type: ChronoNotificationType.completionFeedback,
        priority: ChronoNotificationPriority.medium,
        timestamp: DateTime.now(),
      ),
    );
  }

  void pushTaskSkipped(String taskTitle) {
    push(
      ChronoNotification(
        id: 'skip-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Task Skipped',
        message: '$taskTitle skipped. SI will adapt the next pick.',
        type: ChronoNotificationType.overloadWarning,
        priority: ChronoNotificationPriority.medium,
        timestamp: DateTime.now(),
      ),
    );
  }

  void clear() {
    state = [];
  }

  void dismiss(int index) {
    final newList = [...state];
    newList.removeAt(index);
    state = newList;
  }
}

final notificationProvider = notificationsProvider;
