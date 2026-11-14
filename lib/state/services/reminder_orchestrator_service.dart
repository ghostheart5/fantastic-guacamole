import 'dart:convert';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';

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
    required this._accountScope,
    this._loadHabitOccurrences,
    this._loadGoalTasks,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String _goalReminderEnabledKey = 'goal_reminders_enabled';
  static const String _habitReminderEnabledKey = 'habit_reminders_enabled';
  static const String _dailyPlanningEnabledKey =
      'daily_planning_reminder_enabled';
  static const String _dailyPlanningTimeKey = 'daily_planning_reminder_time';
  static const String _scheduledGoalReminderIdsKey =
      'scheduled_goal_reminder_ids';

  static const String _scheduledHabitReminderIdsKey =
      'scheduled_habit_reminder_ids';
  static const String _goalCloseNudgesKey = 'goal_close_nudges';

  /// Deadline and "almost there" goal reminders arrive at this local hour,
  /// never at midnight (target dates carry no time of day).
  static const int goalReminderHour = 9;

  /// Older builds registered one shared 8 PM rhythm reminder under this id.
  /// It is always cancelled now that each rhythm owns its own reminder.
  static const String _legacyHabitReminderId = 'habit_reminder_daily';
  static const String _dailyPlanningReminderId = 'daily_planning_reminder';

  final SharedPrefsStore _preferences;
  final NotificationsService _notifications;
  final NotificationSchedulerPort _scheduler;
  final String? _accountScope;
  final Future<List<HabitOccurrenceEntity>> Function()? _loadHabitOccurrences;
  final Future<List<TaskEntity>> Function()? _loadGoalTasks;
  final DateTime Function() _now;

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
    if (!enabled) {
      await _cancelTrackedGoalReminders();
    }
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    await _preferences.save(_habitReminderEnabledKey, enabled.toString());
    if (!enabled) {
      for (final String id in <String>{
        _legacyHabitReminderId,
        ..._trackedHabitReminderIds(),
      }) {
        await _notifications.cancel(id);
      }
      await _saveTrackedHabitReminderIds(<String>{});
    }
  }

  /// Registers each active goal's reminders: three days before, the day
  /// before and the morning of its target date (all at [goalReminderHour]),
  /// plus one "almost there" nudge once most of its linked steps are done.
  Future<void> syncGoalReminders(
    List<GoalEntity> goals, {
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return;
    if (!_isEnabled(_goalReminderEnabledKey, defaultValue: true)) {
      await _cancelTrackedGoalReminders(shouldContinue: shouldContinue);
      return;
    }

    final Map<String, GoalProgressView>? progress = await _goalProgress();
    if (shouldContinue?.call() == false) return;
    final DateTime now = _now();
    final Set<String> previousIds = _trackedGoalReminderIds();
    final Map<String, DateTime> previousNudges = _goalCloseNudges();
    final Map<String, DateTime> nextNudges = <String, DateTime>{};
    final Set<String> scheduledIds = <String>{};
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
      );
      for (final GoalReminderSlot slot in slots) {
        if (shouldContinue?.call() == false) return;
        await _scheduleGoalSlot(slot);
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
          !habits.any(_wantsReminder)) {
        // The notification repository carries this account's cancellation
        // scope even when scheduling initialization was skipped.
        for (final String id in <String>{
          _legacyHabitReminderId,
          ..._trackedHabitReminderIds(),
        }) {
          await _notifications.cancel(id);
        }
        await _saveTrackedHabitReminderIds(<String>{});
        return;
      }
      final bool scheduled = await _scheduleHabits(
        habits,
        shouldContinue: shouldContinue,
      );
      if (shouldContinue?.call() == false) return;
      if (!scheduled) throw StateError('Rhythm reminder could not update.');
    },
  );

  static bool _wantsReminder(HabitEntity habit) =>
      habit.active && habit.reminderMinutes != null;

  String habitReminderId(String habitId) => 'habit_reminder_$habitId';

  Future<bool> _scheduleHabits(
    List<HabitEntity> habits, {
    bool Function()? shouldContinue,
  }) async {
    // Replace every earlier registration, including the old shared alarm.
    for (final String id in <String>{
      _legacyHabitReminderId,
      ..._trackedHabitReminderIds(),
    }) {
      if (!await _scheduler.cancel(id, accountScope: _accountScope)) {
        throw StateError('Previous rhythm reminder could not be cancelled.');
      }
    }
    final List<HabitEntity> wanted = habits
        .where(_wantsReminder)
        .toList(growable: false);
    // Track before registering so an interrupted run can still be cancelled.
    await _saveTrackedHabitReminderIds(
      wanted.map((habit) => habitReminderId(habit.id)).toSet(),
    );
    if (wanted.isEmpty) return true;
    if (shouldContinue?.call() == false) return false;
    final load = _loadHabitOccurrences;
    if (load == null) {
      throw StateError('Rhythm reminder outcome storage is unavailable.');
    }
    final outcomes = await load();
    if (shouldContinue?.call() == false) return false;
    final DateTime now = _now().toLocal();
    bool complete = true;
    final List<String> registered = <String>[];
    for (final HabitEntity habit in wanted) {
      if (shouldContinue?.call() == false) {
        for (final String id in registered) {
          await _scheduler.cancel(id, accountScope: _accountScope);
        }
        return false;
      }
      final String id = habitReminderId(habit.id);
      final bool scheduled = await _scheduler.scheduleCadenceAt(
        id: id,
        title: habit.title,
        body: 'Time for "${habit.title}". Tap to check in.',
        cadence: habit.cadence,
        firstAt: nextHabitReminderAt(habit, outcomes, now),
        accountScope: _accountScope,
      );
      if (scheduled) registered.add(id);
      complete = scheduled && complete;
    }
    return complete;
  }

  /// First fire for [habit]: its reminder time in the current period (today,
  /// this week's Monday, or this month's 1st), or the next period's when that
  /// time has passed or the current period is already checked in.
  static DateTime nextHabitReminderAt(
    HabitEntity habit,
    List<HabitOccurrenceEntity> outcomes,
    DateTime now,
  ) {
    final int hour = habit.reminderHour ?? 20;
    final int minute = habit.reminderMinute ?? 0;
    final String key = RhythmPlanningContext.occurrenceKey(habit, now);
    final bool terminal = outcomes.any(
      (value) => value.habitId == habit.id && value.occurrenceKey == key,
    );
    DateTime boundary = switch (habit.cadence) {
      HabitCadence.daily => DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ),
      HabitCadence.weekly => DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - DateTime.monday),
        hour,
        minute,
      ),
      HabitCadence.monthly => DateTime(now.year, now.month, 1, hour, minute),
    };
    if (terminal || !boundary.isAfter(now)) {
      boundary = switch (habit.cadence) {
        HabitCadence.daily => DateTime(
          boundary.year,
          boundary.month,
          boundary.day + 1,
          hour,
          minute,
        ),
        HabitCadence.weekly => DateTime(
          boundary.year,
          boundary.month,
          boundary.day + 7,
          hour,
          minute,
        ),
        HabitCadence.monthly => DateTime(
          boundary.year,
          boundary.month + 1,
          1,
          hour,
          minute,
        ),
      };
    }
    return boundary;
  }

  Future<void> ensureDailyPlanningReminder({bool Function()? shouldContinue}) {
    // Share the notification repository's lock so account cleanup and a new
    // session's schedule cannot overtake an in-flight OS scheduling request.
    return KeyedMutationCoordinator.shared.runExclusive<void>(
      AccountDataRegistry.notificationMutationKeyForScope(
        _accountScope ?? 'legacy',
      ),
      () async {
        if (shouldContinue?.call() == false) return;
        if (!_isEnabled(_dailyPlanningEnabledKey, defaultValue: true)) {
          await _notifications.cancel(_dailyPlanningReminderId);
          return;
        }

        final (int hour, int minute) = _dailyPlanningTime();
        await _scheduler.scheduleDailyAt(
          id: _dailyPlanningReminderId,
          title: 'Daily Planning Reminder',
          body: 'Open Axiomara and choose one manageable next step.',
          hour: hour,
          minute: minute,
          accountScope: _accountScope,
        );
        if (shouldContinue?.call() == false) {
          await _scheduler.cancel(
            _dailyPlanningReminderId,
            accountScope: _accountScope,
          );
        }
      },
    );
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

  /// Reconcile only this account's OS reminders after preferences are replaced.
  /// Keep local goal/habit content; neither is part of the cloud backup.
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
      () async {
        if (!shouldContinue()) return false;
        final goalIds = {
          ..._trackedGoalReminderIds(),
          ...goals.map((g) => g.id),
        };
        final ids = {
          // Fixed daily alarms must not wait behind large historical goal sets.
          _dailyPlanningReminderId,
          _legacyHabitReminderId,
          ..._trackedHabitReminderIds(),
          ...habits.map((habit) => habitReminderId(habit.id)),
          ...goalIds.expand(_goalSlotIds),
        };
        bool complete = true;
        // Cancel stale times and disabled reminders even without OS permission.
        for (final id in ids) {
          if (!shouldContinue()) return false;
          final cancelled = await _scheduler.cancel(
            id,
            accountScope: _accountScope,
          );
          complete = cancelled && complete;
        }
        if (!shouldContinue()) return false;
        final prefs = loadPrefs();
        final scheduledGoals = <String>{};
        final nextNudges = <String, DateTime>{};
        if (prefs.goalRemindersEnabled) {
          // Without permission nothing is registered, so skip the task read.
          final progress = permissionGranted ? await _goalProgress() : null;
          if (!shouldContinue()) return false;
          final now = _now();
          final previousNudges = _goalCloseNudges();
          for (final goal in goals) {
            if (!shouldContinue()) return false;
            if (goal.isCompleted) continue;
            final slots = goalReminderSlots(
              goal,
              progress: progress?[goal.id] ?? const GoalProgressView.empty(),
              progressKnown: progress != null,
              now: now,
              previousNudges: previousNudges,
              nextNudges: nextNudges,
            );
            if (slots.isEmpty) continue;
            if (!permissionGranted) {
              complete = false;
              continue;
            }
            var goalScheduled = false;
            for (final slot in slots) {
              final scheduled = await _scheduler.schedule(
                NotificationEntity(
                  id: slot.id,
                  title: slot.title,
                  message: slot.body,
                  scheduledAt: slot.at,
                ),
                accountScope: _accountScope,
              );
              complete = scheduled && complete;
              goalScheduled = scheduled || goalScheduled;
              if (!shouldContinue()) {
                for (final id in ids) {
                  await _scheduler.cancel(id, accountScope: _accountScope);
                }
                return false;
              }
            }
            if (goalScheduled) scheduledGoals.add(goal.id);
          }
        }
        Future<void> daily(
          String id,
          String title,
          String body,
          int hour,
          int minute,
        ) async {
          if (!shouldContinue()) return;
          if (!permissionGranted) {
            complete = false;
            return;
          }
          final scheduled = await _scheduler.scheduleDailyAt(
            id: id,
            title: title,
            body: body,
            hour: hour,
            minute: minute,
            accountScope: _accountScope,
          );
          complete = scheduled && complete;
        }

        if (prefs.habitRemindersEnabled && habits.any(_wantsReminder)) {
          if (!permissionGranted || !complete) {
            complete = false;
          } else {
            try {
              final scheduled = await _scheduleHabits(
                habits,
                shouldContinue: shouldContinue,
              );
              complete = scheduled && complete;
            } on Object {
              // Stale alarms were cancelled. Failed outcome reads must never
              // become a daily fallback for a completed cadence period.
              complete = false;
            }
          }
        } else {
          await _saveTrackedHabitReminderIds(<String>{});
        }
        if (prefs.dailyPlanningEnabled) {
          await daily(
            _dailyPlanningReminderId,
            'Daily Planning Reminder',
            'Open Axiomara and choose one manageable next step.',
            prefs.dailyPlanningHour,
            prefs.dailyPlanningMinute,
          );
        }
        if (!shouldContinue()) {
          for (final id in ids) {
            await _scheduler.cancel(id, accountScope: _accountScope);
          }
          return false;
        }
        // Retain cancellation candidates if an OS cancellation failed.
        await _saveTrackedGoalReminderIds(complete ? scheduledGoals : goalIds);
        await _saveGoalCloseNudges(nextNudges);
        return complete;
      },
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
  }) {
    final List<GoalReminderSlot> slots = <GoalReminderSlot>[];
    if (goal.isCompleted) return slots;
    final String base = _goalReminderId(goal.id);
    final String title = goal.title;
    final int total = progress.totalCount;
    final int done = progress.completedCount;
    final String steps = total > 0 ? ' $done of $total steps done.' : '';
    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime? target = goal.targetDate;
    DateTime? dueDay;
    if (target != null) {
      final DateTime day = DateTime(target.year, target.month, target.day);
      dueDay = day;
      DateTime morning(int daysBefore) =>
          DateTime(day.year, day.month, day.day - daysBefore, goalReminderHour);
      for (final (String id, int daysBefore, String heading, String phrase)
          in <(String, int, String, String)>[
            ('${base}_3d', 3, 'Goal coming up', 'is due in 3 days'),
            (base, 1, 'Goal due tomorrow', 'is due tomorrow'),
            ('${base}_due', 0, 'Goal due today', 'is due today'),
          ]) {
        final DateTime at = morning(daysBefore);
        if (!at.isAfter(now)) continue;
        slots.add(
          GoalReminderSlot(
            id: id,
            title: heading,
            body: '"$title" $phrase.$steps',
            at: at,
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
        if (earlier.isAfter(now) && !deadlineSoon) {
          slots.add(_closeSlot(base, title, remaining, earlier));
        }
      }
    } else if (close && !deadlineSoon) {
      final DateTime at =
          earlier ??
          (DateTime(now.year, now.month, now.day, goalReminderHour).isAfter(now)
              ? DateTime(now.year, now.month, now.day, goalReminderHour)
              : DateTime(now.year, now.month, now.day + 1, goalReminderHour));
      nextNudges[goal.id] = at;
      // A nudge whose time has passed already fired; it does not repeat.
      if (at.isAfter(now)) slots.add(_closeSlot(base, title, remaining, at));
    }
    return slots;
  }

  GoalReminderSlot _closeSlot(
    String base,
    String title,
    int remaining,
    DateTime at,
  ) => GoalReminderSlot(
    id: '${base}_close',
    title: 'Almost there',
    body: remaining <= 0
        ? 'Every step for "$title" is done. Mark the goal complete when you are ready.'
        : remaining == 1
        ? 'One step left on "$title".'
        : '$remaining steps left on "$title". You are close.',
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
      !id.endsWith('_close');

  Future<void> _scheduleGoalSlot(GoalReminderSlot slot) async {
    if (_isListedGoalSlot(slot.id)) {
      await _notifications.schedule(
        id: slot.id,
        title: slot.title,
        body: slot.body,
        at: slot.at,
      );
      return;
    }
    await _scheduler.schedule(
      NotificationEntity(
        id: slot.id,
        title: slot.title,
        message: slot.body,
        scheduledAt: slot.at,
      ),
      accountScope: _accountScope,
    );
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

  String _goalReminderId(String goalId) => 'goal_reminder_$goalId';

  /// Every reminder id a goal can own. The bare id is the day-before slot, so
  /// it also replaces the single midnight reminder older builds registered.
  Set<String> _goalSlotIds(String goalId) {
    final String base = _goalReminderId(goalId);
    return <String>{base, '${base}_3d', '${base}_due', '${base}_close'};
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

  Map<String, DateTime> _goalCloseNudges() {
    final String? encoded = _preferences.load(_goalCloseNudgesKey);
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

  Future<void> _saveGoalCloseNudges(Map<String, DateTime> nudges) {
    return _preferences.save(
      _goalCloseNudgesKey,
      jsonEncode(<String, String>{
        for (final MapEntry<String, DateTime> entry in nudges.entries)
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
    for (final String goalId in _trackedGoalReminderIds()) {
      for (final String id in _goalSlotIds(goalId)) {
        if (shouldContinue?.call() == false) return;
        await _cancelGoalSlot(id);
      }
    }
    if (shouldContinue?.call() == false) return;
    await _saveTrackedGoalReminderIds(<String>{});
    await _saveGoalCloseNudges(<String, DateTime>{});
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
