enum SystemEvent {
  bootComplete,
  sessionStarted,
  sessionEnded,
  taskCompleted,
  taskSkipped,
  energyUpdated,
  syncRequested,
  syncComplete,
  syncFailed,
  notificationScheduled,
  notificationDismissed,
  settingsChanged,
  errorOccurred,
}

class SystemEventPayload {
  SystemEventPayload({required this.event, this.data = const {}})
    : timestamp = DateTime.now();

  final SystemEvent event;
  final Map<String, dynamic> data;
  final DateTime timestamp;
}
