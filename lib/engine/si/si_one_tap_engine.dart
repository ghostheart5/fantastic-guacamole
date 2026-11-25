import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

part 'si_one_tap_engine.today.dart';
part 'si_one_tap_engine.goals.dart';
part 'si_one_tap_engine.review.dart';

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

  /// The local calendar day of a moment.
  DateTime dayOf(DateTime v) {
    final DateTime d = v.toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  /// The calendar day a deadline means: a deadline chosen as a whole day
  /// (`wholeDay`) is that day wherever the person is; a moment is read in local
  /// time.
  DateTime deadlineDay(DateTime moment, DateTime? wholeDay) =>
      wholeDay ?? dayOf(moment);

  /// A whole-day deadline is past only once its day has ended; a deadline with
  /// a time is past from that moment.
  bool deadlinePast(DateTime moment, DateTime? wholeDay) => wholeDay != null
      ? wholeDay.isBefore(today)
      : moment.toLocal().isBefore(now);

  bool isOverdue(SIV2TaskEvidence task) =>
      task.dueDate != null && deadlinePast(task.dueDate!, task.dueDay);

  DateTime? dueDayOf(SIV2TaskEvidence task) =>
      task.dueDate == null ? null : deadlineDay(task.dueDate!, task.dueDay);

  bool goalIsLate(SIV2GoalEvidence g) =>
      g.targetDate != null && deadlinePast(g.targetDate!, g.targetDay);

  DateTime? goalDay(SIV2GoalEvidence g) =>
      g.targetDate == null ? null : deadlineDay(g.targetDate!, g.targetDay);

  DateTime? milestoneDay(SIV2MilestoneEvidence m) =>
      m.targetDate == null ? null : deadlineDay(m.targetDate!, m.targetDay);

  /// The day the task asks for: its due day or, if earlier and not yet past,
  /// its planned day. A plan for a day that has gone while the task is due
  /// later does not make it due today.
  DateTime? taskDay(SIV2TaskEvidence task) {
    final DateTime? due = dueDayOf(task);
    final DateTime? planned = task.scheduledFor == null
        ? null
        : dayOf(task.scheduledFor!);
    final List<DateTime> days = <DateTime>[
      ?due,
      if (planned != null && !planned.isBefore(today)) planned,
    ]..sort();
    if (days.isNotEmpty) return days.first;
    return planned;
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
      final int days = -daysFromToday(dueDayOf(task)!);
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
    final DateTime? dueD = dueDayOf(task);
    final DateTime? plannedD = task.scheduledFor == null
        ? null
        : dayOf(task.scheduledFor!);
    final bool planned =
        dueD == null ||
        (plannedD != null &&
            !plannedD.isBefore(today) &&
            plannedD.isBefore(dueD));
    if (diff < 0) {
      return t(
        'planned for ${dateLabel(day)}, not done',
        'planeada para el ${dateLabel(day)}, sin hacer',
      );
    }
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
    final DateTime aDay = dueDayOf(a)!;
    final DateTime bDay = dueDayOf(b)!;
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
}
