import 'package:flutter/foundation.dart';

@immutable
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.focusReminders = true,
    this.taskReminders = true,
    this.streakAlerts = true,
    this.dailySummary = false,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
  });

  final bool enabled;
  final bool focusReminders;
  final bool taskReminders;
  final bool streakAlerts;
  final bool dailySummary;
  final int quietHoursStart;
  final int quietHoursEnd;

  bool get isQuietHour {
    final hour = DateTime.now().hour;
    if (quietHoursStart > quietHoursEnd) {
      return hour >= quietHoursStart || hour < quietHoursEnd;
    }
    return hour >= quietHoursStart && hour < quietHoursEnd;
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? focusReminders,
    bool? taskReminders,
    bool? streakAlerts,
    bool? dailySummary,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      focusReminders: focusReminders ?? this.focusReminders,
      taskReminders: taskReminders ?? this.taskReminders,
      streakAlerts: streakAlerts ?? this.streakAlerts,
      dailySummary: dailySummary ?? this.dailySummary,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'focusReminders': focusReminders,
    'taskReminders': taskReminders,
    'streakAlerts': streakAlerts,
    'dailySummary': dailySummary,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        enabled: json['enabled'] as bool? ?? true,
        focusReminders: json['focusReminders'] as bool? ?? true,
        taskReminders: json['taskReminders'] as bool? ?? true,
        streakAlerts: json['streakAlerts'] as bool? ?? true,
        dailySummary: json['dailySummary'] as bool? ?? false,
        quietHoursStart: (json['quietHoursStart'] as num?)?.toInt() ?? 22,
        quietHoursEnd: (json['quietHoursEnd'] as num?)?.toInt() ?? 8,
      );
}
