import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

/// Answers the eight one-tap questions on the device, from the records in an
/// evidence snapshot. It reads only: it adds nothing, changes nothing and sends
/// nothing. Every sentence is backed by a count or a record in the snapshot;
/// when the records are too few it says so instead of guessing.
///
/// The answer is the same typed [SIV2Response] the free Chat card already shows
/// (facts, what is missing, how certain), in English or Spanish.
final class SIOneTapEngine {
  const SIOneTapEngine();

  SIOneTapAnswer answer({
    required SIOneTapQuestion question,
    required SIV2EvidenceSnapshot snapshot,
    required DateTime now,
    required bool isSpanish,
    String? goalId,
  }) {
    final _Run run = _Run(
      question: question,
      snapshot: snapshot,
      now: now.toLocal(),
      isSpanish: isSpanish,
    );
    return switch (question) {
      SIOneTapQuestion.planMyDay => run.planMyDay(),
      SIOneTapQuestion.whatsComingUp => run.whatsComingUp(),
      SIOneTapQuestion.fallingBehind => run.fallingBehind(),
      SIOneTapQuestion.reachGoal => run.reachGoal(goalId),
      SIOneTapQuestion.improveRoutine => run.improveRoutine(),
      SIOneTapQuestion.explainPatterns => run.explainPatterns(),
      SIOneTapQuestion.getBackOnTrack => run.getBackOnTrack(),
      SIOneTapQuestion.reviewWeek => run.reviewWeek(),
    };
  }
}

/// The kinds of saved information a question reads. "Covered" in the answer's
/// certainty counts the kinds that had records.
enum _Signal { tasks, goals, milestones, timeline, habits, recent }

const Map<SIOneTapQuestion, List<_Signal>> _required =
    <SIOneTapQuestion, List<_Signal>>{
      SIOneTapQuestion.planMyDay: <_Signal>[_Signal.tasks, _Signal.habits],
      SIOneTapQuestion.whatsComingUp: <_Signal>[
        _Signal.tasks,
        _Signal.timeline,
        _Signal.goals,
      ],
      SIOneTapQuestion.fallingBehind: <_Signal>[
        _Signal.tasks,
        _Signal.goals,
        _Signal.milestones,
        _Signal.habits,
      ],
      SIOneTapQuestion.reachGoal: <_Signal>[
        _Signal.goals,
        _Signal.tasks,
        _Signal.milestones,
      ],
      SIOneTapQuestion.improveRoutine: <_Signal>[_Signal.habits],
      SIOneTapQuestion.explainPatterns: <_Signal>[
        _Signal.recent,
        _Signal.habits,
      ],
      SIOneTapQuestion.getBackOnTrack: <_Signal>[
        _Signal.tasks,
        _Signal.habits,
        _Signal.goals,
      ],
      SIOneTapQuestion.reviewWeek: <_Signal>[
        _Signal.recent,
        _Signal.tasks,
        _Signal.habits,
      ],
    };

/// Habits younger than this cannot be judged from a 14 day window.
const int _habitWindowDays = 14;

/// Fewer finished or skipped tasks than this show no pattern.
const int _patternMinimum = 5;

final class _Run {
  _Run({
    required this.question,
    required this.snapshot,
    required this.now,
    required this.isSpanish,
  }) : today = DateTime(now.year, now.month, now.day);

  final SIOneTapQuestion question;
  final SIV2EvidenceSnapshot snapshot;
  final DateTime now;
  final bool isSpanish;
  final DateTime today;

  final Map<String, SIV2EvidenceLink> _links = <String, SIV2EvidenceLink>{};
  final List<SIV2Statement> _facts = <SIV2Statement>[];
  final List<SIV2Statement> _calculations = <SIV2Statement>[];
  final List<SIV2Statement> _inferences = <SIV2Statement>[];
  final List<String> _missing = <String>[];

  String t(String en, String es) => isSpanish ? es : en;

  String count(int n, String en1, String enN, String es1, String esN) =>
      '$n ${n == 1 ? t(en1, es1) : t(enN, esN)}';

  // ---------------------------------------------------------------- records

  List<SIV2TaskEvidence> get tasks => snapshot.tasks;

  bool get isEmptyAccount =>
      snapshot.tasks.isEmpty &&
      snapshot.goals.isEmpty &&
      snapshot.habits.isEmpty &&
      snapshot.recentTasks.isEmpty &&
      snapshot.milestones.every((SIV2MilestoneEvidence m) => m.archived);

  bool _has(_Signal signal) => switch (signal) {
    _Signal.tasks => snapshot.tasks.isNotEmpty,
    _Signal.goals => snapshot.goals.isNotEmpty,
    _Signal.milestones => snapshot.milestones.any(
      (SIV2MilestoneEvidence m) => !m.archived,
    ),
    _Signal.timeline => snapshot.timeline.isNotEmpty,
    _Signal.habits => snapshot.habits.isNotEmpty,
    _Signal.recent => snapshot.recentTasks.isNotEmpty,
  };

  bool _unavailable(_Signal signal) => switch (signal) {
    _Signal.tasks ||
    _Signal.recent => snapshot.unavailableSources.contains(SIV2Source.tasks),
    _Signal.goals => snapshot.unavailableSources.contains(SIV2Source.goals),
    _Signal.milestones => snapshot.unavailableSources.contains(
      SIV2Source.milestones,
    ),
    _Signal.timeline => snapshot.unavailableSources.contains(
      SIV2Source.timeline,
    ),
    _Signal.habits => snapshot.habitsUnavailable,
  };

  String _signalName(_Signal signal) => switch (signal) {
    _Signal.tasks || _Signal.recent => t('tasks', 'tareas'),
    _Signal.goals => t('goals', 'metas'),
    _Signal.milestones => t('milestones', 'hitos'),
    _Signal.timeline => t('schedule', 'agenda'),
    _Signal.habits => t('habits', 'hábitos'),
  };

  // ------------------------------------------------------------------ dates

  bool _dateOnly(DateTime v) =>
      v.hour == 0 &&
      v.minute == 0 &&
      v.second == 0 &&
      v.millisecond == 0 &&
      v.microsecond == 0;

  /// The calendar day a date means to the person. A date with no time of day
  /// is the same day everywhere; a moment is read in local time.
  DateTime dayOf(DateTime v) {
    final DateTime d = _dateOnly(v) ? v : v.toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  bool isPast(DateTime due) =>
      _dateOnly(due) ? dayOf(due).isBefore(today) : due.toLocal().isBefore(now);

  bool isOverdue(SIV2TaskEvidence task) =>
      task.dueDate != null && isPast(task.dueDate!);

  /// The earliest day the task asks for: its due day or its planned day.
  DateTime? taskDay(SIV2TaskEvidence task) {
    final List<DateTime> days = <DateTime>[
      if (task.dueDate != null) dayOf(task.dueDate!),
      if (task.scheduledFor != null) dayOf(task.scheduledFor!),
    ]..sort();
    return days.isEmpty ? null : days.first;
  }

  int daysFromToday(DateTime day) => day.difference(today).inDays;

  String dateLabel(DateTime day) {
    const List<String> en = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const List<String> es = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return isSpanish
        ? '${day.day} ${es[day.month - 1]}'
        : '${en[day.month - 1]} ${day.day}';
  }

  String timing(SIV2TaskEvidence task) {
    if (isOverdue(task)) {
      final int days = -daysFromToday(dayOf(task.dueDate!));
      return days <= 0
          ? t('overdue', 'vencida')
          : t(
              'overdue by ${count(days, 'day', 'days', 'día', 'días')}',
              'vencida hace ${count(days, 'día', 'días', 'día', 'días')}',
            );
    }
    final DateTime? day = taskDay(task);
    if (day == null) return t('no date', 'sin fecha');
    final int diff = daysFromToday(day);
    final bool planned =
        task.dueDate == null ||
        (task.scheduledFor != null &&
            dayOf(task.scheduledFor!).isBefore(dayOf(task.dueDate!)));
    if (diff <= 0) {
      return planned
          ? t('planned today', 'para hoy')
          : t('due today', 'vence hoy');
    }
    if (diff == 1) {
      return planned
          ? t('planned tomorrow', 'para mañana')
          : t('due tomorrow', 'vence mañana');
    }
    return planned
        ? t('planned ${dateLabel(day)}', 'para el ${dateLabel(day)}')
        : t('due ${dateLabel(day)}', 'vence el ${dateLabel(day)}');
  }

  int compareTasks(SIV2TaskEvidence a, SIV2TaskEvidence b) {
    final bool aLate = isOverdue(a);
    final bool bLate = isOverdue(b);
    if (aLate != bLate) return aLate ? -1 : 1;
    final int byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    final DateTime? aDay = taskDay(a);
    final DateTime? bDay = taskDay(b);
    if (aDay != null && bDay != null) {
      final int byDay = aDay.compareTo(bDay);
      if (byDay != 0) return byDay;
    } else if (aDay != null || bDay != null) {
      return aDay != null ? -1 : 1;
    }
    return a.id.compareTo(b.id);
  }

  /// Most overdue first, then highest priority.
  int compareByWait(SIV2TaskEvidence a, SIV2TaskEvidence b) {
    final DateTime aDay = dayOf(a.dueDate!);
    final DateTime bDay = dayOf(b.dueDate!);
    final int byDay = aDay.compareTo(bDay);
    if (byDay != 0) return byDay;
    final int byPriority = b.priority.compareTo(a.priority);
    return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
  }

  // ------------------------------------------------------------- statements

  String taskId(SIV2TaskEvidence task) {
    final String id = 'tasks:${task.id}';
    _links.putIfAbsent(
      id,
      () => SIV2EvidenceLink(
        evidenceId: id,
        source: SIV2Source.tasks,
        label: task.title,
        entityId: task.id,
        observedAt: snapshot.observedAt,
        uri: 'chronospark://tasks/${task.id}',
      ),
    );
    return id;
  }

  String goalLink(SIV2GoalEvidence goal) {
    final String id = 'goals:${goal.id}';
    _links.putIfAbsent(
      id,
      () => SIV2EvidenceLink(
        evidenceId: id,
        source: SIV2Source.goals,
        label: goal.title,
        entityId: goal.id,
        observedAt: snapshot.observedAt,
        uri: 'chronospark://goals/${goal.id}',
      ),
    );
    return id;
  }

  String milestoneLink(SIV2MilestoneEvidence item) {
    final String id = 'milestones:${item.id}';
    _links.putIfAbsent(
      id,
      () => SIV2EvidenceLink(
        evidenceId: id,
        source: SIV2Source.milestones,
        label: item.title,
        entityId: item.id,
        observedAt: item.updatedAt,
        uri: 'chronospark://milestones/${item.id}',
      ),
    );
    return id;
  }

  String timelineLink(SIV2TimelineEvidence item) {
    final String id = 'timeline:${item.id}';
    _links.putIfAbsent(
      id,
      () => SIV2EvidenceLink(
        evidenceId: id,
        source: SIV2Source.timeline,
        label: item.title,
        entityId: item.id,
        observedAt: item.timestamp,
        uri: 'chronospark://timeline/${item.id}',
      ),
    );
    return id;
  }

  String habitLink(SIV2HabitEvidence habit) {
    final String id = 'habits:${habit.id}';
    _links.putIfAbsent(
      id,
      () => SIV2EvidenceLink(
        evidenceId: id,
        source: null,
        label: habit.title,
        entityId: habit.id,
        observedAt: snapshot.observedAt,
        uri: 'chronospark://habits/${habit.id}',
      ),
    );
    return id;
  }

  /// A link to a whole group of records, for counts.
  String groupLink(String name, SIV2Source? source, String label) {
    final String id = '$name:collection';
    _links.putIfAbsent(
      id,
      () => SIV2EvidenceLink(
        evidenceId: id,
        source: source,
        label: label,
        entityId: 'collection',
        observedAt: snapshot.observedAt,
        uri: 'chronospark://$name',
      ),
    );
    return id;
  }

  String get tasksGroup =>
      groupLink('tasks', SIV2Source.tasks, t('Open tasks', 'Tareas abiertas'));
  String get goalsGroup =>
      groupLink('goals', SIV2Source.goals, t('Active goals', 'Metas activas'));
  String get habitsGroup => groupLink(
    'habits',
    null,
    t('Habits and check-ins', 'Hábitos y registros'),
  );
  String get recentGroup => groupLink(
    'recent-tasks',
    SIV2Source.tasks,
    t(
      'Tasks finished or skipped in the last 14 days',
      'Tareas terminadas u omitidas en los últimos 14 días',
    ),
  );
  String get milestonesGroup =>
      groupLink('milestones', SIV2Source.milestones, t('Milestones', 'Hitos'));

  void fact(String text, Iterable<String> ids) => _facts.add(
    SIV2Statement(
      kind: SIV2StatementKind.observedFact,
      text: text,
      evidenceIds: ids.toList(growable: false),
    ),
  );

  void calc(String text, Iterable<String> ids) => _calculations.add(
    SIV2Statement(
      kind: SIV2StatementKind.deterministicCalculation,
      text: text,
      evidenceIds: ids.toList(growable: false),
    ),
  );

  void infer(String text) => _inferences.add(
    SIV2Statement(kind: SIV2StatementKind.inference, text: text),
  );

  void missing(String text) {
    if (!_missing.contains(text)) _missing.add(text);
  }

  // --------------------------------------------------------------- response

  SIOneTapAnswer finish({
    required String direct,
    required String recommendation,
    bool offerAdd = false,
    bool offerAi = false,
  }) {
    final List<_Signal> required = _required[question]!;
    for (final _Signal signal in required) {
      if (_unavailable(signal)) {
        missing(
          t(
            'Your ${_signalName(signal)} could not be read just now.',
            'No se pudieron leer tus ${_signalName(signal)} en este momento.',
          ),
        );
      }
    }
    // Every answer names the groups of records it read, even when a group was
    // empty, so what was looked at is always inspectable.
    for (final _Signal signal in required) {
      final (String, SIV2Source?, int) group = switch (signal) {
        _Signal.tasks => ('tasks', SIV2Source.tasks, snapshot.tasks.length),
        _Signal.goals => ('goals', SIV2Source.goals, snapshot.goals.length),
        _Signal.milestones => (
          'milestones',
          SIV2Source.milestones,
          snapshot.milestones.where((m) => !m.archived).length,
        ),
        _Signal.timeline => (
          'timeline',
          SIV2Source.timeline,
          snapshot.timeline.length,
        ),
        _Signal.habits => ('habits', null, snapshot.habits.length),
        _Signal.recent => (
          'recent-tasks',
          SIV2Source.tasks,
          snapshot.recentTasks.length,
        ),
      };
      groupLink(
        group.$1,
        group.$2,
        signal == _Signal.recent
            ? t(
                'Finished or skipped tasks read (${group.$3})',
                'Tareas terminadas u omitidas leídas (${group.$3})',
              )
            : t(
                'Saved ${_signalName(signal)} read (${group.$3})',
                '${_signalName(signal)[0].toUpperCase()}${_signalName(signal).substring(1)} leídos (${group.$3})',
              ),
      );
    }
    final int covered = required.where(_has).length;
    final int totalRecords =
        snapshot.tasks.length +
        snapshot.goals.length +
        snapshot.habits.length +
        snapshot.recentTasks.length;
    final SIV2EvidenceStrength strength =
        covered == 0 || covered * 2 < required.length
        ? SIV2EvidenceStrength.limited
        : covered == required.length && totalRecords >= 8
        ? SIV2EvidenceStrength.strong
        : SIV2EvidenceStrength.moderate;
    final Set<SIV2Source> sources = <SIV2Source>{
      for (final _Signal signal in required)
        ...switch (signal) {
          _Signal.tasks || _Signal.recent => <SIV2Source>[SIV2Source.tasks],
          _Signal.goals => <SIV2Source>[SIV2Source.goals],
          _Signal.milestones => <SIV2Source>[SIV2Source.milestones],
          _Signal.timeline => <SIV2Source>[SIV2Source.timeline],
          _Signal.habits => const <SIV2Source>[],
        },
    };
    final SIV2Query query = SIV2Query(
      rawText: question.label(isSpanish: isSpanish),
      intent: SIV2Intent.answer,
      sources: sources,
      timeRange: SIV2TimeRange.thirtyDays,
    );
    final SIV2Response response = SIV2Response(
      query: query,
      snapshotRevision: snapshot.revision,
      directAnswer: direct,
      observedFacts: _facts,
      calculations: _calculations,
      inferences: _inferences,
      missingInformation: _missing,
      conflicts: const <SIV2Conflict>[],
      scenarios: const <SIV2Scenario>[],
      scenarioAssumptions: const <String>[],
      recommendation: recommendation,
      confidence: SIV2ConfidenceAnatomy(
        strength: strength,
        coveredSignals: covered,
        requiredSignals: required.length,
        freshness: required.any(_unavailable)
            ? SIV2Freshness.aging
            : SIV2Freshness.current,
        conflictCount: 0,
        assumptionCount: 0,
      ),
      evidenceLinks: _links.values.toList(growable: false),
    );
    return SIOneTapAnswer(
      question: question,
      response: response,
      offerAddSomething: offerAdd,
      offerAi: offerAi && !isEmptyAccount,
    );
  }

  /// A new account (or one with nothing saved) still gets a plain, useful
  /// answer: what the question reads, that nothing is saved, and what to do.
  SIOneTapAnswer empty(String en, String es) {
    missing(
      t(
        'Nothing is saved yet, so there is nothing to read for this question.',
        'Todavía no hay nada guardado, así que no hay nada que leer para esta pregunta.',
      ),
    );
    return finish(
      direct: t(
        'You have no tasks, goals or habits saved yet, so there is nothing to $en.',
        'Todavía no tienes tareas, metas ni hábitos guardados, así que no hay nada que $es.',
      ),
      recommendation: t(
        'Save one small task, goal or habit in Add something, then ask again. Nothing was changed.',
        'Guarda una tarea, meta o hábito pequeño en Añadir algo y vuelve a preguntar. No se cambió nada.',
      ),
      offerAdd: true,
    );
  }

  // ------------------------------------------------------------- Plan my day

  SIOneTapAnswer planMyDay() {
    if (isEmptyAccount) return empty('plan today', 'planear hoy');
    final List<SIV2TaskEvidence> overdue = tasks.where(isOverdue).toList()
      ..sort(compareTasks);
    final List<SIV2TaskEvidence> dueToday = tasks.where((
      SIV2TaskEvidence task,
    ) {
      if (isOverdue(task)) return false;
      final DateTime? day = taskDay(task);
      return day != null && !day.isAfter(today);
    }).toList()..sort(compareTasks);
    final List<SIV2TaskEvidence> undated =
        tasks.where((SIV2TaskEvidence task) => taskDay(task) == null).toList()
          ..sort(compareTasks);
    final List<SIV2HabitEvidence> habitsToCheck = snapshot.habits
        .where(
          (SIV2HabitEvidence h) =>
              h.cadence == HabitCadence.daily && !h.checkedInThisPeriod,
        )
        .toList(growable: false);
    final List<SIV2TaskEvidence> ordered = <SIV2TaskEvidence>[
      ...overdue,
      ...dueToday,
    ];

    fact(
      t(
        '${overdue.length} open ${overdue.length == 1 ? 'task is' : 'tasks are'} overdue and ${dueToday.length} ${dueToday.length == 1 ? 'is' : 'are'} due or planned for today.',
        '${overdue.length} ${overdue.length == 1 ? 'tarea abierta está vencida' : 'tareas abiertas están vencidas'} y ${dueToday.length} ${dueToday.length == 1 ? 'es' : 'son'} para hoy.',
      ),
      <String>[tasksGroup],
    );
    for (final SIV2TaskEvidence task in ordered.take(5)) {
      fact(
        '"${task.title}" · ${timing(task)} · ${t('priority', 'prioridad')} ${task.priority}/5',
        <String>[taskId(task)],
      );
    }
    if (habitsToCheck.isNotEmpty) {
      fact(
        t(
          '${count(habitsToCheck.length, 'daily habit has', 'daily habits have', 'hábito diario no tiene', 'hábitos diarios no tienen')} no check-in yet today.',
          '${count(habitsToCheck.length, 'hábito diario no tiene', 'hábitos diarios no tienen', 'hábito diario no tiene', 'hábitos diarios no tienen')} registro hoy todavía.',
        ),
        <String>[habitsGroup],
      );
    }
    infer(
      t(
        'The order is overdue first, then higher priority, then the earlier day.',
        'El orden es: primero lo vencido, luego la mayor prioridad y luego el día más cercano.',
      ),
    );
    missing(
      t(
        'How much time you have today is not recorded, so this is an order, not a schedule.',
        'No se registra cuánto tiempo tienes hoy, así que esto es un orden, no un horario.',
      ),
    );
    if (undated.isNotEmpty) {
      missing(
        t(
          '${count(undated.length, 'open task has', 'open tasks have', 'tarea abierta no tiene', 'tareas abiertas no tienen')} no date, so ${undated.length == 1 ? 'it is' : 'they are'} not placed in today\'s order.',
          '${count(undated.length, 'tarea abierta no tiene', 'tareas abiertas no tienen', 'tarea abierta no tiene', 'tareas abiertas no tienen')} fecha, así que no ${undated.length == 1 ? 'entra' : 'entran'} en el orden de hoy.',
        ),
      );
    }

    if (ordered.isEmpty) {
      final String start = undated.isNotEmpty
          ? t(
              'Nothing is overdue or due today. You have ${count(undated.length, 'open task', 'open tasks', 'tarea abierta', 'tareas abiertas')} with no date.',
              'No hay nada vencido ni para hoy. Tienes ${count(undated.length, 'tarea abierta', 'tareas abiertas', 'tarea abierta', 'tareas abiertas')} sin fecha.',
            )
          : t(
              'No task is overdue or due today.',
              'Ninguna tarea está vencida ni es para hoy.',
            );
      return finish(
        direct: start,
        recommendation: undated.isNotEmpty
            ? t(
                'If you want to move something forward, "${undated.first.title}" is your highest-priority task without a date.',
                'Si quieres avanzar en algo, "${undated.first.title}" es tu tarea de mayor prioridad sin fecha.',
              )
            : habitsToCheck.isNotEmpty
            ? t(
                'Check in with your daily habits, or save a task in Add something if something needs a place.',
                'Registra tus hábitos diarios, o guarda una tarea en Añadir algo si algo necesita un lugar.',
              )
            : t(
                'Your day is open. Save a task in Add something if something needs a place.',
                'Tu día está libre. Guarda una tarea en Añadir algo si algo necesita un lugar.',
              ),
        offerAdd: undated.isEmpty,
      );
    }
    final SIV2TaskEvidence first = ordered.first;
    final String then = ordered.length > 1
        ? t(
            ' Then "${ordered[1].title}"${ordered.length > 2 ? ', then "${ordered[2].title}"' : ''}.',
            ' Después "${ordered[1].title}"${ordered.length > 2 ? ', luego "${ordered[2].title}"' : ''}.',
          )
        : '';
    return finish(
      direct: t(
        '${count(ordered.length, 'task needs', 'tasks need', 'tarea necesita', 'tareas necesitan')} you today: ${overdue.length} overdue and ${dueToday.length} due or planned for today.',
        '${count(ordered.length, 'tarea necesita', 'tareas necesitan', 'tarea necesita', 'tareas necesitan')} de ti hoy: ${overdue.length} vencida${overdue.length == 1 ? '' : 's'} y ${dueToday.length} para hoy.',
      ),
      recommendation: t(
        'Start with "${first.title}" (${timing(first)}).$then Nothing was changed.',
        'Empieza con "${first.title}" (${timing(first)}).$then No se cambió nada.',
      ),
    );
  }

  // -------------------------------------------------------- What's coming up

  SIOneTapAnswer whatsComingUp() {
    if (isEmptyAccount) {
      return empty('show as coming up', 'mostrar como próximo');
    }
    final DateTime end = today.add(const Duration(days: 8));
    bool inRange(DateTime day) => !day.isBefore(today) && day.isBefore(end);
    final Set<String> taskIds = tasks.map((SIV2TaskEvidence t) => t.id).toSet();
    final List<({DateTime day, String text, String id})> items =
        <({DateTime day, String text, String id})>[];
    for (final SIV2TaskEvidence task in tasks) {
      if (isOverdue(task)) continue;
      final DateTime? day = taskDay(task);
      if (day != null && inRange(day)) {
        items.add((
          day: day,
          text: '"${task.title}" · ${timing(task)}',
          id: taskId(task),
        ));
      }
    }
    for (final SIV2TimelineEvidence event in snapshot.timeline) {
      final DateTime? due = event.dueAt;
      if (due == null ||
          (event.relatedId != null && taskIds.contains(event.relatedId)) ||
          const <String>{
            'completed',
            'skipped',
            'canceled',
          }.contains(event.status)) {
        continue;
      }
      final DateTime day = dayOf(due);
      if (inRange(day) && !isPast(due)) {
        items.add((
          day: day,
          text: '"${event.title}" · ${dateLabel(day)}',
          id: timelineLink(event),
        ));
      }
    }
    for (final SIV2GoalEvidence goal in snapshot.goals) {
      final DateTime? target = goal.targetDate;
      if (target == null) continue;
      final DateTime day = dayOf(target);
      if (inRange(day)) {
        items.add((
          day: day,
          text: t(
            'Goal "${goal.title}" · target ${dateLabel(day)}',
            'Meta "${goal.title}" · fecha objetivo ${dateLabel(day)}',
          ),
          id: goalLink(goal),
        ));
      }
    }
    items.sort((a, b) {
      final int byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : a.text.compareTo(b.text);
    });
    final int undated = tasks
        .where((SIV2TaskEvidence task) => taskDay(task) == null)
        .length;
    final int overdueCount = tasks.where(isOverdue).length;

    if (items.isEmpty) {
      missing(
        t(
          'Only items with a saved date or time can appear here.',
          'Solo pueden aparecer elementos con fecha u hora guardadas.',
        ),
      );
      if (undated > 0) {
        missing(
          t(
            '${count(undated, 'open task has', 'open tasks have', 'tarea abierta no tiene', 'tareas abiertas no tienen')} no date.',
            '${count(undated, 'tarea abierta no tiene', 'tareas abiertas no tienen', 'tarea abierta no tiene', 'tareas abiertas no tienen')} fecha.',
          ),
        );
      }
      if (overdueCount > 0) {
        fact(
          t(
            '${count(overdueCount, 'open task is', 'open tasks are', 'tarea abierta está', 'tareas abiertas están')} already overdue.',
            '${count(overdueCount, 'tarea abierta ya está', 'tareas abiertas ya están', 'tarea abierta ya está', 'tareas abiertas ya están')} vencida${overdueCount == 1 ? '' : 's'}.',
          ),
          <String>[tasksGroup],
        );
      }
      return finish(
        direct: t(
          'Nothing with a date is coming up in the next 7 days.',
          'No viene nada con fecha en los próximos 7 días.',
        ),
        recommendation: overdueCount > 0
            ? t(
                'Your open week is a good time to look at what is already overdue. Ask "What am I falling behind on".',
                'Tu semana libre es buen momento para mirar lo que ya venció. Pregunta "Qué estoy dejando atrás".',
              )
            : t(
                'Your week is open. Save something in Add something if a date should be on it.',
                'Tu semana está libre. Guarda algo en Añadir algo si debe haber una fecha.',
              ),
        offerAdd: undated == 0,
      );
    }
    fact(
      t(
        '${count(items.length, 'item has', 'items have', 'elemento tiene', 'elementos tienen')} a date in the next 7 days.',
        '${count(items.length, 'elemento tiene', 'elementos tienen', 'elemento tiene', 'elementos tienen')} fecha en los próximos 7 días.',
      ),
      <String>[items.first.id],
    );
    for (final item in items.take(6)) {
      fact(item.text, <String>[item.id]);
    }
    if (items.length > 6) {
      missing(
        t(
          '${items.length - 6} more are not listed here.',
          'Hay ${items.length - 6} más que no se muestran aquí.',
        ),
      );
    }
    if (undated > 0) {
      missing(
        t(
          '${count(undated, 'open task has', 'open tasks have', 'tarea abierta no tiene', 'tareas abiertas no tienen')} no date and is not shown.',
          '${count(undated, 'tarea abierta no tiene', 'tareas abiertas no tienen', 'tarea abierta no tiene', 'tareas abiertas no tienen')} fecha y no se muestra.',
        ),
      );
    }
    final item = items.first;
    return finish(
      direct: t(
        '${count(items.length, 'item is', 'items are', 'elemento está', 'elementos están')} coming up in the next 7 days. The nearest is ${item.text}.',
        '${count(items.length, 'elemento viene', 'elementos vienen', 'elemento viene', 'elementos vienen')} en los próximos 7 días. Lo más cercano es ${item.text}.',
      ),
      recommendation: t(
        'Look at ${item.text} first. Nothing was changed.',
        'Mira primero ${item.text}. No se cambió nada.',
      ),
    );
  }

  // ------------------------------------------------ Falling behind / on track

  List<SIV2TaskEvidence> get overdueByWait =>
      tasks.where(isOverdue).toList()..sort(compareByWait);

  /// A habit counts as quiet only when it is old enough to judge and has no
  /// check-in in the whole 14 day window.
  List<SIV2HabitEvidence> get quietHabits => snapshot.habits
      .where(
        (SIV2HabitEvidence h) =>
            h.cadence != HabitCadence.monthly &&
            h.checkInsInWindow == 0 &&
            now.difference(h.createdAt.toLocal()).inDays >= _habitWindowDays,
      )
      .toList(growable: false);

  List<SIV2GoalEvidence> get lateGoals => snapshot.goals
      .where(
        (SIV2GoalEvidence g) => g.targetDate != null && isPast(g.targetDate!),
      )
      .toList(growable: false);

  List<SIV2MilestoneEvidence> get lateMilestones => snapshot.milestones
      .where(
        (SIV2MilestoneEvidence m) =>
            !m.archived &&
            !m.completed &&
            m.targetDate != null &&
            isPast(m.targetDate!),
      )
      .toList(growable: false);

  void _behindFacts(
    List<SIV2TaskEvidence> overdue,
    List<SIV2GoalEvidence> goals,
    List<SIV2MilestoneEvidence> milestones,
    List<SIV2HabitEvidence> habits,
  ) {
    if (overdue.isNotEmpty) {
      fact(
        t(
          '${count(overdue.length, 'open task is', 'open tasks are', 'tarea abierta está', 'tareas abiertas están')} overdue.',
          '${count(overdue.length, 'tarea abierta está', 'tareas abiertas están', 'tarea abierta está', 'tareas abiertas están')} vencida${overdue.length == 1 ? '' : 's'}.',
        ),
        <String>[tasksGroup],
      );
      for (final SIV2TaskEvidence task in overdue.take(4)) {
        fact('"${task.title}" · ${timing(task)}', <String>[taskId(task)]);
      }
    }
    for (final SIV2GoalEvidence goal in goals.take(3)) {
      fact(
        t(
          'Goal "${goal.title}" passed its target date (${dateLabel(dayOf(goal.targetDate!))}) and is still active.',
          'La meta "${goal.title}" pasó su fecha objetivo (${dateLabel(dayOf(goal.targetDate!))}) y sigue activa.',
        ),
        <String>[goalLink(goal)],
      );
    }
    for (final SIV2MilestoneEvidence item in milestones.take(3)) {
      fact(
        t(
          'Milestone "${item.title}" passed its target date (${dateLabel(dayOf(item.targetDate!))}) and is not done.',
          'El hito "${item.title}" pasó su fecha objetivo (${dateLabel(dayOf(item.targetDate!))}) y no está hecho.',
        ),
        <String>[milestoneLink(item)],
      );
    }
    for (final SIV2HabitEvidence habit in habits.take(3)) {
      fact(
        t(
          'Habit "${habit.title}" has no check-in in the last 14 days.',
          'El hábito "${habit.title}" no tiene registros en los últimos 14 días.',
        ),
        <String>[habitLink(habit)],
      );
    }
  }

  SIOneTapAnswer fallingBehind() {
    if (isEmptyAccount) return empty('catch up on', 'poner al día');
    final List<SIV2TaskEvidence> overdue = overdueByWait;
    final List<SIV2GoalEvidence> goals = lateGoals;
    final List<SIV2MilestoneEvidence> milestones = lateMilestones;
    final List<SIV2HabitEvidence> habits = quietHabits;
    final int total =
        overdue.length + goals.length + milestones.length + habits.length;
    missing(
      t(
        'Tasks with no date cannot be late, and a habit counts as quiet only after 14 days with no check-in.',
        'Las tareas sin fecha no pueden estar atrasadas, y un hábito cuenta como inactivo solo tras 14 días sin registros.',
      ),
    );
    if (total == 0) {
      return finish(
        direct: t(
          'Nothing I can read is behind: no task is overdue, no goal or milestone is past its date, and no habit has gone quiet.',
          'Nada de lo que puedo leer va atrasado: ninguna tarea está vencida, ninguna meta ni hito pasó su fecha y ningún hábito está inactivo.',
        ),
        recommendation: t(
          'Keep your current pace. Nothing was changed.',
          'Mantén tu ritmo actual. No se cambió nada.',
        ),
      );
    }
    _behindFacts(overdue, goals, milestones, habits);
    final String first = overdue.isNotEmpty
        ? t(
            'Start with "${overdue.first.title}", which has waited longest (${timing(overdue.first)}).',
            'Empieza con "${overdue.first.title}", que lleva más tiempo esperando (${timing(overdue.first)}).',
          )
        : goals.isNotEmpty
        ? t(
            'Look at goal "${goals.first.title}" first.',
            'Mira primero la meta "${goals.first.title}".',
          )
        : milestones.isNotEmpty
        ? t(
            'Look at milestone "${milestones.first.title}" first.',
            'Mira primero el hito "${milestones.first.title}".',
          )
        : t(
            'Check in with "${habits.first.title}" when you can.',
            'Registra "${habits.first.title}" cuando puedas.',
          );
    return finish(
      direct: t(
        '${count(total, 'thing is', 'things are', 'cosa va', 'cosas van')} behind: ${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'}, ${goals.length} ${goals.length == 1 ? 'goal' : 'goals'} and ${milestones.length} ${milestones.length == 1 ? 'milestone' : 'milestones'} past their date, and ${habits.length} quiet ${habits.length == 1 ? 'habit' : 'habits'}.',
        '${count(total, 'cosa va', 'cosas van', 'cosa va', 'cosas van')} atrasada${total == 1 ? '' : 's'}: ${overdue.length} ${overdue.length == 1 ? 'tarea vencida' : 'tareas vencidas'}, ${goals.length} ${goals.length == 1 ? 'meta' : 'metas'} y ${milestones.length} ${milestones.length == 1 ? 'hito' : 'hitos'} fuera de fecha, y ${habits.length} ${habits.length == 1 ? 'hábito inactivo' : 'hábitos inactivos'}.',
      ),
      recommendation:
          '$first ${t('Nothing was changed.', 'No se cambió nada.')}',
    );
  }

  SIOneTapAnswer getBackOnTrack() {
    if (isEmptyAccount) return empty('get back on track with', 'retomar');
    final List<SIV2TaskEvidence> overdue = overdueByWait;
    final List<SIV2GoalEvidence> goals = lateGoals;
    final List<SIV2HabitEvidence> habits = quietHabits;
    missing(
      t(
        'Why things slipped is not recorded, so this only shows what is open.',
        'No se registra por qué se atrasaron las cosas, así que esto solo muestra lo que está abierto.',
      ),
    );
    if (overdue.isEmpty && goals.isEmpty && habits.isEmpty) {
      return finish(
        direct: t(
          'You are not behind on anything I can read: no task is overdue, no goal is past its date and no habit has gone quiet.',
          'No estás atrasado en nada que pueda leer: ninguna tarea está vencida, ninguna meta pasó su fecha y ningún hábito está inactivo.',
        ),
        recommendation: t(
          'There is nothing to catch up on. Keep going at your own pace. Nothing was changed.',
          'No hay nada que recuperar. Sigue a tu ritmo. No se cambió nada.',
        ),
      );
    }
    _behindFacts(overdue, goals, const <SIV2MilestoneEvidence>[], habits);
    infer(
      t(
        'One small step is easier to start than a full catch-up.',
        'Un paso pequeño es más fácil de empezar que ponerse al día con todo.',
      ),
    );
    final String step = overdue.isNotEmpty
        ? t(
            'Do just one thing first: "${overdue.first.title}" (${timing(overdue.first)}).',
            'Haz solo una cosa primero: "${overdue.first.title}" (${timing(overdue.first)}).',
          )
        : habits.isNotEmpty
        ? t(
            'Do just one thing first: check in with "${habits.first.title}".',
            'Haz solo una cosa primero: registra "${habits.first.title}".',
          )
        : t(
            'Do just one thing first: open goal "${goals.first.title}" and pick its next step.',
            'Haz solo una cosa primero: abre la meta "${goals.first.title}" y elige su siguiente paso.',
          );
    return finish(
      direct: t(
        'You are behind on ${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'}, ${goals.length} ${goals.length == 1 ? 'goal' : 'goals'} past ${goals.length == 1 ? 'its' : 'their'} date and ${habits.length} quiet ${habits.length == 1 ? 'habit' : 'habits'}.',
        'Tienes ${overdue.length} ${overdue.length == 1 ? 'tarea vencida' : 'tareas vencidas'}, ${goals.length} ${goals.length == 1 ? 'meta fuera de fecha' : 'metas fuera de fecha'} y ${habits.length} ${habits.length == 1 ? 'hábito inactivo' : 'hábitos inactivos'}.',
      ),
      recommendation:
          '$step ${t('Everything else can wait until it is done. If something no longer matters, you can move or remove it yourself. Nothing was changed.', 'Lo demás puede esperar. Si algo ya no importa, puedes moverlo o quitarlo tú. No se cambió nada.')}',
      offerAi: true,
    );
  }

  // -------------------------------------------------------------- Reach goal

  SIOneTapAnswer reachGoal(String? goalId) {
    final List<SIV2GoalEvidence> goals = snapshot.goals;
    if (goals.isEmpty) {
      missing(
        t('No active goal is saved.', 'No hay ninguna meta activa guardada.'),
      );
      return finish(
        direct: t(
          'You have no active goal yet, so there is nothing to work toward.',
          'Todavía no tienes una meta activa, así que no hay nada hacia lo que avanzar.',
        ),
        recommendation: t(
          'Save a goal in Add something, then ask again. Nothing was changed.',
          'Guarda una meta en Añadir algo y vuelve a preguntar. No se cambió nada.',
        ),
        offerAdd: true,
      );
    }
    SIV2GoalEvidence? goal;
    if (goalId != null) {
      for (final SIV2GoalEvidence g in goals) {
        if (g.id == goalId) goal = g;
      }
    } else if (goals.length == 1) {
      goal = goals.single;
    }
    if (goal == null) {
      missing(
        t(
          'Which goal you mean is not known.',
          'No se sabe a qué meta te refieres.',
        ),
      );
      fact(
        t(
          '${count(goals.length, 'active goal is', 'active goals are', 'meta activa está', 'metas activas están')} saved.',
          '${count(goals.length, 'meta activa está', 'metas activas están', 'meta activa está', 'metas activas están')} guardada${goals.length == 1 ? '' : 's'}.',
        ),
        <String>[goalsGroup],
      );
      return finish(
        direct: goalId == null
            ? t(
                'You have ${goals.length} active goals. Choose one and I can look at it.',
                'Tienes ${goals.length} metas activas. Elige una y la reviso.',
              )
            : t(
                'That goal is no longer saved or active.',
                'Esa meta ya no está guardada o activa.',
              ),
        recommendation: t(
          'Ask again and choose a goal from the list.',
          'Pregunta de nuevo y elige una meta de la lista.',
        ),
      );
    }
    final SIV2GoalEvidence chosen = goal;
    final String goalRef = goalLink(chosen);
    final List<SIV2TaskEvidence> linked =
        tasks
            .where((SIV2TaskEvidence task) => task.goalId == chosen.id)
            .toList()
          ..sort(compareTasks);
    final int tasksTotal = chosen.linkedTasksDone + chosen.linkedTasksOpen;
    final int milestonesTotal = chosen.milestonesDone + chosen.milestonesOpen;
    final DateTime? target = chosen.targetDate == null
        ? null
        : dayOf(chosen.targetDate!);

    if (target != null) {
      final int days = daysFromToday(target);
      fact(
        days < 0
            ? t(
                'The target date, ${dateLabel(target)}, passed ${count(-days, 'day', 'days', 'día', 'días')} ago.',
                'La fecha objetivo, ${dateLabel(target)}, pasó hace ${count(-days, 'día', 'días', 'día', 'días')}.',
              )
            : days == 0
            ? t(
                'The target date is today (${dateLabel(target)}).',
                'La fecha objetivo es hoy (${dateLabel(target)}).',
              )
            : t(
                'The target date is ${dateLabel(target)}, in ${count(days, 'day', 'days', 'día', 'días')}.',
                'La fecha objetivo es el ${dateLabel(target)}, dentro de ${count(days, 'día', 'días', 'día', 'días')}.',
              ),
        <String>[goalRef],
      );
    } else {
      missing(
        t(
          'This goal has no target date.',
          'Esta meta no tiene fecha objetivo.',
        ),
      );
    }
    if (tasksTotal > 0) {
      calc(
        t(
          '${chosen.linkedTasksDone} of ${count(tasksTotal, 'linked task', 'linked tasks', 'tarea vinculada', 'tareas vinculadas')} ${chosen.linkedTasksDone == 1 ? 'is' : 'are'} done.',
          '${chosen.linkedTasksDone} de ${count(tasksTotal, 'tarea vinculada', 'tareas vinculadas', 'tarea vinculada', 'tareas vinculadas')} ${chosen.linkedTasksDone == 1 ? 'está hecha' : 'están hechas'}.',
        ),
        <String>[goalRef],
      );
    }
    if (milestonesTotal > 0) {
      calc(
        t(
          '${chosen.milestonesDone} of ${count(milestonesTotal, 'milestone', 'milestones', 'hito', 'hitos')} ${chosen.milestonesDone == 1 ? 'is' : 'are'} done.',
          '${chosen.milestonesDone} de ${count(milestonesTotal, 'hito', 'hitos', 'hito', 'hitos')} ${chosen.milestonesDone == 1 ? 'está hecho' : 'están hechos'}.',
        ),
        <String>[goalRef],
      );
    }
    for (final SIV2TaskEvidence task in linked.take(4)) {
      fact('"${task.title}" · ${timing(task)}', <String>[taskId(task)]);
    }
    if (tasksTotal + milestonesTotal == 0) {
      missing(
        t(
          'No task or milestone is linked to this goal, so how far along it is cannot be told.',
          'Ninguna tarea ni hito está vinculado a esta meta, así que no se puede saber cuánto ha avanzado.',
        ),
      );
    } else {
      missing(
        t(
          'Progress counts only the tasks and milestones you linked to this goal.',
          'El avance cuenta solo las tareas e hitos que vinculaste a esta meta.',
        ),
      );
    }
    final bool hasNext = linked.isNotEmpty;
    final String progress = tasksTotal + milestonesTotal == 0
        ? t('Nothing is linked to it yet.', 'Todavía no hay nada vinculado.')
        : t(
            '${chosen.linkedTasksDone} of $tasksTotal linked ${tasksTotal == 1 ? 'task is' : 'tasks are'} done${milestonesTotal > 0 ? ' and ${chosen.milestonesDone} of $milestonesTotal ${milestonesTotal == 1 ? 'milestone' : 'milestones'}' : ''}.',
            '${chosen.linkedTasksDone} de $tasksTotal ${tasksTotal == 1 ? 'tarea vinculada está hecha' : 'tareas vinculadas están hechas'}${milestonesTotal > 0 ? ' y ${chosen.milestonesDone} de $milestonesTotal ${milestonesTotal == 1 ? 'hito' : 'hitos'}' : ''}.',
          );
    return finish(
      direct: t(
        'Goal "${chosen.title}": $progress',
        'Meta "${chosen.title}": $progress',
      ),
      recommendation: hasNext
          ? t(
              'Take the next step on "${linked.first.title}" (${timing(linked.first)}). Nothing was changed.',
              'Da el siguiente paso en "${linked.first.title}" (${timing(linked.first)}). No se cambió nada.',
            )
          : t(
              'Add one small first step for this goal in Add something, where you review it before it is saved. Nothing was changed.',
              'Añade un primer paso pequeño para esta meta en Añadir algo, donde lo revisas antes de guardarlo. No se cambió nada.',
            ),
      offerAdd: !hasNext,
      offerAi: true,
    );
  }

  // --------------------------------------------------------- Improve routine

  /// Check-ins expected in the window for a habit's cadence, or null when the
  /// window is too short to judge (monthly) or the habit is too new.
  int? _expected(SIV2HabitEvidence habit) {
    final int ageDays = now.difference(habit.createdAt.toLocal()).inDays;
    if (ageDays < 3 || habit.cadence == HabitCadence.monthly) return null;
    final int span = ageDays + 1 < habit.windowDays
        ? ageDays + 1
        : habit.windowDays;
    return habit.cadence == HabitCadence.daily ? span : (span / 7).floor();
  }

  String _habitLine(SIV2HabitEvidence h) {
    final String cadence = switch (h.cadence) {
      HabitCadence.daily => t('daily', 'diario'),
      HabitCadence.weekly => t('weekly', 'semanal'),
      HabitCadence.monthly => t('monthly', 'mensual'),
    };
    return t(
      '"${h.title}" · $cadence · ${count(h.checkInsInWindow, 'check-in', 'check-ins', 'registro', 'registros')} in the last 14 days · streak ${h.currentStreak}',
      '"${h.title}" · $cadence · ${count(h.checkInsInWindow, 'registro', 'registros', 'registro', 'registros')} en los últimos 14 días · racha ${h.currentStreak}',
    );
  }

  SIOneTapAnswer improveRoutine() {
    final List<SIV2HabitEvidence> habits = snapshot.habits;
    if (habits.isEmpty) {
      missing(t('No habit is saved.', 'No hay ningún hábito guardado.'));
      return finish(
        direct: t(
          'You have no habits saved yet, so there is no routine to improve.',
          'Todavía no tienes hábitos guardados, así que no hay una rutina que mejorar.',
        ),
        recommendation: t(
          'Save one small habit in Add something, where you review it before it is saved. Nothing was changed.',
          'Guarda un hábito pequeño en Añadir algo, donde lo revisas antes de guardarlo. No se cambió nada.',
        ),
        offerAdd: true,
      );
    }
    final List<SIV2HabitEvidence> judged = habits
        .where((SIV2HabitEvidence h) => _expected(h) != null)
        .toList(growable: false);
    double ratio(SIV2HabitEvidence h) {
      final int expected = _expected(h)!;
      return expected == 0 ? 1 : h.checkInsInWindow / expected;
    }

    judged.sort((a, b) => ratio(b).compareTo(ratio(a)));
    for (final SIV2HabitEvidence h in habits.take(5)) {
      fact(_habitLine(h), <String>[habitLink(h)]);
    }
    final int withCheckIn = habits
        .where((SIV2HabitEvidence h) => h.checkInsInWindow > 0)
        .length;
    calc(
      t(
        '$withCheckIn of ${habits.length} ${habits.length == 1 ? 'habit has' : 'habits have'} a check-in in the last 14 days.',
        '$withCheckIn de ${habits.length} ${habits.length == 1 ? 'hábito tiene' : 'hábitos tienen'} un registro en los últimos 14 días.',
      ),
      <String>[habitsGroup],
    );
    missing(
      t(
        'The time of day and how each check-in felt are not recorded.',
        'No se registran la hora del día ni cómo se sintió cada registro.',
      ),
    );
    final int tooNew = habits.length - judged.length;
    if (tooNew > 0) {
      missing(
        t(
          '${count(tooNew, 'habit is', 'habits are', 'hábito es', 'hábitos son')} too new, or too infrequent, to judge from 14 days.',
          '${count(tooNew, 'hábito es', 'hábitos son', 'hábito es', 'hábitos son')} demasiado nuevo${tooNew == 1 ? '' : 's'}, o poco frecuente${tooNew == 1 ? '' : 's'}, para juzgar con 14 días.',
        ),
      );
    }
    String recommendation;
    if (judged.isEmpty) {
      recommendation = t(
        'Give your habits a few more days of check-ins, then ask again. Nothing was changed.',
        'Dale a tus hábitos unos días más de registros y pregunta de nuevo. No se cambió nada.',
      );
    } else {
      final SIV2HabitEvidence best = judged.first;
      final SIV2HabitEvidence worst = judged.last;
      if (judged.length > 1 && ratio(worst) < 0.5) {
        recommendation = t(
          'Keep "${best.title}" as it is. "${worst.title}" is the one that slips; making it smaller or less frequent may help. You can change it yourself in Daily Rhythms. Nothing was changed.',
          'Mantén "${best.title}" como está. "${worst.title}" es el que se te escapa; hacerlo más pequeño o menos frecuente puede ayudar. Puedes cambiarlo tú en Ritmos diarios. No se cambió nada.',
        );
      } else if (judged.length == 1 && ratio(best) < 0.5) {
        recommendation = t(
          '"${best.title}" slips most days; making it smaller or less frequent may help. You can change it yourself in Daily Rhythms. Nothing was changed.',
          '"${best.title}" se te escapa casi siempre; hacerlo más pequeño o menos frecuente puede ayudar. Puedes cambiarlo tú en Ritmos diarios. No se cambió nada.',
        );
      } else {
        recommendation = t(
          'Your habits look steady over these 14 days. Keep the current rhythm. Nothing was changed.',
          'Tus hábitos se ven constantes en estos 14 días. Mantén el ritmo actual. No se cambió nada.',
        );
      }
    }
    return finish(
      direct: t(
        'You have ${count(habits.length, 'habit', 'habits', 'hábito', 'hábitos')}. Over the last 14 days, $withCheckIn ${withCheckIn == 1 ? 'has' : 'have'} a check-in and ${habits.length - withCheckIn} ${habits.length - withCheckIn == 1 ? 'has' : 'have'} none.',
        'Tienes ${count(habits.length, 'hábito', 'hábitos', 'hábito', 'hábitos')}. En los últimos 14 días, $withCheckIn ${withCheckIn == 1 ? 'tiene' : 'tienen'} registros y ${habits.length - withCheckIn} no ${habits.length - withCheckIn == 1 ? 'tiene' : 'tienen'}.',
      ),
      recommendation: recommendation,
      offerAi: true,
    );
  }

  // -------------------------------------------------------- Explain patterns

  String _weekday(int weekday) => const <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];

  String _weekdayEs(int weekday) => const <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ][weekday - 1];

  SIOneTapAnswer explainPatterns() {
    if (isEmptyAccount) return empty('find a pattern in', 'ver como patrón');
    final List<SIV2RecentTaskEvidence> recent = snapshot.recentTasks;
    final List<SIV2RecentTaskEvidence> done = recent
        .where(
          (SIV2RecentTaskEvidence r) =>
              r.outcome == SIV2RecentTaskOutcome.completed,
        )
        .toList(growable: false);
    final int skipped = recent.length - done.length;
    missing(
      t(
        'These are patterns in what was recorded, not reasons. Why something happened is not stored.',
        'Son patrones de lo registrado, no razones. No se guarda por qué pasó algo.',
      ),
    );
    if (recent.isNotEmpty) {
      fact(
        t(
          '${count(done.length, 'task was', 'tasks were', 'tarea fue', 'tareas fueron')} finished and $skipped skipped in the last 14 days.',
          '${count(done.length, 'tarea se terminó', 'tareas se terminaron', 'tarea se terminó', 'tareas se terminaron')} y $skipped se omitieron en los últimos 14 días.',
        ),
        <String>[recentGroup],
      );
    }
    for (final SIV2HabitEvidence h in snapshot.habits.take(3)) {
      fact(_habitLine(h), <String>[habitLink(h)]);
    }
    final bool enough = recent.length >= _patternMinimum;
    String direct;
    if (!enough) {
      missing(
        t(
          'Only ${count(recent.length, 'finished or skipped task', 'finished or skipped tasks', 'tarea terminada u omitida', 'tareas terminadas u omitidas')} in the last 14 days; at least $_patternMinimum are needed to show a pattern.',
          'Solo ${count(recent.length, 'tarea terminada u omitida', 'tareas terminadas u omitidas', 'tarea terminada u omitida', 'tareas terminadas u omitidas')} en los últimos 14 días; hacen falta al menos $_patternMinimum para ver un patrón.',
        ),
      );
      direct = t(
        'There is too little history to show a pattern yet.',
        'Todavía hay muy poco historial para mostrar un patrón.',
      );
    } else {
      final Map<int, int> byDay = <int, int>{};
      final Map<String, int> byPart = <String, int>{};
      for (final SIV2RecentTaskEvidence r in done) {
        final DateTime at = r.at.toLocal();
        byDay.update(at.weekday, (int v) => v + 1, ifAbsent: () => 1);
        final String part = at.hour < 12
            ? 'morning'
            : at.hour < 17
            ? 'afternoon'
            : 'evening';
        byPart.update(part, (int v) => v + 1, ifAbsent: () => 1);
      }
      final List<String> lines = <String>[];
      if (done.length >= 3) {
        final MapEntry<int, int> top = byDay.entries.reduce(
          (a, b) => b.value > a.value || (b.value == a.value && b.key < a.key)
              ? b
              : a,
        );
        if (top.value >= 2) {
          final String text = t(
            '${top.value} of ${done.length} finished tasks were finished on a ${_weekday(top.key)}.',
            '${top.value} de ${done.length} tareas terminadas se terminaron un ${_weekdayEs(top.key)}.',
          );
          calc(text, <String>[recentGroup]);
          lines.add(
            t(
              '${_weekday(top.key)} is your most active day.',
              '${_weekdayEs(top.key)} es tu día más activo.',
            ),
          );
        }
        final MapEntry<String, int> part = byPart.entries.reduce(
          (a, b) => b.value > a.value ? b : a,
        );
        if (part.value * 2 > done.length) {
          final String en = part.key;
          final String es = switch (part.key) {
            'morning' => 'por la mañana',
            'afternoon' => 'por la tarde',
            _ => 'por la noche',
          };
          calc(
            t(
              '${part.value} of ${done.length} finished tasks were finished in the $en.',
              '${part.value} de ${done.length} tareas terminadas se terminaron $es.',
            ),
            <String>[recentGroup],
          );
          lines.add(
            t(
              'You finish most tasks in the $en.',
              'Terminas la mayoría de las tareas $es.',
            ),
          );
        }
      }
      final int overdue = tasks.where(isOverdue).length;
      if (skipped > 0) {
        calc(
          t(
            'Skipped tasks are ${(skipped * 100 / recent.length).round()}% of those finished or skipped.',
            'Las tareas omitidas son el ${(skipped * 100 / recent.length).round()}% de las terminadas u omitidas.',
          ),
          <String>[recentGroup],
        );
      }
      if (overdue > 0) {
        lines.add(
          t(
            '${count(overdue, 'task is', 'tasks are', 'tarea está', 'tareas están')} overdue.',
            '${count(overdue, 'tarea está', 'tareas están', 'tarea está', 'tareas están')} vencida${overdue == 1 ? '' : 's'}.',
          ),
        );
      }
      direct = lines.isEmpty
          ? t(
              'The last 14 days show no clear pattern: ${done.length} finished and $skipped skipped, spread without a standout day or time.',
              'Los últimos 14 días no muestran un patrón claro: ${done.length} terminadas y $skipped omitidas, sin un día u hora destacados.',
            )
          : lines.join(' ');
      infer(
        t(
          'A pattern from 14 days can change; treat it as a hint.',
          'Un patrón de 14 días puede cambiar; tómalo como una pista.',
        ),
      );
    }
    return finish(
      direct: direct,
      recommendation: enough
          ? t(
              'Use this as a hint when you plan, and keep tracking. Nothing was changed.',
              'Úsalo como pista al planear y sigue registrando. No se cambió nada.',
            )
          : t(
              'Keep finishing or skipping tasks as you go; patterns appear after about $_patternMinimum. Nothing was changed.',
              'Sigue terminando u omitiendo tareas; los patrones aparecen tras unas $_patternMinimum. No se cambió nada.',
            ),
      offerAi: true,
    );
  }

  // ------------------------------------------------------------- Review week

  SIOneTapAnswer reviewWeek() {
    if (isEmptyAccount) {
      return empty('review for your week', 'revisar en tu semana');
    }
    final DateTime weekStart = today.subtract(const Duration(days: 6));
    final DateTime prevStart = today.subtract(const Duration(days: 13));
    int doneThis = 0;
    int skippedThis = 0;
    int donePrev = 0;
    for (final SIV2RecentTaskEvidence r in snapshot.recentTasks) {
      final DateTime day = DateTime(
        r.at.toLocal().year,
        r.at.toLocal().month,
        r.at.toLocal().day,
      );
      final bool completed = r.outcome == SIV2RecentTaskOutcome.completed;
      if (!day.isBefore(weekStart)) {
        completed ? doneThis++ : skippedThis++;
      } else if (!day.isBefore(prevStart) && completed) {
        donePrev++;
      }
    }
    final int overdue = tasks.where(isOverdue).length;
    final int nextWeek = tasks.where((SIV2TaskEvidence task) {
      if (isOverdue(task)) return false;
      final DateTime? day = taskDay(task);
      return day != null &&
          !day.isBefore(today) &&
          day.isBefore(today.add(const Duration(days: 8)));
    }).length;
    final int habitCheckIns = snapshot.habits.fold(
      0,
      (int sum, SIV2HabitEvidence h) => sum + h.checkInsInWindow,
    );
    fact(
      t(
        'In the last 7 days, ${count(doneThis, 'task was', 'tasks were', 'tarea se terminó', 'tareas se terminaron')} finished and $skippedThis skipped.',
        'En los últimos 7 días se ${doneThis == 1 ? 'terminó' : 'terminaron'} $doneThis ${doneThis == 1 ? 'tarea' : 'tareas'} y se omitieron $skippedThis.',
      ),
      <String>[recentGroup],
    );
    fact(
      t(
        'In the 7 days before that, $donePrev ${donePrev == 1 ? 'task was' : 'tasks were'} finished.',
        'En los 7 días anteriores se ${donePrev == 1 ? 'terminó' : 'terminaron'} $donePrev ${donePrev == 1 ? 'tarea' : 'tareas'}.',
      ),
      <String>[recentGroup],
    );
    if (snapshot.habits.isNotEmpty) {
      fact(
        t(
          '${count(habitCheckIns, 'habit check-in', 'habit check-ins', 'registro de hábito', 'registros de hábitos')} in the last 14 days across ${count(snapshot.habits.length, 'habit', 'habits', 'hábito', 'hábitos')}.',
          '${count(habitCheckIns, 'registro de hábito', 'registros de hábitos', 'registro de hábito', 'registros de hábitos')} en los últimos 14 días en ${count(snapshot.habits.length, 'hábito', 'hábitos', 'hábito', 'hábitos')}.',
        ),
        <String>[habitsGroup],
      );
    }
    if (tasks.isNotEmpty) {
      fact(
        t(
          '${count(overdue, 'open task is', 'open tasks are', 'tarea abierta está', 'tareas abiertas están')} overdue and $nextWeek ${nextWeek == 1 ? 'is' : 'are'} due or planned in the next 7 days.',
          '${count(overdue, 'tarea abierta está', 'tareas abiertas están', 'tarea abierta está', 'tareas abiertas están')} vencida${overdue == 1 ? '' : 's'} y $nextWeek ${nextWeek == 1 ? 'es' : 'son'} para los próximos 7 días.',
        ),
        <String>[tasksGroup],
      );
    }
    missing(
      t(
        'Habit check-ins are counted over 14 days, not 7. Tasks finished without a recorded time are not counted.',
        'Los registros de hábitos se cuentan en 14 días, no 7. Las tareas terminadas sin hora registrada no se cuentan.',
      ),
    );
    if (snapshot.recentTasks.isEmpty) {
      missing(
        t(
          'No task was finished or skipped in the last 14 days, so there is no week to compare.',
          'Ninguna tarea se terminó ni se omitió en los últimos 14 días, así que no hay semana que comparar.',
        ),
      );
    }
    final String trend = doneThis > donePrev
        ? t('more than the week before', 'más que la semana anterior')
        : doneThis < donePrev
        ? t('fewer than the week before', 'menos que la semana anterior')
        : t('the same as the week before', 'lo mismo que la semana anterior');
    return finish(
      direct: snapshot.recentTasks.isEmpty
          ? t(
              'No task was finished or skipped in the last 7 days.',
              'Ninguna tarea se terminó ni se omitió en los últimos 7 días.',
            )
          : t(
              'This week, $doneThis ${doneThis == 1 ? 'task was' : 'tasks were'} finished and $skippedThis skipped: $trend ($donePrev).',
              'Esta semana se ${doneThis == 1 ? 'terminó' : 'terminaron'} $doneThis ${doneThis == 1 ? 'tarea' : 'tareas'} y se omitieron $skippedThis: $trend ($donePrev).',
            ),
      recommendation: overdue > 0
          ? t(
              'Start next week with the $overdue overdue ${overdue == 1 ? 'task' : 'tasks'}. Nothing was changed.',
              'Empieza la próxima semana con ${overdue == 1 ? 'la tarea vencida' : 'las $overdue tareas vencidas'}. No se cambió nada.',
            )
          : t(
              'Nothing is overdue. Next week has $nextWeek ${nextWeek == 1 ? 'item' : 'items'} with a date. Nothing was changed.',
              'No hay nada vencido. La próxima semana tiene $nextWeek ${nextWeek == 1 ? 'elemento' : 'elementos'} con fecha. No se cambió nada.',
            ),
      offerAi: true,
    );
  }
}
