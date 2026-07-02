class ChronoNotification {
  const ChronoNotification({
    required this.id,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    this.title = '',
  });

  final String id;
  final String title;
  final String message;
  final ChronoNotificationType type;
  final ChronoNotificationPriority priority;
  final DateTime timestamp;
}

enum ChronoNotificationType {
  info,
  success,
  warning,
  primaryDecisionAlert,
  overloadWarning,
  energyAdjustment,
  siInsight,
  temporalAlert,
  completionFeedback,
  systemPrompt,
}

enum ChronoNotificationPriority { low, medium, high }
