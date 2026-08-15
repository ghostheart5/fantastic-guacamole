import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
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
    required this.storageScope,
  });

  static const String _goalReminderEnabledKey = 'goal_reminders_enabled';
  static const String _habitReminderEnabledKey = 'habit_reminders_enabled';
  static const String _dailyPlanningEnabledKey =
      'daily_planning_reminder_enabled';
  static const String _dailyPlanningTimeKey = 'daily_planning_reminder_time';

  static const String _scheduleRegistryPrefix = 'reminder_schedule_registry_v2';

  final SharedPrefsStore _preferences;
  final NotificationsService _notifications;
  final NotificationScheduler _scheduler;
  final AccountStorageScope storageScope;
  bool _cancelled = false;
  Future<void> _operationTail = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _operationTail.catchError((Object _) {});
  }

  /// Cancels only the device-side reminder schedules registered to [outgoingScope].
  /// Durable reminder preferences are deliberately not changed.
  Future<void> cancelScheduledRemindersForAccount(
    AccountStorageScope outgoingScope,
  ) async {
    final String registryKey = _registryKeyFor(outgoingScope);
    final List<String> ids = _loadRegisteredIds(registryKey);
    for (final String id in ids) {
      await _notifications.cancel(id);
    }
    await _preferences.delete(registryKey);
  }

  /// Records an externally-produced platform reminder under its owning scope.
  Future<void> registerScheduledReminder({
    required AccountStorageScope scope,
    required String id,
  }) async {
    if (_cancelled) {
      return;
    }
    final String registryKey = _registryKeyFor(scope);
    final List<String> ids = _loadRegisteredIds(registryKey);
    if (!ids.contains(id)) {
      await _preferences.save(registryKey, jsonEncode(<String>[...ids, id]));
    }
  }

  /// Cancels an owned platform reminder and removes its registry entry only
  /// after cancellation succeeds, retaining retry evidence on failure.
  Future<void> cancelRegisteredReminder({
    required AccountStorageScope scope,
    required String id,
  }) async {
    final String registryKey = _registryKeyFor(scope);
    final List<String> ids = _loadRegisteredIds(registryKey);
    await _notifications.cancel(id);
    await _preferences.save(
      registryKey,
      jsonEncode(ids.where((String item) => item != id).toList()),
    );
  }

  Future<void> cancelRegisteredKind({
    required AccountStorageScope scope,
    required String kind,
  }) async {
    final String registryKey = _registryKeyFor(scope);
    final List<String> ids = _loadRegisteredIds(registryKey);
    for (final String id in ids.where((String id) => id.startsWith('reminder.$kind.'))) {
      await cancelRegisteredReminder(scope: scope, id: id);
    }
  }

  void dispose() => _cancelled = true;

  Future<void> _serialize(Future<void> Function() operation) {
    final Future<void> previous = _operationTail.catchError((Object _) {});
    final Future<void> next = previous.then((_) async {
      if (!_cancelled) await operation();
    });
    _operationTail = next;
    return next;
  }

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

  Future<void> setGoalRemindersEnabled(bool enabled) => _serialize(() async {
    await _preferences.save(_goalReminderEnabledKey, enabled.toString());
  });

  Future<void> setHabitRemindersEnabled(bool enabled) => _serialize(() async {
    await _preferences.save(_habitReminderEnabledKey, enabled.toString());
    if (!enabled) {
      await _cancelRegisteredKind('habit');
    }
  });

  Future<void> syncGoalReminders(List<GoalEntity> goals) =>
      _serialize(() async {
        if (!_canSchedule) return;
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

          final String id = _reminderId('goal', goal.id);
          await _notifications.schedule(
            id: id,
            title: 'Goal Reminder',
            body: 'Target date is near for "${goal.title}".',
            at: reminderAt,
          );
          await _register(id);
        }
      });

  Future<void> syncHabitReminders(List<HabitRecord> habits) =>
      _serialize(() async {
        if (!_canSchedule) return;
        if (!_isEnabled(_habitReminderEnabledKey, defaultValue: true)) {
          await _cancelRegisteredKind('habit');
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
          await _cancelRegisteredKind('habit');
          return;
        }

        final NotificationScheduleResult result = await _scheduler
            .scheduleDailyAtWithStatus(
              id: _reminderId('habit', activeHabit.id),
              title: 'Habit Reminder',
              body: 'Stay consistent: ${activeHabit.title}',
              hour: 20,
              minute: 0,
            );
        if (result != NotificationScheduleResult.scheduled) {
          Logger.warn('Habit reminder scheduling skipped: $result');
        } else {
          await _register(_reminderId('habit', activeHabit.id));
        }
      });

  Future<void> ensureDailyPlanningReminder() =>
      _serialize(_ensureDailyPlanningReminder);

  Future<void> _ensureDailyPlanningReminder() async {
    if (!_canSchedule) return;
    if (!_isEnabled(_dailyPlanningEnabledKey, defaultValue: true)) {
      await _cancelRegisteredKind('daily_planning');
      return;
    }

    final (int hour, int minute) = _dailyPlanningTime();
    final NotificationScheduleResult result = await _scheduler
        .scheduleDailyAtWithStatus(
          id: _reminderId('daily_planning', 'default'),
          title: 'Daily Planning Reminder',
          body: 'Open Planner and set your top 3 execution targets.',
          hour: hour,
          minute: minute,
        );
    if (result != NotificationScheduleResult.scheduled) {
      Logger.warn('Daily planning reminder scheduling skipped: $result');
    } else {
      await _register(_reminderId('daily_planning', 'default'));
    }
  }

  Future<void> setDailyPlanningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) => _serialize(() async {
    await _preferences.save(_dailyPlanningEnabledKey, enabled.toString());
    await _preferences.save(_dailyPlanningTimeKey, '$hour:$minute');
    await _ensureDailyPlanningReminder();
  });

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

  bool get _canSchedule =>
      !_cancelled &&
      storageScope.isAuthenticated &&
      storageScope.v2Namespace != null;

  String _reminderId(String kind, String sourceId) {
    return 'reminder.$kind.${storageScope.v2Namespace}.$sourceId';
  }

  String _registryKeyFor(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isAuthenticated || namespace == null) {
      throw StateError(
        'Reminder schedule ownership requires an authenticated scope.',
      );
    }
    return '$_scheduleRegistryPrefix.$namespace';
  }

  List<String> _loadRegisteredIds(String key) {
    final String? raw = _preferences.load(key);
    if (raw == null || raw.trim().isEmpty) return <String>[];
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.whereType<String>().toList(growable: false)
          : <String>[];
    } on Object {
      return <String>[];
    }
  }

  Future<void> _register(String id) async {
    await registerScheduledReminder(scope: storageScope, id: id);
  }

  Future<void> _cancelRegisteredKind(String kind) async {
    await cancelRegisteredKind(scope: storageScope, kind: kind);
  }

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
