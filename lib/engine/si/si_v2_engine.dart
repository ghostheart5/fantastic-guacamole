import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

final class SIV2Engine {
  const SIV2Engine();

  SIV2Response analyze({
    required SIV2Query query,
    required SIV2EvidenceSnapshot snapshot,
    required DateTime now,
  }) {
    final DateTime observedNow = now.toUtc();
    final String? entityFilter = query.entityFilter?.toLowerCase();
    bool matchesEntity(String title) =>
        entityFilter == null || title.toLowerCase().contains(entityFilter);

    final List<SIV2TaskEvidence> tasks =
        query.sources.contains(SIV2Source.tasks)
        ? snapshot.tasks
              .where((SIV2TaskEvidence item) => matchesEntity(item.title))
              .where(
                (SIV2TaskEvidence item) =>
                    _withinTaskRange(item, query.timeRange, observedNow),
              )
              .toList(growable: false)
        : const <SIV2TaskEvidence>[];
    final List<SIV2GoalEvidence> goals =
        query.sources.contains(SIV2Source.goals)
        ? snapshot.goals
              .where((SIV2GoalEvidence item) => matchesEntity(item.title))
              .where(
                (SIV2GoalEvidence item) => _withinDeadlineRange(
                  item.targetDate,
                  query.timeRange,
                  observedNow,
                  undatedMatches: true,
                ),
              )
              .toList(growable: false)
        : const <SIV2GoalEvidence>[];
    final List<SIV2MilestoneEvidence> milestones =
        query.sources.contains(SIV2Source.milestones)
        ? snapshot.milestones
              .where((SIV2MilestoneEvidence item) => !item.archived)
              .where((SIV2MilestoneEvidence item) => matchesEntity(item.title))
              .where(
                (SIV2MilestoneEvidence item) => _withinDeadlineRange(
                  item.targetDate,
                  query.timeRange,
                  observedNow,
                  undatedMatches: true,
                ),
              )
              .toList(growable: false)
        : const <SIV2MilestoneEvidence>[];
    final List<SIV2TimelineEvidence> timeline =
        query.sources.contains(SIV2Source.timeline)
        ? snapshot.timeline
              .where((SIV2TimelineEvidence item) => matchesEntity(item.title))
              .where(
                (SIV2TimelineEvidence item) =>
                    _withinTimelineRange(item, query.timeRange, observedNow),
              )
              .toList(growable: false)
        : const <SIV2TimelineEvidence>[];

    final List<SIV2EvidenceLink> links = _buildEvidenceLinks(
      snapshot: snapshot,
      query: query,
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      timeline: timeline,
    );
    final Map<String, SIV2EvidenceLink> linkById = <String, SIV2EvidenceLink>{
      for (final SIV2EvidenceLink link in links) link.evidenceId: link,
    };
    String sourceId(SIV2Source source) => '${source.name}:collection';

    final List<SIV2Statement> facts = <SIV2Statement>[
      if (query.sources.contains(SIV2Source.tasks))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text:
              '${tasks.length} active task${tasks.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.tasks)],
        ),
      if (query.sources.contains(SIV2Source.goals))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text:
              '${goals.length} active goal${goals.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.goals)],
        ),
      if (query.sources.contains(SIV2Source.milestones))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text:
              '${milestones.length} milestone${milestones.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.milestones)],
        ),
      if (query.sources.contains(SIV2Source.timeline))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text:
              '${timeline.length} Timeline event${timeline.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.timeline)],
        ),
    ];

    final int overdueTasks = tasks
        .where(
          (SIV2TaskEvidence item) =>
              item.dueDate != null &&
              item.dueDate!.toUtc().isBefore(observedNow),
        )
        .length;
    final int overdueGoals = goals
        .where(
          (SIV2GoalEvidence item) =>
              item.targetDate != null &&
              item.targetDate!.toUtc().isBefore(observedNow),
        )
        .length;
    final int overdueMilestones = milestones
        .where(
          (SIV2MilestoneEvidence item) =>
              !item.completed &&
              item.targetDate != null &&
              item.targetDate!.toUtc().isBefore(observedNow),
        )
        .length;
    final List<SIV2Statement> calculations = <SIV2Statement>[
      if (query.sources.contains(SIV2Source.tasks))
        SIV2Statement(
          kind: SIV2StatementKind.deterministicCalculation,
          text:
              '$overdueTasks matched task${overdueTasks == 1 ? ' is' : 's are'} past the recorded due date.',
          evidenceIds: <String>[sourceId(SIV2Source.tasks)],
        ),
      if (query.sources.contains(SIV2Source.goals))
        SIV2Statement(
          kind: SIV2StatementKind.deterministicCalculation,
          text:
              '$overdueGoals matched goal${overdueGoals == 1 ? ' is' : 's are'} past the recorded target date.',
          evidenceIds: <String>[sourceId(SIV2Source.goals)],
        ),
      if (query.sources.contains(SIV2Source.milestones))
        SIV2Statement(
          kind: SIV2StatementKind.deterministicCalculation,
          text:
              '$overdueMilestones incomplete milestone${overdueMilestones == 1 ? ' is' : 's are'} past the recorded target date.',
          evidenceIds: <String>[sourceId(SIV2Source.milestones)],
        ),
    ];

    final List<SIV2Conflict> conflicts = _detectConflicts(
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      now: observedNow,
      linkById: linkById,
    );
    final SIV2TaskEvidence? focusTask = _selectFocusTask(tasks);
    final List<SIV2Scenario> scenarios = _buildScenarios(
      task: focusTask,
      goals: goals,
      now: observedNow,
      userAssumptions: query.assumptions,
      linkById: linkById,
    );
    final List<String> scenarioAssumptions = <String>[
      'Scenarios describe recorded schedule effects, not certain outcomes.',
      'No unrecorded dependency, travel, or capacity constraint is assumed.',
      ...query.assumptions,
    ];
    final List<String> missing = <String>[
      for (final SIV2Source source in query.sources)
        if (snapshot.unavailableSources.contains(source))
          '${source.label} evidence is unavailable.',
      if (query.entityFilter != null &&
          tasks.isEmpty &&
          goals.isEmpty &&
          milestones.isEmpty &&
          timeline.isEmpty)
        'No entity title matched "${query.entityFilter}".',
      if (tasks.any(
        (SIV2TaskEvidence item) =>
            item.dueDate == null && item.scheduledFor == null,
      ))
        'At least one matched task has no due date or schedule.',
      ...conflicts.map((SIV2Conflict item) => item.summary),
    ];
    final List<SIV2Statement> inferences = <SIV2Statement>[
      if (overdueTasks + overdueGoals + overdueMilestones > 0)
        SIV2Statement(
          kind: SIV2StatementKind.inference,
          text:
              'Recorded deadline pressure appears to be the strongest attention signal.',
          evidenceIds: conflicts
              .expand((SIV2Conflict item) => item.evidenceIds)
              .toSet()
              .toList(growable: false),
        )
      else
        SIV2Statement(
          kind: SIV2StatementKind.inference,
          text:
              'No overdue deadline dominates this lens; priority and dependency order should drive the choice.',
          evidenceIds: focusTask == null
              ? const <String>[]
              : <String>['tasks:${focusTask.id}'],
        ),
    ];

    final String directAnswer = _directAnswer(
      query: query,
      focusTask: focusTask,
      goals: goals,
      conflicts: conflicts,
      scenarios: scenarios,
      totalMatched:
          tasks.length + goals.length + milestones.length + timeline.length,
    );
    final String recommendation = focusTask == null
        ? 'Add or broaden a source filter before acting; the current lens does not contain a grounded task recommendation.'
        : 'Review "${focusTask.title}" first because it is the highest-ranked matched task by recorded due date, priority, and title. SI has not changed it.';

    final int requiredSignals = query.sources.length;
    final int coveredSignals = query.sources
        .where(
          (SIV2Source source) => !snapshot.unavailableSources.contains(source),
        )
        .length;
    final Duration age = observedNow.difference(snapshot.observedAt.toUtc());
    final SIV2Freshness freshness = coveredSignals == 0
        ? SIV2Freshness.unavailable
        : age.isNegative || age <= const Duration(hours: 1)
        ? SIV2Freshness.current
        : age <= const Duration(hours: 24)
        ? SIV2Freshness.aging
        : SIV2Freshness.stale;
    final SIV2EvidenceStrength strength =
        coveredSignals == requiredSignals && links.length >= requiredSignals
        ? (conflicts.length <= 1
              ? SIV2EvidenceStrength.strong
              : SIV2EvidenceStrength.moderate)
        : coveredSignals * 2 >= requiredSignals
        ? SIV2EvidenceStrength.moderate
        : SIV2EvidenceStrength.limited;

    return SIV2Response(
      query: query,
      snapshotRevision: snapshot.revision,
      directAnswer: directAnswer,
      observedFacts: facts,
      calculations: calculations,
      inferences: inferences,
      missingInformation: missing,
      conflicts: conflicts,
      scenarios: scenarios,
      scenarioAssumptions: scenarioAssumptions,
      recommendation: recommendation,
      confidence: SIV2ConfidenceAnatomy(
        strength: strength,
        coveredSignals: coveredSignals,
        requiredSignals: requiredSignals,
        freshness: freshness,
        conflictCount: conflicts.length,
        assumptionCount: scenarioAssumptions.length,
      ),
      evidenceLinks: links,
    );
  }

  List<SIV2EvidenceLink> _buildEvidenceLinks({
    required SIV2EvidenceSnapshot snapshot,
    required SIV2Query query,
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required List<SIV2TimelineEvidence> timeline,
  }) {
    final List<SIV2EvidenceLink> links = <SIV2EvidenceLink>[];
    void collection(SIV2Source source, int count) {
      if (!query.sources.contains(source)) return;
      links.add(
        SIV2EvidenceLink(
          evidenceId: '${source.name}:collection',
          source: source,
          label: '${source.label} lens ($count matched)',
          entityId: 'collection',
          observedAt: snapshot.observedAt,
          uri: 'chronospark://${source.name}',
        ),
      );
    }

    collection(SIV2Source.tasks, tasks.length);
    collection(SIV2Source.goals, goals.length);
    collection(SIV2Source.milestones, milestones.length);
    collection(SIV2Source.timeline, timeline.length);
    links.addAll(
      tasks.map(
        (SIV2TaskEvidence item) => SIV2EvidenceLink(
          evidenceId: 'tasks:${item.id}',
          source: SIV2Source.tasks,
          label: item.title,
          entityId: item.id,
          observedAt: snapshot.observedAt,
          uri: 'chronospark://tasks/${item.id}',
        ),
      ),
    );
    links.addAll(
      goals.map(
        (SIV2GoalEvidence item) => SIV2EvidenceLink(
          evidenceId: 'goals:${item.id}',
          source: SIV2Source.goals,
          label: item.title,
          entityId: item.id,
          observedAt: snapshot.observedAt,
          uri: 'chronospark://goals/${item.id}',
        ),
      ),
    );
    links.addAll(
      milestones.map(
        (SIV2MilestoneEvidence item) => SIV2EvidenceLink(
          evidenceId: 'milestones:${item.id}',
          source: SIV2Source.milestones,
          label: item.title,
          entityId: item.id,
          observedAt: item.updatedAt,
          uri: 'chronospark://milestones/${item.id}',
        ),
      ),
    );
    links.addAll(
      timeline.map(
        (SIV2TimelineEvidence item) => SIV2EvidenceLink(
          evidenceId: 'timeline:${item.id}',
          source: SIV2Source.timeline,
          label: item.title,
          entityId: item.id,
          observedAt: item.timestamp,
          uri: 'chronospark://timeline/${item.id}',
        ),
      ),
    );
    return links;
  }

  List<SIV2Conflict> _detectConflicts({
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required DateTime now,
    required Map<String, SIV2EvidenceLink> linkById,
  }) {
    final Map<String, SIV2GoalEvidence> goalsById = <String, SIV2GoalEvidence>{
      for (final SIV2GoalEvidence goal in goals) goal.id: goal,
    };
    final Set<String> milestoneIds = milestones
        .map((SIV2MilestoneEvidence item) => item.id)
        .toSet();
    final List<SIV2Conflict> conflicts = <SIV2Conflict>[];
    for (final SIV2TaskEvidence task in tasks) {
      final String taskEvidence = 'tasks:${task.id}';
      if (task.dueDate != null && task.dueDate!.toUtc().isBefore(now)) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'overdue-task:${task.id}',
            severity: task.priority >= 4
                ? SIV2ConflictSeverity.critical
                : SIV2ConflictSeverity.warning,
            summary: 'Task "${task.title}" is past its recorded due date.',
            evidenceIds: <String>[
              if (linkById.containsKey(taskEvidence)) taskEvidence,
            ],
          ),
        );
      }
      final String? goalId = task.goalId;
      if (goalId == null) continue;
      final SIV2GoalEvidence? goal = goalsById[goalId];
      if (goal == null) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'missing-goal:$goalId:${task.id}',
            severity: SIV2ConflictSeverity.warning,
            summary:
                'Task "${task.title}" references a goal outside the current evidence lens.',
            evidenceIds: <String>[
              if (linkById.containsKey(taskEvidence)) taskEvidence,
            ],
          ),
        );
        continue;
      }
      final DateTime? taskDate = task.dueDate ?? task.scheduledFor;
      if (taskDate != null &&
          goal.targetDate != null &&
          taskDate.toUtc().isAfter(goal.targetDate!.toUtc())) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'task-after-goal:${task.id}:$goalId',
            severity: SIV2ConflictSeverity.critical,
            summary:
                'Task "${task.title}" is scheduled after goal "${goal.title}" ends.',
            evidenceIds: <String>[
              if (linkById.containsKey(taskEvidence)) taskEvidence,
              if (linkById.containsKey('goals:$goalId')) 'goals:$goalId',
            ],
          ),
        );
      }
    }
    for (final SIV2MilestoneEvidence milestone in milestones) {
      final String evidence = 'milestones:${milestone.id}';
      final List<String> missingDependencies = milestone.dependencies
          .where((String id) => !milestoneIds.contains(id))
          .toList(growable: false);
      if (missingDependencies.isNotEmpty) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'missing-milestone-dependency:${milestone.id}',
            severity: SIV2ConflictSeverity.warning,
            summary:
                'Milestone "${milestone.title}" has ${missingDependencies.length} dependency reference${missingDependencies.length == 1 ? '' : 's'} outside the lens.',
            evidenceIds: <String>[if (linkById.containsKey(evidence)) evidence],
          ),
        );
      }
      final SIV2GoalEvidence? goal = milestone.goalId == null
          ? null
          : goalsById[milestone.goalId!];
      if (goal?.targetDate != null &&
          milestone.targetDate != null &&
          milestone.targetDate!.toUtc().isAfter(goal!.targetDate!.toUtc())) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'milestone-after-goal:${milestone.id}:${goal.id}',
            severity: SIV2ConflictSeverity.critical,
            summary:
                'Milestone "${milestone.title}" ends after goal "${goal.title}".',
            evidenceIds: <String>[
              if (linkById.containsKey(evidence)) evidence,
              if (linkById.containsKey('goals:${goal.id}')) 'goals:${goal.id}',
            ],
          ),
        );
      }
    }
    return conflicts;
  }

  List<SIV2Scenario> _buildScenarios({
    required SIV2TaskEvidence? task,
    required List<SIV2GoalEvidence> goals,
    required DateTime now,
    required List<String> userAssumptions,
    required Map<String, SIV2EvidenceLink> linkById,
  }) {
    if (task == null) return const <SIV2Scenario>[];
    final String evidenceId = 'tasks:${task.id}';
    final List<String> citations = <String>[
      if (linkById.containsKey(evidenceId)) evidenceId,
    ];
    final DateTime? recordedDate = task.dueDate ?? task.scheduledFor;
    final DateTime deferredDate = (recordedDate ?? now).add(
      const Duration(days: 1),
    );
    final SIV2GoalEvidence? linkedGoal = task.goalId == null
        ? null
        : goals
              .where((SIV2GoalEvidence item) => item.id == task.goalId)
              .firstOrNull;
    final bool crossesGoalDate =
        linkedGoal?.targetDate != null &&
        deferredDate.toUtc().isAfter(linkedGoal!.targetDate!.toUtc());
    return <SIV2Scenario>[
      SIV2Scenario(
        kind: SIV2ScenarioKind.doNow,
        label: 'Do now',
        projectedEffect:
            'Scenario: acting on "${task.title}" now avoids adding a one-day schedule delay.',
        assumptions: <String>[
          'The task can be started with current capacity.',
          ...userAssumptions,
        ],
        evidenceIds: citations,
      ),
      SIV2Scenario(
        kind: SIV2ScenarioKind.deferOneDay,
        label: 'Defer one day',
        projectedEffect: crossesGoalDate
            ? 'Scenario: a one-day deferral crosses the linked goal target date and increases recorded schedule conflict.'
            : 'Scenario: a one-day deferral shifts the next recorded task date without crossing a visible goal target.',
        assumptions: <String>[
          'The task date moves by exactly 24 hours.',
          ...userAssumptions,
        ],
        evidenceIds: <String>[
          ...citations,
          if (linkedGoal != null &&
              linkById.containsKey('goals:${linkedGoal.id}'))
            'goals:${linkedGoal.id}',
        ],
      ),
      SIV2Scenario(
        kind: SIV2ScenarioKind.skip,
        label: 'Skip',
        projectedEffect: task.priority >= 4
            ? 'Scenario: skipping removes this task from today while leaving a high-priority commitment unresolved.'
            : 'Scenario: skipping removes this task from today while leaving its recorded commitment unresolved.',
        assumptions: <String>[
          'No replacement task satisfies the same commitment.',
          ...userAssumptions,
        ],
        evidenceIds: citations,
      ),
    ];
  }

  String _directAnswer({
    required SIV2Query query,
    required SIV2TaskEvidence? focusTask,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2Conflict> conflicts,
    required List<SIV2Scenario> scenarios,
    required int totalMatched,
  }) => switch (query.intent) {
    SIV2Intent.answer =>
      focusTask == null
          ? '$totalMatched evidence item${totalMatched == 1 ? '' : 's'} matched, but none supports a task-level next action.'
          : 'The strongest recorded next-task candidate is "${focusTask.title}".',
    SIV2Intent.explain =>
      conflicts.isEmpty
          ? 'No recorded conflict explains the current state; ranking is driven by due date and priority.'
          : 'The current evidence contains ${conflicts.length} explicit conflict${conflicts.length == 1 ? '' : 's'} that explain the risk signal.',
    SIV2Intent.compare =>
      goals.length < 2
          ? 'A grounded comparison needs at least two matched goals; ${goals.length} is available.'
          : 'Between the first two matched goals, "${_earliestGoal(goals).title}" has the earlier recorded target date.',
    SIV2Intent.forecast =>
      scenarios.isEmpty
          ? 'No task is available for do, defer, and skip scenarios.'
          : 'Three bounded scenarios were calculated for "${focusTask!.title}"; they are conditional, not predictions.',
    SIV2Intent.findConflict =>
      conflicts.isEmpty
          ? 'No explicit schedule, link, or dependency conflict was found in the current lens.'
          : '${conflicts.length} explicit conflict${conflicts.length == 1 ? '' : 's'} require attention.',
    SIV2Intent.counterfactual =>
      focusTask == null
          ? 'A recommendation would change if the lens exposed a dated or prioritized active task.'
          : 'The recommendation would change if another matched task gained an earlier due date, a higher priority, or a blocking dependency.',
  };

  SIV2TaskEvidence? _selectFocusTask(List<SIV2TaskEvidence> tasks) {
    if (tasks.isEmpty) return null;
    final List<SIV2TaskEvidence> ranked = List<SIV2TaskEvidence>.of(tasks)
      ..sort((SIV2TaskEvidence left, SIV2TaskEvidence right) {
        final DateTime leftDate =
            left.dueDate ??
            left.scheduledFor ??
            DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true);
        final DateTime rightDate =
            right.dueDate ??
            right.scheduledFor ??
            DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true);
        final int dateOrder = leftDate.compareTo(rightDate);
        if (dateOrder != 0) return dateOrder;
        final int priorityOrder = right.priority.compareTo(left.priority);
        if (priorityOrder != 0) return priorityOrder;
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    return ranked.first;
  }

  SIV2GoalEvidence _earliestGoal(List<SIV2GoalEvidence> goals) {
    final List<SIV2GoalEvidence> ranked = List<SIV2GoalEvidence>.of(goals)
      ..sort((SIV2GoalEvidence left, SIV2GoalEvidence right) {
        final DateTime leftDate =
            left.targetDate ??
            DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true);
        final DateTime rightDate =
            right.targetDate ??
            DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true);
        return leftDate.compareTo(rightDate);
      });
    return ranked.first;
  }

  bool _withinTaskRange(
    SIV2TaskEvidence task,
    SIV2TimeRange range,
    DateTime now,
  ) {
    if (range == SIV2TimeRange.all) return true;
    final DateTime? date = task.dueDate ?? task.scheduledFor;
    if (date == null || date.toUtc().isBefore(now)) return true;
    return _withinRange(date, range, now, undatedMatches: true);
  }

  bool _withinDeadlineRange(
    DateTime? date,
    SIV2TimeRange range,
    DateTime now, {
    required bool undatedMatches,
  }) {
    if (date != null && date.toUtc().isBefore(now)) {
      return true;
    }
    return _withinRange(date, range, now, undatedMatches: undatedMatches);
  }

  bool _withinTimelineRange(
    SIV2TimelineEvidence event,
    SIV2TimeRange range,
    DateTime now,
  ) {
    if (range == SIV2TimeRange.all) return true;
    final DateTime date = event.dueAt ?? event.timestamp;
    final Duration pastAge = now.difference(date.toUtc());
    if (!pastAge.isNegative) {
      final int days = switch (range) {
        SIV2TimeRange.today => 1,
        SIV2TimeRange.sevenDays => 7,
        SIV2TimeRange.thirtyDays => 30,
        SIV2TimeRange.all => 365000,
      };
      return pastAge <= Duration(days: days);
    }
    return _withinRange(date, range, now, undatedMatches: false);
  }

  bool _withinRange(
    DateTime? date,
    SIV2TimeRange range,
    DateTime now, {
    required bool undatedMatches,
  }) {
    if (range == SIV2TimeRange.all) return true;
    if (date == null) return undatedMatches;
    final DateTime start = DateTime.utc(now.year, now.month, now.day);
    final int days = switch (range) {
      SIV2TimeRange.today => 1,
      SIV2TimeRange.sevenDays => 7,
      SIV2TimeRange.thirtyDays => 30,
      SIV2TimeRange.all => 365000,
    };
    final DateTime end = start.add(Duration(days: days));
    final DateTime utc = date.toUtc();
    return !utc.isBefore(start) && utc.isBefore(end);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
