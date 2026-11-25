part of 'reminder_orchestrator_service.dart';

/// One task reminder to register with the OS.
class TaskReminderSlot {
  const TaskReminderSlot({
    required this.id,
    required this.taskId,
    required this.title,
    required this.body,
    required this.at,
  });

  final String id;
  final String taskId;
  final String title;
  final String body;

  /// The fire time, in UTC.
  final DateTime at;
}

/// Which reminders open tasks get. Per task: one at its start time, or, with
/// no start time, one when it is due (9 AM local for a deadline without a
/// time of day); plus one "still open" nudge at 9 AM local the day after its
/// deadline when overdue nudges are on. Only future reminders count, and
/// only the [maxPending] nearest are kept (Android limits pending alarms).
abstract final class TaskReminderPlanner {
  static const String idPrefix = 'task_reminder_';
  static const String startPrefix = 'task_reminder_start_';
  static const String duePrefix = 'task_reminder_due_';
  static const String overduePrefix = 'task_reminder_overdue_';

  /// Date-only deadlines and overdue nudges arrive at this local hour.
  static const int reminderHour = 9;
  static const int maxPending = 20;

  static bool ownsId(String id) => id.startsWith(idPrefix);

  static String startId(String taskId) => '$startPrefix$taskId';
  static String dueId(String taskId) => '$duePrefix$taskId';
  static String overdueId(String taskId) => '$overduePrefix$taskId';

  static Set<String> idsFor(String taskId) => <String>{
    startId(taskId),
    dueId(taskId),
    overdueId(taskId),
  };

  /// Whether an open task with these times gets a reminder under [prefs].
  static bool wouldRemind({
    required DateTime? scheduledFor,
    required DateTime? dueDate,
    required ReminderOrchestratorPrefs prefs,
    required DateTime now,
  }) =>
      prefs.remindersEnabled &&
      prefs.taskRemindersEnabled &&
      plan(
        <TaskEntity>[
          TaskEntity(
            id: 'saved',
            title: '',
            createdAt: now,
            scheduledFor: scheduledFor,
            dueDate: dueDate,
          ),
        ],
        now: now,
        leadTime: Duration(minutes: prefs.taskReminderLeadMinutes),
        overdueNudges: prefs.taskOverdueNudgesEnabled,
        quietHours: prefs.quietHours,
      ).isNotEmpty;

  static bool isOpen(TaskEntity task) =>
      task.id.isNotEmpty &&
      !task.isCompleted &&
      !task.isSkipped &&
      !task.isCanceled;

  /// The reminders [tasks] should have right now, nearest first. Local times
  /// use the device time zone (`tz.local`). With a lead time, a task saved
  /// too late for it is reminded at its time itself. Every time is moved out
  /// of [quietHours] before it is judged, so a reminder held back until quiet
  /// hours end stays planned (and counts toward [limit]) while it waits.
  static List<TaskReminderSlot> plan(
    Iterable<TaskEntity> tasks, {
    required DateTime now,
    Duration leadTime = Duration.zero,
    bool overdueNudges = false,
    bool spanish = false,
    int limit = maxPending,
    QuietHours quietHours = const QuietHours(),
  }) {
    final Duration lead = leadTime.isNegative ? Duration.zero : leadTime;
    final List<TaskReminderSlot> slots = <TaskReminderSlot>[
      for (final TaskEntity task in tasks)
        if (isOpen(task))
          ..._forTask(
                task,
                now: now,
                lead: lead,
                overdue: overdueNudges,
                quiet: quietHours,
              )
              .map((slot) => slot.written(_TaskReminderCopy(spanish, task)))
              .where((TaskReminderSlot slot) => slot.at.isAfter(now)),
    ];
    slots.sort((TaskReminderSlot a, TaskReminderSlot b) {
      final int byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return slots.length <= limit ? slots : slots.sublist(0, limit);
  }

  static List<_TaskSlotTime> _forTask(
    TaskEntity task, {
    required DateTime now,
    required Duration lead,
    required bool overdue,
    required QuietHours quiet,
  }) {
    final DateTime? start = task.scheduledFor;
    final DateTime? due = task.dueDate;
    // The lead-time reminder, or, when that moment had already passed when
    // the task was last saved but the time itself is still ahead, a
    // reminder at the time itself. A task saved before its lead moment
    // already had its lead-time reminder, so none follows at the time.
    final DateTime savedAt = task.updatedAt ?? task.createdAt;
    _TaskSlotTime? ahead(String id, _TaskReminderKind kind, DateTime at) {
      final DateTime early = at.subtract(lead);
      final DateTime heldEarly = quiet.moveOut(early);
      if (heldEarly.isAfter(now)) {
        return _TaskSlotTime(id, kind, heldEarly, lead.inMinutes);
      }
      if (early.isAfter(savedAt)) return null;
      return _TaskSlotTime(id, kind, quiet.moveOut(at), 0);
    }

    final _TaskSlotTime? first = start != null
        ? ahead(startId(task.id), _TaskReminderKind.start, start)
        : due == null
        ? null
        : task.hasDateOnlyDeadline
        ? ahead(
            dueId(task.id),
            _TaskReminderKind.dueToday,
            _morning(due, dateOnly: true, daysAfter: 0),
          )
        : ahead(dueId(task.id), _TaskReminderKind.due, due);
    return <_TaskSlotTime>[
      ?first,
      if (overdue && due != null)
        _TaskSlotTime(
          overdueId(task.id),
          _TaskReminderKind.overdue,
          quiet.moveOut(
            _morning(due, dateOnly: task.hasDateOnlyDeadline, daysAfter: 1),
          ),
          0,
        ),
    ];
  }

  /// [reminderHour] on the deadline's local day plus [daysAfter]. A
  /// date-only deadline keeps the written date (as [TaskEntity.effectiveDueAt]
  /// does), so a value decoded as UTC midnight never shifts a day.
  static DateTime _morning(
    DateTime due, {
    required bool dateOnly,
    required int daysAfter,
  }) {
    final DateTime day = dateOnly ? due : tz.TZDateTime.from(due, tz.local);
    return tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day + daysAfter,
      reminderHour,
    );
  }
}

enum _TaskReminderKind { start, due, dueToday, overdue }

class _TaskSlotTime {
  const _TaskSlotTime(this.id, this.kind, this.at, this.leadMinutes);

  final String id;
  final _TaskReminderKind kind;
  final DateTime at;
  final int leadMinutes;

  TaskReminderSlot written(_TaskReminderCopy copy) => TaskReminderSlot(
    id: id,
    taskId: copy.task.id,
    title: copy.title(kind, leadMinutes),
    body: copy.body(kind, leadMinutes),
    at: DateTime.fromMillisecondsSinceEpoch(
      at.millisecondsSinceEpoch,
      isUtc: true,
    ),
  );
}

/// Task reminder text in the app language.
class _TaskReminderCopy {
  const _TaskReminderCopy(this.spanish, this.task);

  final bool spanish;
  final TaskEntity task;

  String get _name {
    final String title = task.title.trim();
    return spanish ? '«$title»' : '"$title"';
  }

  String _minutes(int count) => spanish
      ? (count == 1 ? '1 minuto' : '$count minutos')
      : (count == 1 ? '1 minute' : '$count minutes');

  String title(_TaskReminderKind kind, int lead) => switch (kind) {
    _TaskReminderKind.start when lead == 0 =>
      spanish ? 'Hora de empezar' : 'Time to start',
    _TaskReminderKind.start => spanish ? 'Empieza pronto' : 'Starting soon',
    _TaskReminderKind.due when lead == 0 =>
      spanish ? 'Tarea para ahora' : 'Task due now',
    _TaskReminderKind.due => spanish ? 'Tarea por vencer' : 'Task due soon',
    _TaskReminderKind.dueToday => spanish ? 'Tarea para hoy' : 'Task due today',
    _TaskReminderKind.overdue => spanish ? 'Tarea vencida' : 'Task overdue',
  };

  String body(_TaskReminderKind kind, int lead) => switch (kind) {
    _TaskReminderKind.start when lead == 0 =>
      spanish ? '$_name empieza ahora.' : '$_name starts now.',
    _TaskReminderKind.start =>
      spanish
          ? '$_name empieza en ${_minutes(lead)}.'
          : '$_name starts in ${_minutes(lead)}.',
    _TaskReminderKind.due when lead == 0 =>
      spanish ? '$_name vence ahora.' : '$_name is due now.',
    _TaskReminderKind.due =>
      spanish
          ? '$_name vence en ${_minutes(lead)}.'
          : '$_name is due in ${_minutes(lead)}.',
    _TaskReminderKind.dueToday =>
      spanish ? '$_name vence hoy.' : '$_name is due today.',
    _TaskReminderKind.overdue =>
      spanish
          ? '$_name venció ayer y sigue pendiente.'
          : '$_name was due yesterday and is still open.',
  };
}

extension _TaskReminders on ReminderOrchestratorService {
  Future<_ReminderGroup> _planTaskGroup(
    Future<List<TaskEntity>> Function() load,
  ) async {
    final ReminderOrchestratorPrefs prefs = loadPrefs();
    final Set<String> previous = _trackedTaskReminderIds();
    final DateTime now = _now();
    final List<TaskEntity> tasks = await load();
    final Set<String> openIds = <String>{
      for (final TaskEntity task in tasks)
        if (TaskReminderPlanner.isOpen(task))
          ...TaskReminderPlanner.idsFor(task.id),
    };
    final bool tasksOn = prefs.remindersEnabled && prefs.taskRemindersEnabled;
    final List<_PlannedReminder> wanted = <_PlannedReminder>[
      if (tasksOn)
        for (final TaskReminderSlot slot in TaskReminderPlanner.plan(
          tasks,
          now: now,
          leadTime: Duration(minutes: prefs.taskReminderLeadMinutes),
          overdueNudges: prefs.taskOverdueNudgesEnabled,
          spanish: _isSpanish(),
          quietHours: prefs.quietHours,
        ))
          _PlannedReminder.once(
            id: slot.id,
            title: slot.title,
            body: slot.body,
            // Already moved out of quiet hours by the planner.
            at: slot.at,
          ),
    ];
    final Set<String> wantedIds = <String>{
      for (final _PlannedReminder item in wanted) item.id,
    };
    return _ReminderGroup(
      owns: TaskReminderPlanner.ownsId,
      wanted: wanted,
      tracked: previous,
      couldOwn: <String>{
        ...previous,
        ..._loadFingerprints().keys.where(TaskReminderPlanner.ownsId),
      },
      // A reminder whose time has just passed may still be waiting for the
      // OS to deliver it; it goes away on its own once it has fired. A
      // finished or removed task loses it at once.
      keep: (String id, _StoredFingerprint? stored) {
        final DateTime? at = stored?.onceAt;
        return tasksOn &&
            at != null &&
            !at.isAfter(now) &&
            openIds.contains(id);
      },
      commit: (NotificationScheduleResult outcome) =>
          _saveTrackedTaskReminderIds(
            outcome == NotificationScheduleResult.scheduled
                ? wantedIds
                : <String>{...previous, ...wantedIds},
          ),
    );
  }

  /// Cancels every task reminder this account may have registered.
  Future<void> _cancelTaskReminders() async {
    final Set<String> ids = <String>{
      ..._trackedTaskReminderIds(),
      ..._loadFingerprints().keys.where(TaskReminderPlanner.ownsId),
      ...(await _readPendingIds() ?? const <String>{}).where(
        TaskReminderPlanner.ownsId,
      ),
    };
    await _forgetFingerprints(ids);
    for (final String id in ids) {
      await _scheduler.cancel(id, accountScope: _accountScope);
    }
    await _saveTrackedTaskReminderIds(<String>{});
  }

  int _taskReminderLeadMinutes() {
    final String? raw = _preferences.load(
      ReminderOrchestratorService._taskReminderLeadKey,
    );
    final int minutes = int.tryParse(raw?.trim() ?? '') ?? 0;
    return minutes.clamp(0, 24 * 60).toInt();
  }

  Set<String> _trackedTaskReminderIds() {
    final String? encoded = _preferences.load(
      ReminderOrchestratorService._scheduledTaskReminderIdsKey,
    );
    if (encoded == null || encoded.isEmpty) return <String>{};
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .where(TaskReminderPlanner.ownsId)
          .toSet();
    } on FormatException {
      return <String>{};
    }
  }

  Future<void> _saveTrackedTaskReminderIds(Set<String> ids) {
    return _preferences.save(
      ReminderOrchestratorService._scheduledTaskReminderIdsKey,
      jsonEncode(ids.toList()..sort()),
    );
  }
}
