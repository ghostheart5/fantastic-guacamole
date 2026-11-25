part of 'reminder_orchestrator_service.dart';

/// How a planned reminder repeats.
enum _Repeat { once, daily, cadence }

/// One reminder the account should have, with everything that decides what
/// the OS shows and when.
class _PlannedReminder {
  const _PlannedReminder.once({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  }) : repeat = _Repeat.once,
       hour = 0,
       minute = 0,
       cadence = null,
       skippedPeriod = '',
       day = '';

  _PlannedReminder.daily({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
  }) : repeat = _Repeat.daily,
       at = DateTime(0),
       cadence = null,
       skippedPeriod = '',
       day = '';

  _PlannedReminder.cadence({
    required this.id,
    required this.title,
    required this.body,
    required HabitCadence this.cadence,
    required DateTime firstAt,
    required this.skippedPeriod,
    this.day = '',
  }) : repeat = _Repeat.cadence,
       at = firstAt,
       hour = firstAt.hour,
       minute = firstAt.minute;

  final String id;
  final String title;
  final String body;
  final _Repeat repeat;

  /// The fire time of a one-off reminder, or the first fire of a cadence.
  final DateTime at;
  final int hour;
  final int minute;
  final HabitCadence? cadence;

  /// The checked-in period a cadence reminder skips, or empty. The first
  /// fire itself is left out of the fingerprint: it moves to the next period
  /// once the reminder time passes, and that alone must not replace a
  /// registration whose alarm may still be waiting to fire.
  final String skippedPeriod;

  /// The chosen day a cadence reminder repeats on, when it is not implied by
  /// its id, or empty. Left out of the fingerprint when empty.
  final String day;

  /// Changes whenever the time, repeat rule, text or time zone changes.
  String fingerprint(String zone) {
    final String rule = switch (repeat) {
      _Repeat.once => 'once|${at.toIso8601String()}',
      _Repeat.daily => 'daily|$hour:$minute',
      _Repeat.cadence =>
        'cadence|${cadence!.name}|$hour:$minute|$skippedPeriod'
            '${day.isEmpty ? '' : '|$day'}',
    };
    return sha256
        .convert(utf8.encode(jsonEncode(<String>[zone, rule, title, body])))
        .toString()
        .substring(0, 32);
  }
}

/// What the reconciler last registered under one id.
class _StoredFingerprint {
  const _StoredFingerprint(this.hash, {this.onceAt});

  final String hash;

  /// Fire time of a one-off reminder; null for repeating ones.
  final DateTime? onceAt;
}

/// Everything one producer of reminders wants, and the ids it may own.
///
/// To add a producer, write a planner that returns one of these and list it
/// in [ReminderOrchestratorService._reminderGroups].
class _ReminderGroup {
  _ReminderGroup({
    required this.owns,
    required this.wanted,
    required this.couldOwn,
    this.tracked = const <String>{},
    this.keep,
    this.commit,
  });

  /// Which OS reminder ids belong to this group.
  final bool Function(String id) owns;
  final List<_PlannedReminder> wanted;

  /// Ids its own bookkeeping says may be registered.
  final Set<String> tracked;

  /// Every id it may have registered. Cancelled when notifications are not
  /// allowed and used in place of the OS list when that cannot be read.
  final Set<String> couldOwn;

  /// Registered ids that are not wanted but must not be cancelled. [held]
  /// says whether the OS list holds the id: false for a one-off reminder
  /// that was delivered, null when the list could not be read (or
  /// notifications are not allowed).
  final bool Function(
    String id,
    _StoredFingerprint? stored, {
    required bool? held,
  })?
  keep;

  /// Saves the group's own bookkeeping once it has been applied, given how
  /// that went: [NotificationScheduleResult.scheduled] when every wanted
  /// reminder is registered and nothing stale is left;
  /// [NotificationScheduleResult.permissionDenied] or
  /// [NotificationScheduleResult.unsupported] when some could not be
  /// registered for that known reason (not a failure); otherwise
  /// [NotificationScheduleResult.failed].
  final Future<void> Function(NotificationScheduleResult outcome)? commit;
}

/// Shared state of one reconcile run.
class _ReconcileRun {
  _ReconcileRun({
    required this.pending,
    required this.permissionGranted,
    required this.fingerprints,
    required this.zone,
    required this.shouldContinue,
    required this.clearedWhileOff,
  });

  /// This account's registered OS ids, or null when they could not be read.
  final Set<String>? pending;
  final bool permissionGranted;
  final Map<String, _StoredFingerprint> fingerprints;

  /// Ids already cancelled while notifications were not allowed, so later
  /// runs in that state do not cancel them again. Empty once allowed.
  final Set<String> clearedWhileOff;
  final String zone;
  final bool Function() shouldContinue;

  /// Ids this run registered, cancelled again if the run is abandoned.
  final List<String> registered = <String>[];
}

/// Thrown inside a group when the account changed while it was applied.
class _ReconcileAbandoned implements Exception {
  const _ReconcileAbandoned();
}

extension _ReminderReconciler on ReminderOrchestratorService {
  static const String _fingerprintsKey = 'reminder_fingerprints_v1';
  static const String _clearedWhileOffKey = 'reminders_cleared_while_off_v1';

  /// Every producer of reminders, planned and applied one after another.
  /// Fixed daily reminders go first so they never wait behind a long goal
  /// history.
  List<(String, Future<_ReminderGroup> Function())> _reminderGroups({
    required List<GoalEntity> goals,
    required List<HabitEntity> habits,
    required bool permissionGranted,
    required bool keepLegacy,
    required bool trackLegacy,
  }) => <(String, Future<_ReminderGroup> Function())>[
    ('planning', () async => _planDailyPlanningGroup()),
    (
      'habits',
      () => _planHabitGroup(
        habits,
        permissionGranted: permissionGranted,
        keepLegacy: keepLegacy,
        trackLegacy: trackLegacy,
      ),
    ),
    ('goals', () => _planGoalGroup(goals, permissionGranted)),
    if (_loadTasks case final load?)
      (
        'tasks',
        () => _planTaskGroup(load, permissionGranted: permissionGranted),
      ),
  ];

  /// Applies only the difference between what each group wants and what is
  /// registered: missing reminders are added, changed ones replaced, removed
  /// ones cancelled, and matching ones left alone, so a delivered reminder
  /// stays in the tray and a waiting alarm keeps its current period.
  Future<bool> _reconcile({
    required List<GoalEntity> goals,
    required List<HabitEntity> habits,
    required bool permissionGranted,
    required bool Function() shouldContinue,
  }) async {
    if (!shouldContinue()) return false;
    final bool keepLegacy = _keepsLegacyHabitReminder();
    final bool trackLegacy = await _legacyIdToKeepTracked(keepLegacy);
    if (!shouldContinue()) return false;
    if (!_remindersOn()) {
      // One-off nudges outside the reconciler go too. The notification list
      // drops a future entry and keeps one that already went off.
      try {
        await _notifications.cancelWhere(
          (String id) =>
              id.startsWith(ReminderOrchestratorService.streakBreakIdPrefix),
        );
      } on Object {
        return false;
      }
      if (!shouldContinue()) return false;
    }
    return _runGroups(
      _reminderGroups(
        goals: goals,
        habits: habits,
        permissionGranted: permissionGranted,
        keepLegacy: keepLegacy,
        trackLegacy: trackLegacy,
      ),
      permissionGranted: permissionGranted,
      shouldContinue: shouldContinue,
      everyGroup: true,
    );
  }

  /// Plans and applies [groups] one after another. [everyGroup] is false
  /// when only some producers run: the record of what was cleared while
  /// notifications were off then keeps the other groups' ids.
  Future<bool> _runGroups(
    List<(String, Future<_ReminderGroup> Function())> groups, {
    required bool permissionGranted,
    required bool Function() shouldContinue,
    required bool everyGroup,
  }) async {
    final _ReconcileRun run = _ReconcileRun(
      pending: permissionGranted ? await _readPendingIds() : null,
      permissionGranted: permissionGranted,
      fingerprints: _loadFingerprints(),
      zone: _timeZoneName(),
      shouldContinue: shouldContinue,
      // Once notifications are allowed again, everything is registered anew.
      clearedWhileOff: permissionGranted && everyGroup
          ? <String>{}
          : _loadClearedWhileOff(),
    );
    if (!shouldContinue()) return false;
    bool complete = true;
    final List<String> failed = <String>[];
    NotificationScheduleResult? habitOutcome;
    NotificationScheduleResult overall = NotificationScheduleResult.scheduled;
    for (final (String name, Future<_ReminderGroup> Function() plan)
        in groups) {
      if (!shouldContinue()) return _abandon(run);
      NotificationScheduleResult outcome;
      _ReminderGroup? group;
      try {
        group = await plan();
        outcome = await _applyGroup(group, run);
      } on _ReconcileAbandoned {
        return _abandon(run);
      } on Object {
        outcome = NotificationScheduleResult.failed;
      }
      if (!shouldContinue()) return _abandon(run);
      if (permissionGranted && group != null) {
        run.clearedWhileOff.removeWhere(group.owns);
      }
      try {
        await group?.commit?.call(outcome);
      } on Object {
        outcome = NotificationScheduleResult.failed;
      }
      // A reminder this device cannot register at all (for example a
      // repeating rhythm reminder outside Android) is nothing the person can
      // fix, so it does not leave the update incomplete.
      if (outcome != NotificationScheduleResult.scheduled &&
          outcome != NotificationScheduleResult.unsupported) {
        complete = false;
      }
      if (outcome == NotificationScheduleResult.failed) failed.add(name);
      if (name == 'habits') habitOutcome = outcome;
      overall = ReminderOrchestratorService._worseResult(overall, outcome);
    }
    if (!shouldContinue()) return _abandon(run);
    await _saveFingerprints(run.fingerprints);
    await _saveClearedWhileOff(run.clearedWhileOff);
    if (failed.isNotEmpty) _recordIncomplete(failed);
    if (habitOutcome != null) _lastHabitReminderResult.value = habitOutcome;
    if (everyGroup) _lastReminderResult.value = overall;
    return complete;
  }

  Future<NotificationScheduleResult> _applyGroup(
    _ReminderGroup group,
    _ReconcileRun run,
  ) async {
    final Set<String>? pending = run.pending;
    final Map<String, _StoredFingerprint> fingerprints = run.fingerprints;
    final Set<String> wantedIds = <String>{
      for (final _PlannedReminder item in group.wanted) item.id,
    };
    bool kept(String id) =>
        group.keep?.call(id, fingerprints[id], held: pending?.contains(id)) ??
        false;
    bool ok = true;
    NotificationScheduleResult? declined;

    if (!run.permissionGranted) {
      // Nothing can be registered, and the OS list may read as empty. Clear
      // every reminder this group may own so none fires with outdated
      // content once notifications are allowed again. Each id is cleared
      // once: later runs skip it unless something registered it since.
      final Set<String> cleared = run.clearedWhileOff;
      for (final String id in <String>{...group.couldOwn, ...wantedIds}) {
        if (kept(id)) continue;
        if (cleared.contains(id) && !fingerprints.containsKey(id)) continue;
        _checkCurrent(run);
        if (await _scheduler.cancel(id, accountScope: _accountScope)) {
          fingerprints.remove(id);
          cleared.add(id);
        } else {
          ok = false;
        }
      }
      if (!ok) return NotificationScheduleResult.failed;
      return wantedIds.isEmpty
          ? NotificationScheduleResult.scheduled
          : NotificationScheduleResult.permissionDenied;
    }

    final Set<String> registered = <String>{
      if (pending != null) ...pending.where(group.owns) else ...group.couldOwn,
      ...group.tracked,
      ...fingerprints.keys.where(group.owns),
    };
    for (final _PlannedReminder item in group.wanted) {
      _checkCurrent(run);
      final String fingerprint = item.fingerprint(run.zone);
      if (pending != null &&
          pending.contains(item.id) &&
          fingerprints[item.id]?.hash == fingerprint) {
        continue;
      }
      NotificationScheduleResult result;
      try {
        result = await _registerPlanned(item);
      } on Object {
        result = NotificationScheduleResult.failed;
      }
      final bool scheduled = result == NotificationScheduleResult.scheduled;
      if (scheduled) run.registered.add(item.id);
      _checkCurrent(run);
      if (scheduled) {
        fingerprints[item.id] = _StoredFingerprint(
          fingerprint,
          onceAt: item.repeat == _Repeat.once ? item.at : null,
        );
        continue;
      }
      // A fingerprint means this id was registered and not known to be gone.
      final bool wasRegistered = fingerprints.remove(item.id) != null;
      final bool knownReason = result != NotificationScheduleResult.failed;
      if (knownReason) {
        // Missing permission or an unsupported platform is not a failure.
        declined = declined == null
            ? result
            : ReminderOrchestratorService._worseResult(declined, result);
      } else {
        ok = false;
      }
      // Same id, so there is no newer registration to keep: the one left
      // behind carries outdated content. For a known reason only clear what
      // the OS really holds (or, when its list cannot be read, what this
      // account last registered), so every resume does not cancel it again.
      final bool held = pending != null
          ? pending.contains(item.id)
          : wasRegistered;
      if (knownReason ? held : registered.contains(item.id)) {
        try {
          await _scheduler.cancel(item.id, accountScope: _accountScope);
        } on Object {
          // Reported through the incomplete result.
        }
      }
    }
    // Cancel only after the new registrations, so a replacement under a
    // different id never leaves a gap.
    for (final String id in registered.difference(wantedIds)) {
      if (kept(id)) continue;
      _checkCurrent(run);
      if (await _scheduler.cancel(id, accountScope: _accountScope)) {
        fingerprints.remove(id);
      } else {
        ok = false;
      }
    }
    if (pending != null) {
      // Forget what the OS no longer holds (a delivered one-off reminder).
      fingerprints.removeWhere(
        (String id, _) =>
            group.owns(id) &&
            !pending.contains(id) &&
            !run.registered.contains(id),
      );
    }
    if (!ok) return NotificationScheduleResult.failed;
    return declined ?? NotificationScheduleResult.scheduled;
  }

  void _checkCurrent(_ReconcileRun run) {
    if (!run.shouldContinue()) throw const _ReconcileAbandoned();
  }

  /// The account changed: take back what this run registered for it.
  Future<bool> _abandon(_ReconcileRun run) async {
    for (final String id in run.registered) {
      await _scheduler.cancel(id, accountScope: _accountScope);
    }
    return false;
  }

  Future<Set<String>?> _readPendingIds() async {
    final String? scope = _accountScope;
    if (scope == null) return null;
    try {
      return (await _scheduler.pendingIdsForAccount(scope)).toSet();
    } on Object {
      return null;
    }
  }

  Future<NotificationScheduleResult> _registerPlanned(_PlannedReminder item) {
    return switch (item.repeat) {
      _Repeat.once => _scheduler.schedule(
        NotificationEntity(
          id: item.id,
          title: item.title,
          message: item.body,
          scheduledAt: item.at,
        ),
        accountScope: _accountScope,
      ),
      _Repeat.daily => _scheduler.scheduleDailyAt(
        id: item.id,
        title: item.title,
        body: item.body,
        hour: item.hour,
        minute: item.minute,
        accountScope: _accountScope,
      ),
      _Repeat.cadence => _scheduler.scheduleCadenceAt(
        id: item.id,
        title: item.title,
        body: item.body,
        cadence: item.cadence!,
        firstAt: item.at,
        accountScope: _accountScope,
      ),
    };
  }

  void _recordIncomplete(List<String> groups) {
    Logger.errorCode(
      code: AppDiagnosticCode.reminderReconcileIncomplete,
      debugMessage: 'Reminder update left groups incomplete: $groups',
    );
    RuntimeDiagnostics.recordState(
      'reminders.reconcile_incomplete',
      message: 'some reminders could not be updated',
      data: <String, Object?>{'groups': groups.join(',')},
    );
  }

  _ReminderGroup _planDailyPlanningGroup() {
    final ReminderOrchestratorPrefs prefs = loadPrefs();
    return _ReminderGroup(
      owns: (String id) =>
          id == ReminderOrchestratorService.dailyPlanningReminderId,
      wanted: <_PlannedReminder>[
        if (prefs.remindersEnabled && prefs.dailyPlanningEnabled)
          _dailyPlanningReminder(
            prefs.dailyPlanningHour,
            prefs.dailyPlanningMinute,
          ),
      ],
      couldOwn: const <String>{
        ReminderOrchestratorService.dailyPlanningReminderId,
      },
    );
  }

  Future<_ReminderGroup> _planHabitGroup(
    List<HabitEntity> habits, {
    required bool permissionGranted,
    required bool keepLegacy,
    required bool trackLegacy,
  }) async {
    final List<HabitEntity> wanted =
        _isEnabled(
              ReminderOrchestratorService._habitReminderEnabledKey,
              defaultValue: true,
            ) &&
            _remindersOn()
        ? habits
              .where(ReminderOrchestratorService._wantsReminder)
              .toList(growable: false)
        : const <HabitEntity>[];
    List<HabitOccurrenceEntity> outcomes = const <HabitOccurrenceEntity>[];
    // Without permission nothing is registered, so skip the outcome read.
    if (wanted.isNotEmpty && permissionGranted) {
      final load = _loadHabitOccurrences;
      if (load == null) {
        throw StateError('Rhythm reminder outcome storage is unavailable.');
      }
      outcomes = await load();
    }
    final DateTime now = _now().toLocal();
    final Set<String> previous = _trackedHabitReminderIds();
    final String legacy = ReminderOrchestratorService._legacyHabitReminderId;
    return _ReminderGroup(
      owns: (String id) => id.startsWith('habit_reminder_'),
      wanted: <_PlannedReminder>[
        for (final HabitEntity habit in wanted)
          ..._habitReminders(habit, outcomes, now),
      ],
      tracked: previous,
      couldOwn: <String>{
        ..._habitReminderIdsToCancel(keepLegacy),
        for (final HabitEntity habit in habits)
          ..._habitReminderIdsOwnedBy(habit.id),
      },
      // The old shared reminder stays until its one-time migration has run.
      keep: (String id, _, {required bool? held}) => keepLegacy && id == legacy,
      commit: (NotificationScheduleResult outcome) =>
          _saveTrackedHabitReminderIds(<String>{
            if (outcome == NotificationScheduleResult.failed)
              ...previous.where((String id) => id != legacy),
            for (final HabitEntity habit in wanted)
              ..._habitReminderIdsFor(habit),
            if (trackLegacy) legacy,
          }),
    );
  }

  Future<_ReminderGroup> _planGoalGroup(
    List<GoalEntity> goals,
    bool permissionGranted,
  ) async {
    final ReminderOrchestratorPrefs prefs = loadPrefs();
    final Set<String> previous = _trackedGoalReminderIds();
    final Set<String> active = <String>{
      for (final GoalEntity goal in goals)
        if (!goal.isCompleted) goal.id,
    };
    final Map<String, DateTime> nextNudges = <String, DateTime>{};
    final Map<String, DateTime> nextDueTimes = <String, DateTime>{};
    final Set<String> withReminders = <String>{};
    final List<_PlannedReminder> wanted = <_PlannedReminder>[];
    final DateTime now = _now();
    final Map<String, DateTime> previousDueTimes = _goalDueTodayTimes();
    final bool goalsOn = prefs.remindersEnabled && prefs.goalRemindersEnabled;
    if (goalsOn) {
      // Without permission nothing is registered, so skip the task read.
      final progress = permissionGranted ? await _goalProgress() : null;
      final Map<String, DateTime> previousNudges = _goalCloseNudges();
      for (final GoalEntity goal in goals) {
        if (goal.isCompleted) continue;
        final List<GoalReminderSlot> slots = goalReminderSlots(
          goal,
          progress: progress?[goal.id] ?? const GoalProgressView.empty(),
          progressKnown: progress != null,
          now: now,
          previousNudges: previousNudges,
          nextNudges: nextNudges,
          // The morning-after nudge follows the same choice as for tasks.
          overdueNudges: prefs.taskOverdueNudgesEnabled,
          previousDueTimes: previousDueTimes,
          nextDueTimes: nextDueTimes,
        );
        if (slots.isEmpty) continue;
        withReminders.add(goal.id);
        wanted.addAll(slots.map(_goalReminder));
      }
    }
    final Set<String> activeSlotIds = <String>{
      for (final String goalId in active) ..._goalSlotIds(goalId),
    };
    return _ReminderGroup(
      owns: (String id) => id.startsWith('goal_reminder_'),
      wanted: wanted,
      // Removed and completed goals lose every reminder they could own.
      tracked: <String>{
        for (final String goalId in previous.difference(active))
          ..._goalSlotIds(goalId),
      },
      couldOwn: <String>{
        for (final String goalId in <String>{
          ...previous,
          ...goals.map((GoalEntity goal) => goal.id),
        })
          ..._goalSlotIds(goalId),
      },
      // A reminder whose time has just passed may still be waiting for the
      // OS to deliver it; it goes away on its own once it has fired.
      keep: (String id, _StoredFingerprint? stored, {required bool? held}) {
        final DateTime? at = stored?.onceAt;
        return goalsOn &&
            at != null &&
            !at.isAfter(now) &&
            activeSlotIds.contains(id);
      },
      commit: (NotificationScheduleResult outcome) async {
        // Keep cancellation candidates while anything is left to retry.
        await _saveTrackedGoalReminderIds(
          outcome == NotificationScheduleResult.scheduled
              ? withReminders
              : <String>{...previous, ...goals.map((goal) => goal.id)},
        );
        await _saveGoalCloseNudges(nextNudges);
        // A newly chosen time counts only once every wanted reminder is
        // registered; otherwise the next run decides again.
        await _saveGoalDueTodayTimes(
          _confirmedDueTimes(
            nextDueTimes,
            previousDueTimes,
            registered: (String goalId, DateTime at) =>
                outcome == NotificationScheduleResult.scheduled,
          ),
        );
      },
    );
  }

  _PlannedReminder _dailyPlanningReminder(int hour, int minute) {
    final _ReminderCopy copy = _ReminderCopy(_isSpanish());
    return _PlannedReminder.daily(
      id: ReminderOrchestratorService.dailyPlanningReminderId,
      title: copy.dailyPlanningTitle,
      body: copy.dailyPlanningBody,
      hour: hour,
      minute: minute,
    );
  }

  /// Slot times already have quiet hours applied (see [goalReminderSlots]).
  _PlannedReminder _goalReminder(GoalReminderSlot slot) =>
      _PlannedReminder.once(
        id: slot.id,
        title: slot.title,
        body: slot.body,
        at: slot.at,
      );

  Map<String, _StoredFingerprint> _loadFingerprints() {
    final String? encoded = _preferences.load(_fingerprintsKey);
    final Map<String, _StoredFingerprint> result =
        <String, _StoredFingerprint>{};
    if (encoded == null || encoded.isEmpty) return result;
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map) return result;
      decoded.forEach((Object? id, Object? value) {
        if (id is! String || id.isEmpty || value is! Map) return;
        final Object? hash = value['f'];
        final Object? at = value['at'];
        if (hash is! String || hash.isEmpty) return;
        result[id] = _StoredFingerprint(
          hash,
          onceAt: at is String ? DateTime.tryParse(at) : null,
        );
      });
    } on FormatException {
      // Unreadable bookkeeping only means every reminder is registered again.
    }
    return result;
  }

  Future<void> _saveFingerprints(Map<String, _StoredFingerprint> values) {
    return _preferences.save(
      _fingerprintsKey,
      jsonEncode(<String, Object>{
        for (final MapEntry<String, _StoredFingerprint> entry in values.entries)
          entry.key: <String, String>{
            'f': entry.value.hash,
            if (entry.value.onceAt != null)
              'at': entry.value.onceAt!.toIso8601String(),
          },
      }),
    );
  }

  /// Forgets what is known about [ids]; the next reconcile registers them
  /// again unless the OS list and the content both match, and cancels them
  /// again while notifications are not allowed (another path may have
  /// registered them meanwhile).
  Future<void> _forgetFingerprints(Iterable<String> ids) async {
    final Map<String, _StoredFingerprint> values = _loadFingerprints();
    final Set<String> cleared = _loadClearedWhileOff();
    final int before = values.length;
    final int clearedBefore = cleared.length;
    for (final String id in ids) {
      values.remove(id);
      cleared.remove(id);
    }
    if (values.length != before) await _saveFingerprints(values);
    if (cleared.length != clearedBefore) await _saveClearedWhileOff(cleared);
  }

  Set<String> _loadClearedWhileOff() {
    final String? encoded = _preferences.load(_clearedWhileOffKey);
    if (encoded == null || encoded.isEmpty) return <String>{};
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .where((String id) => id.isNotEmpty)
          .toSet();
    } on FormatException {
      // Unreadable: every id is cancelled once more, which is safe.
      return <String>{};
    }
  }

  Future<void> _saveClearedWhileOff(Set<String> ids) async {
    if (ids.isEmpty) {
      if (_preferences.load(_clearedWhileOffKey) != null) {
        await _preferences.delete(_clearedWhileOffKey);
      }
      return;
    }
    await _preferences.save(
      _clearedWhileOffKey,
      jsonEncode(ids.toList()..sort()),
    );
  }

  /// Records [items] as registered by a path outside the reconciler.
  Future<void> _rememberFingerprints(Iterable<_PlannedReminder> items) async {
    if (items.isEmpty) return;
    final Map<String, _StoredFingerprint> values = _loadFingerprints();
    final String zone = _timeZoneName();
    for (final _PlannedReminder item in items) {
      values[item.id] = _StoredFingerprint(
        item.fingerprint(zone),
        onceAt: item.repeat == _Repeat.once ? item.at : null,
      );
    }
    await _saveFingerprints(values);
  }
}
