part of 'reminder_orchestrator_service.dart';

/// First fire of a habit reminder; see
/// [ReminderOrchestratorService.nextHabitReminderAt].
DateTime _nextHabitReminderAt(
  HabitEntity habit,
  List<HabitOccurrenceEntity> outcomes,
  DateTime now,
  int? weekday,
) {
  final int hour = habit.reminderHour ?? 20;
  final int minute = habit.reminderMinute ?? 0;
  final String key = RhythmPlanningContext.occurrenceKey(habit, now);
  final bool terminal = outcomes.any(
    (value) => value.habitId == habit.id && value.occurrenceKey == key,
  );
  switch (habit.cadence) {
    case HabitCadence.daily:
      final DateTime today = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      return terminal || !today.isAfter(now)
          ? DateTime(now.year, now.month, now.day + 1, hour, minute)
          : today;
    case HabitCadence.weekly:
      // The chosen weekday in this (Monday-based) week, else the next one.
      final int day = weekday ?? DateTime.monday;
      final DateTime thisWeek = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - DateTime.monday) + (day - DateTime.monday),
        hour,
        minute,
      );
      return terminal || !thisWeek.isAfter(now)
          ? DateTime(
              thisWeek.year,
              thisWeek.month,
              thisWeek.day + 7,
              hour,
              minute,
            )
          : thisWeek;
    case HabitCadence.monthly:
      // A chosen day that has passed waits for next month even while this
      // month is unrecorded (no extra one-off reminder).
      final int chosen = _monthlyReminderDay(habit);
      DateTime inMonth(int year, int month) => DateTime(
        year,
        month,
        _resolvedMonthDay(chosen, year, month),
        hour,
        minute,
      );
      final DateTime thisMonth = inMonth(now.year, now.month);
      if (!terminal && thisMonth.isAfter(now)) return thisMonth;
      final DateTime next = DateTime(now.year, now.month + 1);
      return inMonth(next.year, next.month);
  }
}

/// The chosen day of the month, or the 1st.
int _monthlyReminderDay(HabitEntity habit) => habit.reminderDayOfMonth ?? 1;

/// [day] in that month, with [HabitEntity.lastDayOfMonth] resolved to the
/// month's real last day.
int _resolvedMonthDay(int day, int year, int month) =>
    day == HabitEntity.lastDayOfMonth ? DateTime(year, month + 1, 0).day : day;

extension _HabitReminderPlanner on ReminderOrchestratorService {
  /// The weekdays that get their own alarm, or null for the single alarm
  /// under [ReminderOrchestratorService.habitReminderId] (daily and monthly
  /// habits, and weekly habits on Monday alone, chosen or by default, so
  /// they keep the alarm registered before days could be chosen).
  List<int>? _alarmWeekdays(HabitEntity habit) {
    if (habit.cadence != HabitCadence.weekly) return null;
    final List<int>? weekdays = habit.reminderWeekdays;
    if (weekdays == null ||
        (weekdays.length == 1 && weekdays.single == DateTime.monday)) {
      return null;
    }
    return weekdays;
  }

  /// The reminder ids [habit] wants registered when it has a time.
  List<String> _habitReminderIdsFor(HabitEntity habit) {
    final List<int>? weekdays = _alarmWeekdays(habit);
    if (weekdays == null) return <String>[habitReminderId(habit.id)];
    return <String>[
      for (final int weekday in weekdays)
        habitWeekdayReminderId(habit.id, weekday),
    ];
  }

  /// Every reminder id a habit can own, whichever days it had.
  Set<String> _habitReminderIdsOwnedBy(String habitId) => <String>{
    habitReminderId(habitId),
    for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      habitWeekdayReminderId(habitId, weekday),
  };

  /// The repeating alarms for one habit: one per chosen weekday for a weekly
  /// habit with chosen days, otherwise one.
  List<_PlannedReminder> _habitReminders(
    HabitEntity habit,
    List<HabitOccurrenceEntity> outcomes,
    DateTime now,
  ) {
    final String period = RhythmPlanningContext.occurrenceKey(habit, now);
    final bool checkedIn = outcomes.any(
      (HabitOccurrenceEntity value) =>
          value.habitId == habit.id && value.occurrenceKey == period,
    );
    _PlannedReminder planned(String id, int? weekday) {
      final DateTime firstAt = _nextHabitReminderAt(
        habit,
        outcomes,
        now,
        weekday,
      );
      return _PlannedReminder.cadence(
        id: id,
        title: habit.title,
        body: 'Time for "${habit.title}". Tap to check in.',
        cadence: habit.cadence,
        firstAt: firstAt,
        skippedPeriod: checkedIn ? period : '',
        day: _fingerprintDay(habit, firstAt),
      );
    }

    final List<int>? weekdays = _alarmWeekdays(habit);
    if (weekdays == null) {
      return <_PlannedReminder>[planned(habitReminderId(habit.id), null)];
    }
    return <_PlannedReminder>[
      for (final int weekday in weekdays)
        planned(habitWeekdayReminderId(habit.id, weekday), weekday),
    ];
  }

  /// The chosen day of a monthly habit, for its fingerprint, so changing it
  /// replaces the alarm. Empty without a chosen day, which keeps the
  /// fingerprints registered before days could be chosen. "Last day" names
  /// the date it resolved to: the OS repeats that date number, so a month of
  /// another length needs the alarm set up again (on the next resume).
  String _fingerprintDay(HabitEntity habit, DateTime firstAt) {
    if (habit.cadence != HabitCadence.monthly) return '';
    final int? day = habit.reminderDayOfMonth;
    // The 1st, chosen or by default, keeps its earlier fingerprint.
    if (day == null || day == 1) return '';
    return day == HabitEntity.lastDayOfMonth ? 'last${firstAt.day}' : '$day';
  }
}
