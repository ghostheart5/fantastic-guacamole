import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/si_v2_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  test(
    'returns proof-carrying analysis with scenarios and confidence anatomy',
    () {
      final SIV2Response response = const SIV2Engine().analyze(
        query: SIV2Query(
          rawText: 'What happens if I defer the launch task?',
          intent: SIV2Intent.forecast,
          sources: SIV2Source.values.toSet(),
          timeRange: SIV2TimeRange.thirtyDays,
          assumptions: const <String>['Only one work block is available.'],
        ),
        snapshot: _snapshot(now),
        now: now,
      );

      expect(response.directAnswer, contains('Three bounded scenarios'));
      expect(response.observedFacts, hasLength(4));
      expect(response.calculations, isNotEmpty);
      expect(response.inferences, isNotEmpty);
      expect(response.scenarios.map((SIV2Scenario item) => item.kind), {
        SIV2ScenarioKind.doNow,
        SIV2ScenarioKind.deferOneDay,
        SIV2ScenarioKind.skip,
      });
      expect(
        response.conflicts.map((SIV2Conflict item) => item.conflictId),
        containsAll(<String>[
          'overdue-task:t1',
          'task-after-goal:t1:g1',
          'milestone-after-goal:m1:g1',
        ]),
      );
      expect(response.confidence.coveredSignals, 4);
      expect(response.confidence.requiredSignals, 4);
      expect(response.confidence.freshness, SIV2Freshness.current);
      expect(response.evidenceLinks, isNotEmpty);
      expect(
        response.conflicts.every(
          (SIV2Conflict item) => item.evidenceIds.isNotEmpty,
        ),
        isTrue,
      );
      expect(
        response.scenarios.every(
          (SIV2Scenario item) => item.evidenceIds.isNotEmpty,
        ),
        isTrue,
      );
      expect(response.toPlainText(), contains('SCENARIOS'));
      expect(
        response.toPlainText(),
        isNot(contains(RegExp(r'\d+% confident'))),
      );
      response.validate();
    },
  );

  test('explicit query-builder intent wins over free-text detection', () {
    final SIV2Query query = SIV2Query.fromUserInput(
      rawText: 'What happens if I defer this?',
      selectedIntent: SIV2Intent.counterfactual,
      selectedSources: SIV2Source.values.toSet(),
      timeRange: SIV2TimeRange.all,
    );

    expect(query.intent, SIV2Intent.counterfactual);
  });

  test(
    'free text detects intent and shortcut source without losing arguments',
    () {
      final SIV2Query query = SIV2Query.fromUserInput(
        rawText: '/tasks explain THIS exact task',
        selectedIntent: SIV2Intent.answer,
        selectedSources: SIV2Source.values.toSet(),
        timeRange: SIV2TimeRange.all,
      );

      expect(query.rawText, '/tasks explain THIS exact task');
      expect(query.intent, SIV2Intent.explain);
      expect(query.sources, <SIV2Source>{SIV2Source.tasks});
    },
  );

  test('unavailable source is explicit and lowers coverage', () {
    final SIV2EvidenceSnapshot base = _snapshot(now);
    final SIV2Response response = const SIV2Engine().analyze(
      query: SIV2Query(
        rawText: 'Compare goals and milestones',
        intent: SIV2Intent.compare,
        sources: const <SIV2Source>{SIV2Source.goals, SIV2Source.milestones},
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: SIV2EvidenceSnapshot(
        accountScopeId: base.accountScopeId,
        observedAt: base.observedAt,
        tasks: base.tasks,
        goals: base.goals,
        milestones: const <SIV2MilestoneEvidence>[],
        timeline: base.timeline,
        unavailableSources: const <SIV2Source>{SIV2Source.milestones},
      ),
      now: now,
    );

    expect(response.confidence.coveredSignals, 1);
    expect(response.confidence.requiredSignals, 2);
    expect(
      response.missingInformation,
      contains('Milestones evidence is unavailable.'),
    );
  });

  test('entity filters remain bounded to titles', () {
    final SIV2Response response = const SIV2Engine().analyze(
      query: SIV2Query(
        rawText: 'What would change?',
        intent: SIV2Intent.counterfactual,
        sources: const <SIV2Source>{SIV2Source.tasks},
        timeRange: SIV2TimeRange.all,
        entityFilter: 'not present',
      ),
      snapshot: _snapshot(now),
      now: now,
    );

    expect(response.directAnswer, contains('lens exposed'));
    expect(
      response.missingInformation,
      contains('No entity title matched "not present".'),
    );
    expect(response.scenarios, isEmpty);
  });

  test('normal-language task wording changes the grounded answer', () {
    final SIV2Response background = const SIV2Engine().analyze(
      query: SIV2Query.fromUserInput(
        rawText: 'What should I do about the background task?',
        selectedIntent: SIV2Intent.answer,
        selectedSources: SIV2Source.values.toSet(),
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: _snapshot(now),
      now: now,
    );
    final SIV2Response launch = const SIV2Engine().analyze(
      query: SIV2Query.fromUserInput(
        rawText: 'What should I do about the launch task?',
        selectedIntent: SIV2Intent.answer,
        selectedSources: SIV2Source.values.toSet(),
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: _snapshot(now),
      now: now,
    );

    expect(background.directAnswer, contains('Background task'));
    expect(background.recommendation, contains('Background task'));
    expect(launch.directAnswer, contains('Launch task'));
    expect(background.directAnswer, isNot(launch.directAnswer));
    expect(background.recommendation, isNot(launch.recommendation));
  });

  test('a named goal never borrows an unrelated task recommendation', () {
    final SIV2Response response = const SIV2Engine().analyze(
      query: SIV2Query.fromUserInput(
        rawText: 'What should I do for the Prepare follow-up goal?',
        selectedIntent: SIV2Intent.answer,
        selectedSources: SIV2Source.values.toSet(),
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: _snapshot(now),
      now: now,
    );

    expect(response.directAnswer, contains('Prepare follow-up'));
    expect(response.directAnswer, isNot(contains('Launch task')));
    expect(response.recommendation, contains('Prepare follow-up'));
  });

  test('different planning questions produce materially different answers', () {
    SIV2Response ask(String text) => const SIV2Engine().analyze(
      query: SIV2Query.fromUserInput(
        rawText: text,
        selectedIntent: SIV2Intent.answer,
        selectedSources: SIV2Source.values.toSet(),
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: _snapshot(now),
      now: now,
    );

    final SIV2Response workload = ask('How overloaded is my workload?');
    final SIV2Response progress = ask(
      'Am I making progress on the Ship release goal?',
    );
    final SIV2Response timeline = ask(
      'What happened at the release checkpoint?',
    );
    final SIV2Response unsupported = ask('What is the weather outside?');

    expect(workload.directAnswer, contains('2 active tasks'));
    expect(progress.directAnswer, contains('50% average'));
    expect(timeline.directAnswer, contains('Release checkpoint'));
    expect(timeline.directAnswer, contains('status "active"'));
    expect(unsupported.directAnswer, contains('cannot answer that question'));
    expect(<String>{
      workload.directAnswer,
      progress.directAnswer,
      timeline.directAnswer,
      unsupported.directAnswer,
    }, hasLength(4));
  });

  test('a short follow-up resolves against recent user wording', () {
    final SIV2Query query = SIV2Query.fromUserInput(
      rawText: 'Why?',
      selectedIntent: SIV2Intent.answer,
      selectedSources: SIV2Source.values.toSet(),
      timeRange: SIV2TimeRange.all,
      priorUserTurns: const <String>['Should I focus on the Background task?'],
    );
    final SIV2Response response = const SIV2Engine().analyze(
      query: query,
      snapshot: _snapshot(now),
      now: now,
    );

    expect(response.directAnswer, contains('Background task'));
    expect(query.conversationText, contains('Should I focus'));
    expect(() => query.priorUserTurns.add('mutate'), throwsUnsupportedError);
  });

  test('snapshot revision covers fields that can change analysis', () {
    final SIV2EvidenceSnapshot base = _snapshot(now);
    final SIV2EvidenceSnapshot changedTaskLink = _snapshot(
      now,
      taskGoalId: 'g2',
    );
    final SIV2EvidenceSnapshot changedDependency = _snapshot(
      now,
      milestoneDependencies: const <String>[],
    );
    final SIV2EvidenceSnapshot changedObservation = SIV2EvidenceSnapshot(
      accountScopeId: base.accountScopeId,
      observedAt: now.add(const Duration(minutes: 1)),
      tasks: base.tasks,
      goals: base.goals,
      milestones: base.milestones,
      timeline: base.timeline,
    );

    expect(changedTaskLink.revision, isNot(base.revision));
    expect(changedDependency.revision, isNot(base.revision));
    expect(changedObservation.revision, isNot(base.revision));
  });

  test('confidence freshness is unavailable when every source read failed', () {
    final SIV2Response response = const SIV2Engine().analyze(
      query: SIV2Query(
        rawText: 'What needs attention?',
        intent: SIV2Intent.answer,
        sources: const <SIV2Source>{SIV2Source.tasks},
        timeRange: SIV2TimeRange.all,
      ),
      snapshot: SIV2EvidenceSnapshot(
        accountScopeId: 'account:test',
        observedAt: now,
        tasks: const <SIV2TaskEvidence>[],
        goals: const <SIV2GoalEvidence>[],
        milestones: const <SIV2MilestoneEvidence>[],
        timeline: const <SIV2TimelineEvidence>[],
        unavailableSources: const <SIV2Source>{SIV2Source.tasks},
      ),
      now: now,
    );

    expect(response.confidence.freshness, SIV2Freshness.unavailable);
  });

  test('nested evidence and response lists are immutable', () {
    final List<String> dependencies = <String>['m0'];
    final SIV2MilestoneEvidence milestone = SIV2MilestoneEvidence(
      id: 'm1',
      title: 'Checkpoint',
      createdAt: now,
      updatedAt: now,
      completionPercent: 0,
      completed: false,
      archived: false,
      dependencies: dependencies,
    );
    dependencies.add('m2');

    expect(milestone.dependencies, <String>['m0']);
    expect(() => milestone.dependencies.add('m3'), throwsUnsupportedError);
  });

  test('evidence snapshot rejects duplicate entity identities', () {
    expect(
      () => SIV2EvidenceSnapshot(
        accountScopeId: 'account:test',
        observedAt: now,
        tasks: <SIV2TaskEvidence>[
          SIV2TaskEvidence(
            id: 'duplicate',
            title: 'First',
            createdAt: now,
            priority: 1,
          ),
          SIV2TaskEvidence(
            id: 'duplicate',
            title: 'Second',
            createdAt: now,
            priority: 2,
          ),
        ],
        goals: const <SIV2GoalEvidence>[],
        milestones: const <SIV2MilestoneEvidence>[],
        timeline: const <SIV2TimelineEvidence>[],
      ),
      throwsArgumentError,
    );
  });
}

SIV2EvidenceSnapshot _snapshot(
  DateTime now, {
  String taskGoalId = 'g1',
  List<String> milestoneDependencies = const <String>['missing'],
}) => SIV2EvidenceSnapshot(
  accountScopeId: 'account:test',
  observedAt: now,
  tasks: <SIV2TaskEvidence>[
    SIV2TaskEvidence(
      id: 't1',
      title: 'Launch task',
      createdAt: now.subtract(const Duration(days: 4)),
      priority: 5,
      dueDate: now.subtract(const Duration(days: 1)),
      goalId: taskGoalId,
    ),
    SIV2TaskEvidence(
      id: 't2',
      title: 'Background task',
      createdAt: now.subtract(const Duration(days: 2)),
      priority: 2,
    ),
  ],
  goals: <SIV2GoalEvidence>[
    SIV2GoalEvidence(
      id: 'g1',
      title: 'Ship release',
      createdAt: now.subtract(const Duration(days: 10)),
      targetDate: now.subtract(const Duration(days: 2)),
    ),
    SIV2GoalEvidence(
      id: 'g2',
      title: 'Prepare follow-up',
      createdAt: now.subtract(const Duration(days: 5)),
      targetDate: now.add(const Duration(days: 10)),
    ),
  ],
  milestones: <SIV2MilestoneEvidence>[
    SIV2MilestoneEvidence(
      id: 'm1',
      title: 'Release candidate',
      createdAt: now.subtract(const Duration(days: 6)),
      updatedAt: now,
      completionPercent: 50,
      completed: false,
      archived: false,
      goalId: 'g1',
      targetDate: now.add(const Duration(days: 1)),
      dependencies: milestoneDependencies,
    ),
  ],
  timeline: <SIV2TimelineEvidence>[
    SIV2TimelineEvidence(
      id: 'e1',
      title: 'Release checkpoint',
      timestamp: now.subtract(const Duration(hours: 2)),
      type: 'milestone',
      status: 'active',
      relatedId: 'm1',
    ),
  ],
);
