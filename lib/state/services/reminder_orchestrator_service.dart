import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/l10n/app_language.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

part 'reminder_orchestrator_service.copy.dart';
part 'reminder_orchestrator_service.habits.dart';
part 'reminder_orchestrator_service.quiet_hours.dart';
part 'reminder_orchestrator_service.reconcile.dart';
part 'reminder_orchestrator_service.tasks.dart';

class ReminderOrchestratorPrefs {
  const ReminderOrchestratorPrefs({
    required this.goalRemindersEnabled,
    required this.habitRemindersEnabled,
    required this.dailyPlanningEnabled,
    required this.dailyPlanningHour,
    required this.dailyPlanningMinute,
    this.taskRemindersEnabled = false,
    this.taskOverdueNudgesEnabled = false,
    this.taskReminderLeadMinutes = 0,
    this.remindersEnabled = true,
    this.quietHours = const QuietHours(),
  });

  /// The main switch. Off, the account has no OS reminders at all; each
  /// feature keeps its own choice for when it is turned back on.
  final bool remindersEnabled;

  /// Off unless the person sets it.
  final QuietHours quietHours;

  final bool goalRemindersEnabled;
  final bool habitRemindersEnabled;
  final bool dailyPlanningEnabled;
  final int dailyPlanningHour;
  final int dailyPlanningMinute;

  /// Stored default is on; see [ReminderOrchestratorService.loadPrefs].
  final bool taskRemindersEnabled;

  /// One "still open" nudge the morning after a task's deadline. Off unless
  /// the person turns it on.
  final bool taskOverdueNudgesEnabled;

  /// Minutes before a task's start or due time its reminder arrives.
  final int taskReminderLeadMinutes;
}

class ReminderOrchestratorService {
  ReminderOrchestratorService({
    required this._preferences,
    required this._notifications,
    required this._scheduler,
    required this._accountScope,
    this._loadHabitOccurrences,
    this._loadGoalTasks,
    this._loadTasks,
    DateTime Function()? now,
    String Function()? timeZoneName,
    bool Function()? isSpanish,
  }) : _now = now ?? DateTime.now,
       _timeZoneName = timeZoneName ?? _deviceTimeZoneName,
       _isSpanish = isSpanish ?? appLanguageIsSpanish;

  /// The main reminder switch; missing means on, as before it existed.
  static const String remindersEnabledKey = 'reminders_enabled';

  /// The one-off "rebuild your streak" nudge (see the profile controller).
  /// It goes through the notification list, not the reconciler, so a full
  /// reconcile with the main switch off cancels it separately.
  static const String streakBreakIdPrefix = 'streak_break_recovery_';
  static const String _quietHoursEnabledKey = 'quiet_hours_enabled';
  static const String _quietHoursStartKey = 'quiet_hours_start';
  static const String _quietHoursEndKey = 'quiet_hours_end';

  /// The task lead times offered in Settings, in minutes.
  static const List<int> taskLeadChoices = <int>[0, 5, 15, 30, 60];

  static const String _goalReminderEnabledKey = 'goal_reminders_enabled';
  static const String _habitReminderEnabledKey = 'habit_reminders_enabled';
  static const String _taskReminderEnabledKey = 'task_reminders_enabled';
  static const String _taskOverdueNudgesKey = 'task_overdue_nudges_enabled';
  static const String _taskReminderLeadKey = 'task_reminder_lead_minutes';

  /// When a change could have let a lead-time reminder be missed (see
  /// [TaskReminderPlanner.plan]).
  static const String _taskRulesChangedAtKey = 'task_reminder_rules_changed_at';
  static const String _scheduledTaskReminderIdsKey =
      'scheduled_task_reminder_ids';
  static const String _dailyPlanningEnabledKey =
      'daily_planning_reminder_enabled';
  static const String _dailyPlanningTimeKey = 'daily_planning_reminder_time';
  static const String _scheduledGoalReminderIdsKey =
      'scheduled_goal_reminder_ids';

  static const String _scheduledHabitReminderIdsKey =
      'scheduled_habit_reminder_ids';
  static const String _goalCloseNudgesKey = 'goal_close_nudges';

  /// When each goal's "due today" reminder was planned for its target date.
  static const String _goalDueTodayTimesKey = 'goal_due_today_times';

  /// Deadline and "almost there" goal reminders arrive at this local hour,
  /// never at midnight (target dates carry no time of day).
  static const int goalReminderHour = 9;

  /// A goal due today whose morning reminder time has already passed gets one
  /// reminder at this local hour, if it is still [goalSameDayLead] away.
  static const int goalSameDayHour = 18;
  static const Duration goalSameDayLead = Duration(minutes: 30);

  /// Older builds registered one shared 8 PM rhythm reminder under this id.
  /// [migrateLegacyHabitReminder] replaces it with per-rhythm times; until
  /// then no other path may erase it (see [_keepsLegacyHabitReminder]).
  static const String _legacyHabitReminderId = 'habit_reminder_daily';
  static const int _legacyReminderMinutes = 20 * 60;
  static const String _legacyHabitMigrationDoneKey =
      'legacy_habit_reminder_migrated';
  static const String dailyPlanningReminderId = 'daily_planning_reminder';

  /// Every goal reminder id: this, the goal id and, for all but the
  /// day-before reminder, a slot suffix (see [_goalSlotIds]).
  static const String goalReminderPrefix = 'goal_reminder_';

  /// Every rhythm reminder id, including the old shared one: this, the habit
  /// id and, for a chosen weekday, `_wd<1-7>`.
  static const String habitReminderPrefix = 'habit_reminder_';

  static bool ownsGoalReminderId(String id) =>
      id.startsWith(goalReminderPrefix);

  static bool ownsHabitReminderId(String id) =>
      id.startsWith(habitReminderPrefix);

  final SharedPrefsStore _preferences;
  final NotificationsService _notifications;
  final NotificationSchedulerPort _scheduler;
  final String? _accountScope;
  final Future<List<HabitOccurrenceEntity>> Function()? _loadHabitOccurrences;
  final Future<List<TaskEntity>> Function()? _loadGoalTasks;

  /// Every task of this account, for task reminders. Without it the task
  /// group is left out of reconciles.
  final Future<List<TaskEntity>> Function()? _loadTasks;
  final DateTime Function() _now;
  final String Function() _timeZoneName;

  /// Whether reminder text is written in Spanish: asked each time reminders
  /// are planned, so they follow the app language (see
  /// [appLanguageIsSpanish]). Changing it changes the fingerprints, so the
  /// next update replaces every registration.
  final bool Function() _isSpanish;
  final ValueNotifier<NotificationScheduleResult?> _lastHabitReminderResult =
      ValueNotifier<NotificationScheduleResult?>(null);

  /// How the latest rhythm reminder sync or reconcile ended for this
  /// account: [NotificationScheduleResult.scheduled] when every wanted rhythm
  /// reminder is registered (or none is wanted), the reason none could be
  /// registered, or [NotificationScheduleResult.failed]. Null until one ran.
  ValueListenable<NotificationScheduleResult?> get lastHabitReminderResult =>
      _lastHabitReminderResult;

  final ValueNotifier<NotificationScheduleResult?> _lastReminderResult =
      ValueNotifier<NotificationScheduleResult?>(null);

  /// How the latest full reminder update ([reconcileAfterRestore]) ended for
  /// this account, across every kind of reminder: the most telling result
  /// (see [_worseResult]). Null until one ran.
  ValueListenable<NotificationScheduleResult?> get lastReminderResult =>
      _lastReminderResult;

  static String _deviceTimeZoneName() {
    try {
      return tz.local.name;
    } on Object {
      return '';
    }
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
      taskRemindersEnabled: _isEnabled(
        _taskReminderEnabledKey,
        defaultValue: true,
      ),
      taskOverdueNudgesEnabled: _isEnabled(
        _taskOverdueNudgesKey,
        defaultValue: false,
      ),
      taskReminderLeadMinutes: _taskReminderLeadMinutes(),
      remindersEnabled: _remindersOn(),
      quietHours: _quietHours(),
    );
  }

  bool _remindersOn() => _isEnabled(remindersEnabledKey, defaultValue: true);

  /// Saves the main switch. The caller then runs the full reconcile, which
  /// cancels every OS reminder (off) or registers them again (on).
  Future<void> setRemindersEnabled(bool enabled) async {
    final bool changed = _remindersOn() != enabled;
    await _preferences.save(remindersEnabledKey, enabled.toString());
    if (changed) await _markTaskRulesChanged();
  }

  /// Lists the one-off "rebuild your streak" nudge and hands it to the OS,
  /// unless the main reminder switch is off: then nothing is listed or
  /// registered. Returns whether it was scheduled.
  Future<bool> scheduleStreakBreakNudge({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) => KeyedMutationCoordinator.shared.runExclusive<bool>(
    AccountDataRegistry.notificationMutationKeyForScope(
      _accountScope ?? 'legacy',
    ),
    () async {
      if (!_remindersOn()) return false;
      await _notifications.schedule(id: id, title: title, body: body, at: at);
      return true;
    },
  );

  /// Applied by the next reconcile (the caller runs one).
  Future<void> setTaskOverdueNudgesEnabled(bool enabled) =>
      _preferences.save(_taskOverdueNudgesKey, enabled.toString());

  /// Applied by the next reconcile (the caller runs one).
  Future<void> setTaskReminderLeadMinutes(int minutes) async {
    final int value = minutes.clamp(0, 24 * 60).toInt();
    final bool changed = _taskReminderLeadMinutes() != value;
    await _preferences.save(_taskReminderLeadKey, value.toString());
    if (changed) await _markTaskRulesChanged();
  }

  /// Applied by the next reconcile (the caller runs one).
  Future<void> setQuietHours(QuietHours quietHours) async {
    String time(int minutes) => '${minutes ~/ 60}:${minutes % 60}';
    await _preferences.save(_quietHoursStartKey, time(quietHours.startMinutes));
    await _preferences.save(_quietHoursEndKey, time(quietHours.endMinutes));
    await _preferences.save(
      _quietHoursEnabledKey,
      quietHours.enabled.toString(),
    );
  }

  /// [at] moved out of the stored quiet hours, for reminders whose time the
  /// app picks itself.
  DateTime _appTimed(DateTime at) => _quietHours().moveOut(at);

  /// Off cancels every task reminder right away; on is applied by the next
  /// reconcile (the caller runs one).
  Future<void> setTaskRemindersEnabled(bool enabled) async {
    final bool changed =
        _isEnabled(_taskReminderEnabledKey, defaultValue: true) != enabled;
    await _preferences.save(_taskReminderEnabledKey, enabled.toString());
    if (changed) await _markTaskRulesChanged();
    if (!enabled) {
      await KeyedMutationCoordinator.shared.runExclusive<void>(
        AccountDataRegistry.notificationMutationKeyForScope(
          _accountScope ?? 'legacy',
        ),
        _cancelTaskReminders,
      );
    }
  }

  /// Brings only the task reminders in line with the stored tasks, the same
  /// way [reconcileAfterRestore] does for every group. Every task write ends
  /// here (see the task reminder sync provider).
  Future<bool> syncTaskReminders({
    required bool permissionGranted,
    required bool Function() shouldContinue,
  }) {
    return KeyedMutationCoordinator.shared.runExclusive<bool>(
      AccountDataRegistry.notificationMutationKeyForScope(
        _accountScope ?? 'legacy',
      ),
      () async {
        final load = _loadTasks;
        if (load == null || !shouldContinue()) return false;
        return _runGroups(
          <(String, Future<_ReminderGroup> Function())>[
            (
              'tasks',
              () => _planTaskGroup(load, permissionGranted: permissionGranted),
            ),
          ],
          permissionGranted: permissionGranted,
          shouldContinue: shouldContinue,
          everyGroup: false,
        );
      },
    );
  }

  Future<void> setGoalRemindersEnabled(bool enabled) async {
    await _preferences.save(_goalReminderEnabledKey, enabled.toString());
    if (!enabled) {
      await KeyedMutationCoordinator.shared.runExclusive<void>(
        AccountDataRegistry.notificationMutationKeyForScope(
          _accountScope ?? 'legacy',
        ),
        _cancelTrackedGoalReminders,
      );
    }
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    await _preferences.save(_habitReminderEnabledKey, enabled.toString());
    if (!enabled) {
      await KeyedMutationCoordinator.shared.runExclusive<void>(
        AccountDataRegistry.notificationMutationKeyForScope(
          _accountScope ?? 'legacy',
        ),
        _cancelHabitReminders,
      );
    }
  }

  /// Cancels every rhythm reminder. Turned off, the old shared reminder goes
  /// too (the user's choice wins), but [_legacyIdToKeepTracked] keeps the
  /// sign that this account had it for the migration.
  Future<void> _cancelHabitReminders() async {
    final bool keepLegacy = _keepsLegacyHabitReminder();
    final bool trackLegacy = await _legacyIdToKeepTracked(keepLegacy);
    final Set<String> ids = _habitReminderIdsToCancel(keepLegacy);
    await _forgetFingerprints(ids);
    for (final String id in ids) {
      await _notifications.cancel(id);
    }
    await _saveTrackedHabitReminderIds(<String>{
      if (trackLegacy) _legacyHabitReminderId,
    });
  }

  /// Registers each active goal's reminders: three days before, the day
  /// before and the morning of its target date (all at [goalReminderHour]),
  /// plus one "almost there" nudge once most of its linked steps are done.
  Future<void> syncGoalReminders(
    List<GoalEntity> goals, {
    bool Function()? shouldContinue,
  }) => KeyedMutationCoordinator.shared.runExclusive<void>(
    AccountDataRegistry.notificationMutationKeyForScope(
      _accountScope ?? 'legacy',
    ),
    () => _syncGoalReminders(goals, shouldContinue: shouldContinue),
  );

  Future<void> _syncGoalReminders(
    List<GoalEntity> goals, {
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return;
    if (!_isEnabled(_goalReminderEnabledKey, defaultValue: true) ||
        !_remindersOn()) {
      await _cancelTrackedGoalReminders(shouldContinue: shouldContinue);
      return;
    }

    final Map<String, GoalProgressView>? progress = await _goalProgress();
    if (shouldContinue?.call() == false) return;
    final DateTime now = _now();
    final Set<String> previousIds = _trackedGoalReminderIds();
    final Map<String, DateTime> previousNudges = _goalCloseNudges();
    final Map<String, DateTime> nextNudges = <String, DateTime>{};
    final Map<String, DateTime> previousDueTimes = _goalDueTodayTimes();
    final Map<String, DateTime> nextDueTimes = <String, DateTime>{};
    final bool overdueNudges = loadPrefs().taskOverdueNudgesEnabled;
    final Set<String> scheduledIds = <String>{};
    // Everything below may change these registrations; the reconciler only
    // trusts what is recorded again once registered.
    await _forgetFingerprints(<String>{
      for (final String id in <String>{
        ...previousIds,
        ...goals.map((GoalEntity goal) => goal.id),
      })
        ..._goalSlotIds(id),
    });
    final List<_PlannedReminder> registered = <_PlannedReminder>[];
    for (final GoalEntity goal in goals) {
      if (shouldContinue?.call() == false) return;
      if (goal.isCompleted) continue;
      final List<GoalReminderSlot> slots = goalReminderSlots(
        goal,
        progress: progress?[goal.id] ?? const GoalProgressView.empty(),
        progressKnown: progress != null,
        now: now,
        previousNudges: previousNudges,
        nextNudges: nextNudges,
        overdueNudges: overdueNudges,
        previousDueTimes: previousDueTimes,
        nextDueTimes: nextDueTimes,
      );
      for (final GoalReminderSlot slot in slots) {
        if (shouldContinue?.call() == false) return;
        if (await _scheduleGoalSlot(slot)) {
          registered.add(_goalReminder(slot));
        }
      }
      if (previousIds.contains(goal.id)) {
        final Set<String> wanted = slots.map((slot) => slot.id).toSet();
        for (final String id in _goalSlotIds(goal.id).difference(wanted)) {
          if (shouldContinue?.call() == false) return;
          await _cancelGoalSlot(id);
        }
      }
      if (slots.isNotEmpty) scheduledIds.add(goal.id);
    }
    if (shouldContinue?.call() == false) return;
    for (final String removedId in previousIds.difference(scheduledIds)) {
      if (shouldContinue?.call() == false) return;
      if (goals.any((goal) => goal.id == removedId && !goal.isCompleted)) {
        continue; // Its unused slots were already cancelled above.
      }
      for (final String id in _goalSlotIds(removedId)) {
        await _cancelGoalSlot(id);
      }
    }
    if (shouldContinue?.call() == false) return;
    await _saveTrackedGoalReminderIds(scheduledIds);
    await _saveGoalCloseNudges(nextNudges);
    await _saveGoalDueTodayTimes(
      _confirmedDueTimes(
        nextDueTimes,
        previousDueTimes,
        registered: (String goalId, DateTime at) => registered.any(
          (_PlannedReminder item) =>
              item.id == '${_goalReminderId(goalId)}_due' &&
              item.at.isAtSameMomentAs(_appTimed(at)),
        ),
      ),
    );
    await _rememberFingerprints(registered);
  }

  /// The "due today" times to remember: those already remembered, and newly
  /// chosen ones only once [registered] confirms the OS holds them. A time
  /// that was never registered (notifications off, a failed registration) is
  /// decided again on the next run, so turning notifications on after 9 AM on
  /// the target date still gets the evening reminder.
  Map<String, DateTime> _confirmedDueTimes(
    Map<String, DateTime> next,
    Map<String, DateTime> previous, {
    required bool Function(String goalId, DateTime at) registered,
  }) => <String, DateTime>{
    for (final MapEntry<String, DateTime> entry in next.entries)
      if (previous[entry.key]?.isAtSameMomentAs(entry.value) == true ||
          registered(entry.key, entry.value))
        entry.key: entry.value,
  };

  /// Brings only the goal reminders in line with [goals] and their linked
  /// tasks, changing what differs. Every task write that touches a goal's
  /// steps ends here (see the goal reminder sync provider).
  Future<bool> syncGoalReminderGroup({
    required List<GoalEntity> goals,
    required bool permissionGranted,
    required bool Function() shouldContinue,
  }) {
    return KeyedMutationCoordinator.shared.runExclusive<bool>(
      AccountDataRegistry.notificationMutationKeyForScope(
        _accountScope ?? 'legacy',
      ),
      () async {
        if (!shouldContinue()) return false;
        return _runGroups(
          <(String, Future<_ReminderGroup> Function())>[
            ('goals', () => _planGoalGroup(goals, permissionGranted)),
          ],
          permissionGranted: permissionGranted,
          shouldContinue: shouldContinue,
          everyGroup: false,
        );
      },
    );
  }

  /// Gives every active rhythm that has its own reminder time a repeating
  /// reminder at that time. Rhythms without a time get no reminder.
  Future<void> syncHabitReminders(
    List<HabitEntity> habits, {
    bool Function()? shouldContinue,
  }) => KeyedMutationCoordinator.shared.runExclusive<void>(
    AccountDataRegistry.notificationMutationKeyForScope(
      _accountScope ?? 'legacy',
    ),
    () async {
      if (shouldContinue?.call() == false) return;
      if (!_isEnabled(_habitReminderEnabledKey, defaultValue: true) ||
          !_remindersOn() ||
          !habits.any(_wantsReminder)) {
        // The notification repository carries this account's cancellation
        // scope even when scheduling initialization was skipped.
        await _cancelHabitReminders();
        _lastHabitReminderResult.value = NotificationScheduleResult.scheduled;
        return;
      }
      final NotificationScheduleResult? result;
      try {
        result = await _scheduleHabits(habits, shouldContinue: shouldContinue);
      } on Object {
        if (shouldContinue?.call() != false) {
          _lastHabitReminderResult.value = NotificationScheduleResult.failed;
        }
        rethrow;
      }
      if (result == null || shouldContinue?.call() == false) return;
      _lastHabitReminderResult.value = result;
      // Missing permission or an unsupported platform is a known state for
      // the caller to explain, not a failed update.
      if (result == NotificationScheduleResult.failed) {
        throw StateError('Rhythm reminder could not update.');
      }
    },
  );

  /// One-time upgrade step for the old shared 8 PM rhythm reminder. When this
  /// account still has it, every active rhythm without its own time gets
  /// 8 PM, saved through [save], and the old reminder is cancelled. Paused
  /// rhythms and rhythms that already have a time are left alone. Returns the
  /// rhythms to use from here on. Run it before the first reminder sync.
  Future<List<HabitEntity>> migrateLegacyHabitReminder(
    List<HabitEntity> habits, {
    required Future<void> Function(List<HabitEntity> habits) save,
    bool Function()? shouldContinue,
  }) => KeyedMutationCoordinator.shared.runExclusive<List<HabitEntity>>(
    AccountDataRegistry.notificationMutationKeyForScope(
      _accountScope ?? 'legacy',
    ),
    () async {
      if (shouldContinue?.call() == false) return habits;
      if (_preferences.load(_legacyHabitMigrationDoneKey) == 'true') {
        return habits;
      }
      if (!_isEnabled(_habitReminderEnabledKey, defaultValue: true)) {
        return habits;
      }
      // Without a verified account the OS reminders cannot be read yet.
      if (_accountScope == null) return habits;
      final bool hadLegacy =
          _trackedHabitReminderIds().contains(_legacyHabitReminderId) ||
          await _legacyReminderIsPending();
      if (shouldContinue?.call() == false) return habits;
      if (!hadLegacy) {
        await _preferences.save(_legacyHabitMigrationDoneKey, 'true');
        return habits;
      }
      bool changed = false;
      final List<HabitEntity> migrated = <HabitEntity>[
        for (final HabitEntity habit in habits)
          if (habit.active && habit.reminderMinutes == null)
            () {
              changed = true;
              return habit.copyWith(reminderMinutes: _legacyReminderMinutes);
            }()
          else
            habit,
      ];
      if (changed) await save(migrated);
      if (shouldContinue?.call() == false) return migrated;
      // Marked done only once the old reminder is really gone.
      if (!await _scheduler.cancel(
        _legacyHabitReminderId,
        accountScope: _accountScope,
      )) {
        return migrated;
      }
      await _preferences.save(_legacyHabitMigrationDoneKey, 'true');
      return migrated;
    },
  );

  /// A failed read throws, so the migration is retried instead of skipped.
  Future<bool> _legacyReminderIsPending() async =>
      (await _scheduler.pendingIdsForAccount(
        _accountScope!,
      )).contains(_legacyHabitReminderId);

  /// True until the one-time migration has run while rhythm reminders are on.
  /// The old shared reminder is then this account's only sign that its
  /// rhythms had a reminder, and it still fires at 8 PM, so every other path
  /// leaves it registered and keeps its tracked id. Only the migration (or
  /// the user turning rhythm reminders, or every reminder, off) cancels it.
  bool _keepsLegacyHabitReminder() =>
      _preferences.load(_legacyHabitMigrationDoneKey) != 'true' &&
      _isEnabled(_habitReminderEnabledKey, defaultValue: true) &&
      _remindersOn();

  /// Rhythm reminder ids a sync or reconcile may cancel.
  Set<String> _habitReminderIdsToCancel(bool keepLegacy) => <String>{
    if (!keepLegacy) _legacyHabitReminderId,
    ..._trackedHabitReminderIds().where(
      (String id) => !keepLegacy || id != _legacyHabitReminderId,
    ),
  };

  /// Whether the old shared id must stay in the tracked ids after this run.
  /// Kept as is while [keepLegacy]. Otherwise, before the migration has run,
  /// it is recorded when this account still had the old reminder, so turning
  /// rhythm reminders back on lets the migration find it. A failed OS read
  /// records nothing: turning reminders off must still work.
  Future<bool> _legacyIdToKeepTracked(bool keepLegacy) async {
    final bool tracked = _trackedHabitReminderIds().contains(
      _legacyHabitReminderId,
    );
    if (keepLegacy) return tracked;
    if (_preferences.load(_legacyHabitMigrationDoneKey) == 'true') {
      return false;
    }
    if (tracked) return true;
    if (_accountScope == null) return false;
    try {
      return await _legacyReminderIsPending();
    } on Object {
      return false;
    }
  }

  static bool _wantsReminder(HabitEntity habit) =>
      habit.active && habit.reminderMinutes != null;

  String habitReminderId(String habitId) => '$habitReminderPrefix$habitId';

  /// The alarm for one chosen weekday (1 = Monday) of a weekly habit.
  String habitWeekdayReminderId(String habitId, int weekday) =>
      '$habitReminderPrefix${habitId}_wd$weekday';

  /// How registering every wanted rhythm reminder went, or null when the
  /// account changed part way.
  Future<NotificationScheduleResult?> _scheduleHabits(
    List<HabitEntity> habits, {
    bool Function()? shouldContinue,
  }) async {
    final bool keepLegacy = _keepsLegacyHabitReminder();
    final bool trackLegacy = await _legacyIdToKeepTracked(keepLegacy);
    final Set<String> previous = _habitReminderIdsToCancel(keepLegacy);
    final List<HabitEntity> wanted = habits
        .where(_wantsReminder)
        .toList(growable: false);
    final Set<String> wantedIds = <String>{
      for (final HabitEntity habit in wanted) ..._habitReminderIdsFor(habit),
    };
    await _forgetFingerprints(<String>{...previous, ...wantedIds});
    // Replace every earlier registration, including the old shared alarm
    // once the migration has run.
    for (final String id in previous) {
      if (!await _scheduler.cancel(id, accountScope: _accountScope)) {
        throw StateError('Previous rhythm reminder could not be cancelled.');
      }
    }
    // Track before registering so an interrupted run can still be cancelled.
    await _saveTrackedHabitReminderIds(<String>{
      ...wantedIds,
      if (trackLegacy) _legacyHabitReminderId,
    });
    if (wanted.isEmpty) return NotificationScheduleResult.scheduled;
    if (shouldContinue?.call() == false) return null;
    final load = _loadHabitOccurrences;
    if (load == null) {
      throw StateError('Rhythm reminder outcome storage is unavailable.');
    }
    final outcomes = await load();
    if (shouldContinue?.call() == false) return null;
    final DateTime now = _now().toLocal();
    NotificationScheduleResult result = NotificationScheduleResult.scheduled;
    final List<_PlannedReminder> registered = <_PlannedReminder>[];
    for (final HabitEntity habit in wanted) {
      if (shouldContinue?.call() == false) {
        for (final _PlannedReminder item in registered) {
          await _scheduler.cancel(item.id, accountScope: _accountScope);
        }
        return null;
      }
      for (final _PlannedReminder item in _habitReminders(
        habit,
        outcomes,
        now,
      )) {
        final NotificationScheduleResult scheduled = await _registerPlanned(
          item,
        );
        if (scheduled == NotificationScheduleResult.scheduled) {
          registered.add(item);
        }
        result = _worseResult(result, scheduled);
      }
    }
    await _rememberFingerprints(registered);
    return result;
  }

  /// The more telling of two results: a failure first, then missing
  /// permission (the user can fix it), then an unsupported platform.
  static NotificationScheduleResult _worseResult(
    NotificationScheduleResult a,
    NotificationScheduleResult b,
  ) {
    int rank(NotificationScheduleResult value) => switch (value) {
      NotificationScheduleResult.scheduled => 0,
      NotificationScheduleResult.unsupported => 1,
      NotificationScheduleResult.permissionDenied => 2,
      NotificationScheduleResult.failed => 3,
    };
    return rank(b) > rank(a) ? b : a;
  }

  /// First fire for [habit]: its reminder time in the current period (today,
  /// this week's [weekday] (Monday when not given), or this month's chosen
  /// day, the 1st by default), or the next period's when that time has
  /// passed or the current period is already checked in.
  static DateTime nextHabitReminderAt(
    HabitEntity habit,
    List<HabitOccurrenceEntity> outcomes,
    DateTime now, {
    int? weekday,
  }) => _nextHabitReminderAt(habit, outcomes, now, weekday);

  /// How registering the daily planning reminder went. Also
  /// [NotificationScheduleResult.scheduled] when it is off (nothing is left
  /// to register); null when the account changed part way.
  Future<NotificationScheduleResult?> ensureDailyPlanningReminder({
    bool Function()? shouldContinue,
  }) {
    // Share the notification repository's lock so account cleanup and a new
    // session's schedule cannot overtake an in-flight OS scheduling request.
    return KeyedMutationCoordinator.shared
        .runExclusive<NotificationScheduleResult?>(
          AccountDataRegistry.notificationMutationKeyForScope(
            _accountScope ?? 'legacy',
          ),
          () async {
            if (shouldContinue?.call() == false) return null;
            await _forgetFingerprints(const <String>[dailyPlanningReminderId]);
            if (!_isEnabled(_dailyPlanningEnabledKey, defaultValue: true) ||
                !_remindersOn()) {
              await _notifications.cancel(dailyPlanningReminderId);
              return NotificationScheduleResult.scheduled;
            }

            final (int hour, int minute) = _dailyPlanningTime();
            final _PlannedReminder item = _dailyPlanningReminder(hour, minute);
            final NotificationScheduleResult result = await _registerPlanned(
              item,
            );
            if (shouldContinue?.call() == false) {
              await _scheduler.cancel(
                dailyPlanningReminderId,
                accountScope: _accountScope,
              );
              return null;
            }
            if (result == NotificationScheduleResult.scheduled) {
              await _rememberFingerprints(<_PlannedReminder>[item]);
            }
            return result;
          },
        );
  }

  Future<NotificationScheduleResult> setDailyPlanningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _preferences.save(_dailyPlanningEnabledKey, enabled.toString());
    await _preferences.save(_dailyPlanningTimeKey, '$hour:$minute');
    return await ensureDailyPlanningReminder() ??
        NotificationScheduleResult.failed;
  }

  /// Brings this account's OS reminders in line with its goals, rhythms and
  /// preferences, changing only what differs (see [_ReminderReconciler]).
  /// Runs on resume and after preferences are restored. Keep local
  /// goal/habit content; neither is part of the cloud backup.
  Future<bool> reconcileAfterRestore({
    required List<GoalEntity> goals,
    required List<HabitEntity> habits,
    required bool permissionGranted,
    required bool Function() shouldContinue,
  }) {
    return KeyedMutationCoordinator.shared.runExclusive<bool>(
      AccountDataRegistry.notificationMutationKeyForScope(
        _accountScope ?? 'legacy',
      ),
      () => _reconcile(
        goals: goals,
        habits: habits,
        permissionGranted: permissionGranted,
        shouldContinue: shouldContinue,
      ),
    );
  }

  /// The reminders one goal should have right now. Pure apart from recording
  /// the goal's "almost there" time in [nextNudges], so it fires only once.
  List<GoalReminderSlot> goalReminderSlots(
    GoalEntity goal, {
    required GoalProgressView progress,
    required bool progressKnown,
    required DateTime now,
    required Map<String, DateTime> previousNudges,
    required Map<String, DateTime> nextNudges,
    bool overdueNudges = false,
    Map<String, DateTime> previousDueTimes = const <String, DateTime>{},
    Map<String, DateTime>? nextDueTimes,
  }) {
    final List<GoalReminderSlot> slots = <GoalReminderSlot>[];
    if (goal.isCompleted) return slots;
    final String base = _goalReminderId(goal.id);
    final String title = goal.title;
    final int total = progress.totalCount;
    final int done = progress.completedCount;
    final _ReminderCopy copy = _ReminderCopy(_isSpanish());
    final DateTime today = DateTime(now.year, now.month, now.day);
    // The app picks these times, so quiet hours move them. Whether one is
    // still ahead is judged on the moved time, so a reminder being held
    // back is not dropped while it waits.
    final QuietHours quiet = _quietHours();

    final DateTime? target = goal.targetDate;
    DateTime? dueDay;
    if (target != null) {
      final DateTime day = DateTime(target.year, target.month, target.day);
      dueDay = day;
      DateTime morning(int daysBefore) =>
          DateTime(day.year, day.month, day.day - daysBefore, goalReminderHour);
      for (final (String id, int daysBefore) in <(String, int)>[
        ('${base}_3d', 3),
        (base, 1),
        ('${base}_due', 0),
      ]) {
        final DateTime? at = daysBefore == 0
            ? _dueTodayAt(
                goal.id,
                day,
                now,
                previous: previousDueTimes,
                next: nextDueTimes,
              )
            : morning(daysBefore);
        final DateTime? when = at == null ? null : quiet.moveOut(at);
        if (when == null || !when.isAfter(now)) continue;
        slots.add(
          GoalReminderSlot(
            id: id,
            title: copy.goalDeadlineTitle(daysBefore),
            body: copy.goalDeadlineBody(title, daysBefore, done, total),
            at: when,
          ),
        );
      }
      final DateTime overdueAt = quiet.moveOut(morning(-1));
      if (overdueNudges && overdueAt.isAfter(now)) {
        slots.add(
          GoalReminderSlot(
            id: '${base}_overdue',
            title: copy.goalOverdueTitle,
            body: copy.goalOverdueBody(title, done, total),
            at: overdueAt,
          ),
        );
      }
    }

    final int remaining = total - done;
    final bool close =
        total >= 2 && done >= 1 && (remaining <= 1 || done / total >= 0.75);
    // Deadline reminders already cover goals due today or tomorrow.
    // Compared as calendar dates: a 23-hour daylight-saving day must not make
    // a goal due in two days look like it is due tomorrow.
    final bool deadlineSoon =
        dueDay != null &&
        !dueDay.isAfter(DateTime(today.year, today.month, today.day + 1));
    final DateTime? earlier = previousNudges[goal.id];
    if (!progressKnown) {
      // Progress could not be read: keep any pending nudge as it was.
      if (earlier != null) {
        nextNudges[goal.id] = earlier;
        final DateTime when = quiet.moveOut(earlier);
        if (when.isAfter(now) && !deadlineSoon) {
          slots.add(_closeSlot(copy, base, title, remaining, when));
        }
      }
    } else if (close && !deadlineSoon) {
      final DateTime at =
          earlier ??
          (quiet
                  .moveOut(
                    DateTime(now.year, now.month, now.day, goalReminderHour),
                  )
                  .isAfter(now)
              ? DateTime(now.year, now.month, now.day, goalReminderHour)
              : DateTime(now.year, now.month, now.day + 1, goalReminderHour));
      nextNudges[goal.id] = at;
      // A nudge whose time has passed already fired; it does not repeat.
      final DateTime when = quiet.moveOut(at);
      if (when.isAfter(now)) {
        slots.add(_closeSlot(copy, base, title, remaining, when));
      }
    }
    return slots;
  }

  /// When a goal's "due today" reminder fires: [goalReminderHour] on its
  /// target date, or, when that time had already passed before the reminder
  /// was first planned on the day itself, once at [goalSameDayHour] if that is
  /// still at least [goalSameDayLead] away. The time chosen for the target
  /// date is kept in [next], so later updates neither add an evening reminder
  /// after the morning one nor drop an evening reminder about to fire.
  DateTime? _dueTodayAt(
    String goalId,
    DateTime day,
    DateTime now, {
    required Map<String, DateTime> previous,
    required Map<String, DateTime>? next,
  }) {
    bool onDay(DateTime value) =>
        value.year == day.year &&
        value.month == day.month &&
        value.day == day.day;
    final DateTime? earlier = previous[goalId];
    DateTime? at;
    if (earlier != null && onDay(earlier)) {
      at = earlier;
    } else {
      final DateTime morning = DateTime(
        day.year,
        day.month,
        day.day,
        goalReminderHour,
      );
      final DateTime evening = DateTime(
        day.year,
        day.month,
        day.day,
        goalSameDayHour,
      );
      // Judged on the times after quiet hours move them.
      if (_appTimed(morning).isAfter(now)) {
        at = morning;
      } else if (onDay(now) &&
          !_appTimed(evening).isBefore(now.add(goalSameDayLead))) {
        at = evening;
      }
    }
    if (at != null) next?[goalId] = at;
    return at;
  }

  GoalReminderSlot _closeSlot(
    _ReminderCopy copy,
    String base,
    String title,
    int remaining,
    DateTime at,
  ) => GoalReminderSlot(
    id: '${base}_close',
    title: copy.goalCloseTitle,
    body: copy.goalCloseBody(title, remaining),
    at: at,
  );

  /// The day-before reminder keeps its original id and goes through the
  /// notification list, as before. The extra slots are OS-only so one goal
  /// never fills the in-app list (and its unread badge) with future items;
  /// sign-out finds them through [NotificationSchedulerPort.pendingIdsForAccount].
  bool _isListedGoalSlot(String id) =>
      id.startsWith('goal_reminder_') &&
      !id.endsWith('_3d') &&
      !id.endsWith('_due') &&
      !id.endsWith('_close') &&
      !id.endsWith('_overdue');

  /// True only when the OS confirmed the registration. The listed slot goes
  /// through the notification list, which does not report the outcome.
  Future<bool> _scheduleGoalSlot(GoalReminderSlot slot) async {
    final DateTime at = slot.at;
    if (_isListedGoalSlot(slot.id)) {
      await _notifications.schedule(
        id: slot.id,
        title: slot.title,
        body: slot.body,
        at: at,
      );
      return false;
    }
    final NotificationScheduleResult result = await _scheduler.schedule(
      NotificationEntity(
        id: slot.id,
        title: slot.title,
        message: slot.body,
        scheduledAt: at,
      ),
      accountScope: _accountScope,
    );
    return result == NotificationScheduleResult.scheduled;
  }

  Future<void> _cancelGoalSlot(String id) async {
    if (_isListedGoalSlot(id)) {
      await _notifications.cancel(id);
    } else {
      await _scheduler.cancel(id, accountScope: _accountScope);
    }
  }

  Future<Map<String, GoalProgressView>?> _goalProgress() async {
    final load = _loadGoalTasks;
    if (load == null) return null;
    try {
      final List<TaskEntity> tasks = await load();
      final Map<String, List<TaskEntity>> byGoal = <String, List<TaskEntity>>{};
      for (final TaskEntity task in tasks) {
        final String? goalId = task.goalId;
        if (goalId == null || goalId.isEmpty) continue;
        byGoal.putIfAbsent(goalId, () => <TaskEntity>[]).add(task);
      }
      return <String, GoalProgressView>{
        for (final MapEntry<String, List<TaskEntity>> entry in byGoal.entries)
          entry.key: GoalProgressView.fromTasks(entry.value),
      };
    } on Object {
      return null;
    }
  }

  bool _isEnabled(String key, {required bool defaultValue}) {
    final String? raw = _preferences.load(key);
    if (raw == null) {
      return defaultValue;
    }
    return raw == 'true';
  }

  String _goalReminderId(String goalId) => '$goalReminderPrefix$goalId';

  /// Every reminder id a goal can own. The bare id is the day-before slot, so
  /// it also replaces the single midnight reminder older builds registered.
  Set<String> _goalSlotIds(String goalId) {
    final String base = _goalReminderId(goalId);
    return <String>{
      base,
      '${base}_3d',
      '${base}_due',
      '${base}_close',
      '${base}_overdue',
    };
  }

  Set<String> _trackedHabitReminderIds() {
    final String? encoded = _preferences.load(_scheduledHabitReminderIdsKey);
    if (encoded == null || encoded.isEmpty) return <String>{};
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .where((String id) => id.startsWith('habit_reminder_'))
          .toSet();
    } on FormatException {
      return <String>{};
    }
  }

  Future<void> _saveTrackedHabitReminderIds(Set<String> ids) {
    return _preferences.save(
      _scheduledHabitReminderIdsKey,
      jsonEncode(ids.toList()..sort()),
    );
  }

  Map<String, DateTime> _goalCloseNudges() =>
      _loadGoalTimes(_goalCloseNudgesKey);

  Future<void> _saveGoalCloseNudges(Map<String, DateTime> nudges) =>
      _saveGoalTimes(_goalCloseNudgesKey, nudges);

  Map<String, DateTime> _goalDueTodayTimes() =>
      _loadGoalTimes(_goalDueTodayTimesKey);

  Future<void> _saveGoalDueTodayTimes(Map<String, DateTime> times) =>
      _saveGoalTimes(_goalDueTodayTimesKey, times);

  /// A goal id to time map; unreadable entries are skipped.
  Map<String, DateTime> _loadGoalTimes(String key) {
    final String? encoded = _preferences.load(key);
    if (encoded == null || encoded.isEmpty) return <String, DateTime>{};
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, DateTime>{};
      final Map<String, DateTime> result = <String, DateTime>{};
      decoded.forEach((Object? key, Object? value) {
        final DateTime? at = value is String ? DateTime.tryParse(value) : null;
        if (key is String && key.isNotEmpty && at != null) result[key] = at;
      });
      return result;
    } on FormatException {
      return <String, DateTime>{};
    }
  }

  Future<void> _saveGoalTimes(String key, Map<String, DateTime> times) {
    return _preferences.save(
      key,
      jsonEncode(<String, String>{
        for (final MapEntry<String, DateTime> entry in times.entries)
          entry.key: entry.value.toIso8601String(),
      }),
    );
  }

  Set<String> _trackedGoalReminderIds() {
    final String? encoded = _preferences.load(_scheduledGoalReminderIdsKey);
    if (encoded == null || encoded.isEmpty) {
      return <String>{};
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .where((String id) => id.isNotEmpty)
          .toSet();
    } on FormatException {
      return <String>{};
    }
  }

  Future<void> _saveTrackedGoalReminderIds(Set<String> ids) {
    return _preferences.save(
      _scheduledGoalReminderIdsKey,
      jsonEncode(ids.toList()..sort()),
    );
  }

  Future<void> _cancelTrackedGoalReminders({
    bool Function()? shouldContinue,
  }) async {
    await _forgetFingerprints(<String>{
      for (final String goalId in _trackedGoalReminderIds())
        ..._goalSlotIds(goalId),
    });
    for (final String goalId in _trackedGoalReminderIds()) {
      for (final String id in _goalSlotIds(goalId)) {
        if (shouldContinue?.call() == false) return;
        await _cancelGoalSlot(id);
      }
    }
    if (shouldContinue?.call() == false) return;
    await _saveTrackedGoalReminderIds(<String>{});
    await _saveGoalCloseNudges(<String, DateTime>{});
    await _saveGoalDueTodayTimes(<String, DateTime>{});
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

/// One goal reminder to register with the OS.
class GoalReminderSlot {
  const GoalReminderSlot({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;
}
