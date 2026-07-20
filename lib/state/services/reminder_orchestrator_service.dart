import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

class ReminderOrchestratorPrefs {
  const ReminderOrchestratorPrefs({
    required this.goalRemindersEnabled,
    required this.habitRemindersEnabled,
    required this.dailyPlanningEnabled,
    required this.dailyPlanningHour,
    required this.dailyPlanningMinute,
  });

  final bool goalRemindersEnabled;
  final bool habitRemindersEnabled;
  final bool dailyPlanningEnabled;
  final int dailyPlanningHour;
  final int dailyPlanningMinute;
}

class ReminderOrchestratorService {
  ReminderOrchestratorService({
    required this._preferences,
    required this._notifications,
    required this._scheduler,
  });

  static const String _goalReminderEnabledKey = 'goal_reminders_enabled';
  static const String _habitReminderEnabledKey = 'habit_reminders_enabled';
  static const String _dailyPlanningEnabledKey =
      'daily_planning_reminder_enabled';
  static const String _dailyPlanningTimeKey = 'daily_planning_reminder_time';

  static const String _habitReminderId = 'habit_reminder_daily';
  static const String _dailyPlanningReminderId = 'daily_planning_reminder';

  final SharedPrefsStore _preferences;
  final NotificationsService _notifications;
  final NotificationScheduler _scheduler;

  ReminderOrchestratorPrefs loadPrefs() {
    final (int hour, int minute) = _dailyPlanningTime();
    return ReminderOrchestratorPrefs(
      goalRemindersEnabled: _isEnabled(
        _goalReminderEnabledKey,
        defaultValue: true,
      ),
      habitRemindersEnabled: _isEnabled(
        _habitReminderEnabledKey,
        defaultValue: true,
      ),
      dailyPlanningEnabled: _isEnabled(
        _dailyPlanningEnabledKey,
        defaultValue: true,
      ),
      dailyPlanningHour: hour,
      dailyPlanningMinute: minute,
    );
  }

  Future<void> setGoalRemindersEnabled(bool enabled) async {
    await _preferences.save(_goalReminderEnabledKey, enabled.toString());
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    await _preferences.save(_habitReminderEnabledKey, enabled.toString());
    if (!enabled) {
      await _notifications.cancel(_habitReminderId);
    }
  }

  Future<void> syncGoalReminders(List<GoalEntity> goals) async {
    if (!_isEnabled(_goalReminderEnabledKey, defaultValue: true)) {
      return;
    }

    for (final GoalEntity goal in goals) {
      final DateTime? targetDate = goal.targetDate;
      if (targetDate == null) {
        continue;
      }

      final DateTime? reminderAt = _resolveGoalReminderAt(targetDate);
      if (reminderAt == null) {
        continue;
      }

      await _notifications.schedule(
        id: _goalReminderId(goal.id),
        title: 'Goal Reminder',
        body: 'Target date is near for "${goal.title}".',
        at: reminderAt,
      );
    }
  }

  Future<void> syncHabitReminders(List<HabitRecord> habits) async {
    if (!_isEnabled(_habitReminderEnabledKey, defaultValue: true)) {
      await _notifications.cancel(_habitReminderId);
      return;
    }

    HabitRecord? activeHabit;
    for (final HabitRecord habit in habits) {
      if (habit.active) {
        activeHabit = habit;
        break;
      }
    }

    if (activeHabit == null) {
      await _notifications.cancel(_habitReminderId);
      return;
    }

    final NotificationScheduleResult result = await _scheduler
        .scheduleDailyAtWithStatus(
      id: _habitReminderId,
      title: 'Habit Reminder',
      body: 'Stay consistent: ${activeHabit.title}',
      hour: 20,
      minute: 0,
    );
    if (result != NotificationScheduleResult.scheduled) {
      Logger.warn('Habit reminder scheduling skipped: $result');
    }
  }

  Future<void> ensureDailyPlanningReminder() async {
    if (!_isEnabled(_dailyPlanningEnabledKey, defaultValue: true)) {
      await _notifications.cancel(_dailyPlanningReminderId);
      return;
    }

    final (int hour, int minute) = _dailyPlanningTime();
    final NotificationScheduleResult result = await _scheduler
        .scheduleDailyAtWithStatus(
      id: _dailyPlanningReminderId,
      title: 'Daily Planning Reminder',
      body: 'Open Planner and set your top 3 execution targets.',
      hour: hour,
      minute: minute,
    );
    if (result != NotificationScheduleResult.scheduled) {
      Logger.warn('Daily planning reminder scheduling skipped: $result');
    }
  }

  Future<void> setDailyPlanningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _preferences.save(_dailyPlanningEnabledKey, enabled.toString());
    await _preferences.save(_dailyPlanningTimeKey, '$hour:$minute');
    await ensureDailyPlanningReminder();
  }

  bool _isEnabled(String key, {required bool defaultValue}) {
    final String? raw = _preferences.load(key);
    if (raw == null) {
      return defaultValue;
    }
    return raw == 'true';
  }

  DateTime? _resolveGoalReminderAt(DateTime targetDate) {
    final DateTime now = DateTime.now();
    final DateTime oneDayBefore = targetDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      return oneDayBefore;
    }
    if (targetDate.isAfter(now)) {
      return targetDate;
    }
    return null;
  }

  String _goalReminderId(String goalId) => 'goal_reminder_$goalId';

  (int, int) _dailyPlanningTime() {
    final String? raw = _preferences.load(_dailyPlanningTimeKey);
    if (raw == null || raw.trim().isEmpty) {
      return (7, 30);
    }

    final List<String> parts = raw.split(':');
    if (parts.length != 2) {
      return (7, 30);
    }

    final int hour = int.tryParse(parts[0]) ?? 7;
    final int minute = int.tryParse(parts[1]) ?? 30;
    return (hour.clamp(0, 23).toInt(), minute.clamp(0, 59).toInt());
  }
}
