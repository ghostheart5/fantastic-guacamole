import 'behavior_entities.dart';
import 'local_notification_service.dart';

enum ChronoNotificationType {
  primaryDecisionAlert,
  overloadWarning,
  energyAdjustment,
  siInsight,
  temporalAlert,
  completionFeedback,
  systemPrompt,
}

enum ChronoNotificationPriority { high, medium, low }

class ChronoNotification {
  const ChronoNotification({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.priority,
    required this.message,
  });

  final String id;
  final DateTime timestamp;
  final ChronoNotificationType type;
  final ChronoNotificationPriority priority;
  final String message;
}

class NotificationManager {
  DateTime _lastActivity = DateTime.now();
  String _lastDecisionText = '';
  final Map<ChronoNotificationType, DateTime> _lastSentByType =
      <ChronoNotificationType, DateTime>{};
  int _acknowledged = 0;
  int _dismissed = 0;

  List<ChronoNotification> evaluate({
    required ChronoUserState state,
    required ChronoDecision decision,
    required List<ChronoTask> tasks,
    DateTime? now,
  }) {
    final DateTime stamp = now ?? DateTime.now();
    final List<ChronoNotification> notifications = <ChronoNotification>[];

    if (decision.primaryAction != _lastDecisionText) {
      _addIfAllowed(
        notifications: notifications,
        stamp: stamp,
        type: ChronoNotificationType.primaryDecisionAlert,
        priority: ChronoNotificationPriority.high,
        message: 'Focus on this now: ${decision.primaryAction}',
      );
      _lastDecisionText = decision.primaryAction;
    }

    final int pendingCount = tasks
        .where((ChronoTask t) => t.status == ChronoTaskStatus.pending)
        .length;
    final bool overloaded = pendingCount > 5 || state.cognitiveLoad >= 0.82;
    if (overloaded) {
      _addIfAllowed(
        notifications: notifications,
        stamp: stamp,
        type: ChronoNotificationType.overloadWarning,
        priority: ChronoNotificationPriority.high,
        message: 'System overload detected. Reduce workload.',
      );
    }

    if (state.energy <= 0.35 || state.energy >= 0.92) {
      _addIfAllowed(
        notifications: notifications,
        stamp: stamp,
        type: ChronoNotificationType.energyAdjustment,
        priority: ChronoNotificationPriority.medium,
        message: state.energy <= 0.35
            ? 'Low energy detected. Shift to lighter tasks.'
            : 'Energy spike detected. Use deep-work tasks now.',
      );
    }

    if (state.focusLevel >= 0.75 && state.mood >= 0.6) {
      _addIfAllowed(
        notifications: notifications,
        stamp: stamp,
        type: ChronoNotificationType.siInsight,
        priority: ChronoNotificationPriority.low,
        message: 'You are in a high-focus pattern. Extend this block?',
      );
    }

    final bool timelineAtRisk =
        state.timeAvailable.inMinutes < 45 &&
        pendingCount > 0 &&
        tasks.any((ChronoTask t) => t.priority >= 8);
    if (timelineAtRisk) {
      _addIfAllowed(
        notifications: notifications,
        stamp: stamp,
        type: ChronoNotificationType.temporalAlert,
        priority: ChronoNotificationPriority.medium,
        message: 'Schedule fracture detected. Reorganizing timeline.',
      );
    }

    if (stamp.difference(_lastActivity).inMinutes >= 90) {
      _addIfAllowed(
        notifications: notifications,
        stamp: stamp,
        type: ChronoNotificationType.systemPrompt,
        priority: ChronoNotificationPriority.low,
        message: 'You paused. Resume execution or revise plan?',
      );
    }

    return notifications;
  }

  ChronoNotification completionFeedback({String? title, DateTime? now}) {
    final DateTime stamp = now ?? DateTime.now();
    return _create(
      stamp: stamp,
      type: ChronoNotificationType.completionFeedback,
      priority: ChronoNotificationPriority.low,
      message: title == null ? 'Mission progress confirmed.' : 'Mission progress confirmed: $title',
    );
  }

  void markActivity([DateTime? now]) {
    _lastActivity = now ?? DateTime.now();
  }

  void recordResponse({required bool acknowledged}) {
    if (acknowledged) {
      _acknowledged += 1;
    } else {
      _dismissed += 1;
    }
  }

  void triggerNotification(String message) {
    Future<void>.microtask(() async {
      try {
        await LocalNotificationService.instance.showNow(
          title: 'ChronoSpark',
          body: message,
        );
      } catch (_) {
        // Keep console logging as a fallback when local notifications fail.
      }
    });

    // Keep a debug trail for terminal sessions.
    // ignore: avoid_print
    print('NOTIFY: $message');
  }

  ChronoNotification _create({
    required DateTime stamp,
    required ChronoNotificationType type,
    required ChronoNotificationPriority priority,
    required String message,
  }) {
    return ChronoNotification(
      id: '${stamp.microsecondsSinceEpoch}-${type.name}',
      timestamp: stamp,
      type: type,
      priority: priority,
      message: message,
    );
  }

  void _addIfAllowed({
    required List<ChronoNotification> notifications,
    required DateTime stamp,
    required ChronoNotificationType type,
    required ChronoNotificationPriority priority,
    required String message,
  }) {
    final DateTime? last = _lastSentByType[type];
    final Duration cooldown = _cooldownFor(priority);
    if (last != null && stamp.difference(last) < cooldown) {
      return;
    }

    final ChronoNotification created = _create(
      stamp: stamp,
      type: type,
      priority: priority,
      message: message,
    );
    notifications.add(created);
    _lastSentByType[type] = stamp;
  }

  Duration _cooldownFor(ChronoNotificationPriority priority) {
    final int totalResponses = _acknowledged + _dismissed;
    final double engagement = totalResponses == 0 ? 0.5 : _acknowledged / totalResponses;
    final double multiplier = 1.5 - (engagement * 0.8);

    final Duration base = switch (priority) {
      ChronoNotificationPriority.high => const Duration(minutes: 8),
      ChronoNotificationPriority.medium => const Duration(minutes: 20),
      ChronoNotificationPriority.low => const Duration(minutes: 45),
    };
    return Duration(milliseconds: (base.inMilliseconds * multiplier).round());
  }
}
