import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Notifications
class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledAt,
    this.isEnabled = true,
    this.isRead = false,
    this.scheduleResult,
  });

  /// Whether [id] names a reminder the app registers with the OS, as
  /// opposed to an in-app history entry.
  static bool isReminderId(String id) =>
      id.startsWith('goal_reminder_') ||
      id.startsWith('habit_reminder_') ||
      id.startsWith('task_reminder_') ||
      id == 'daily_planning_reminder' ||
      id == 'reflection_reminder';

  final String id;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final bool isEnabled;
  final bool isRead;

  /// What the OS said when this reminder was last handed to it. Null for
  /// in-app entries and for records stored before this was kept.
  final NotificationScheduleResult? scheduleResult;

  /// A reminder switched off before its time. Older builds kept it as a
  /// disabled record; it never went off, so it is not activity and is never
  /// listed. One whose time has passed went off and stays as history.
  bool isCancelledReminderAt(DateTime now) =>
      !isEnabled && isReminderId(id) && scheduledAt.isAfter(now);

  // Domain behavior
  bool isDueAt(DateTime reference) => reference.isAfter(scheduledAt);

  bool get isDue => isDueAt(DateTime.now());

  Duration timeUntilAt(DateTime reference) => scheduledAt.difference(reference);

  Duration get timeUntil => timeUntilAt(DateTime.now());

  NotificationEntity enable() => copyWith(isEnabled: true);

  NotificationEntity disable() => copyWith(isEnabled: false);

  NotificationEntity markRead() => copyWith(isRead: true);

  NotificationEntity markUnread() => copyWith(isRead: false);

  bool contains(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) || message.toLowerCase().contains(q);
  }

  void validate() {
    if (title.trim().isEmpty) {
      throw StateError('NotificationEntity must have a title');
    }
  }

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? scheduledAt,
    bool? isEnabled,
    bool? isRead,
    NotificationScheduleResult? scheduleResult,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isEnabled: isEnabled ?? this.isEnabled,
      isRead: isRead ?? this.isRead,
      scheduleResult: scheduleResult ?? this.scheduleResult,
    );
  }
}
