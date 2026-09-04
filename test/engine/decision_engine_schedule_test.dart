import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/ranked_task.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves an explicit future schedule without repacking it', () {
    final DateTime now = DateTime(2026, 8, 20, 18);
    final DateTime scheduled = DateTime(2026, 8, 27, 18, 27);
    final TaskEntity task = TaskEntity(
      id: 'scheduled-task',
      title: 'Scheduled task',
      createdAt: now,
      scheduledFor: scheduled,
      estimatedDuration: const Duration(minutes: 45),
    );

    final DecisionRecommendation result = const DecisionEngine().recommend(
      tasks: <TaskEntity>[task],
      state: SiStateEntity(energy: .7, attention: .7, fatigue: .2),
      learning: LearningEntity(),
      now: now,
    );

    expect(result.plan.blocks, hasLength(1));
    expect(result.plan.blocks.single.taskId, task.id);
    expect(result.plan.blocks.single.start, scheduled);
    expect(
      result.plan.blocks.single.end,
      scheduled.add(const Duration(minutes: 45)),
    );
  });

  test('terminal tasks never re-enter decision candidates or plan blocks', () {
    final DateTime now = DateTime(2026, 8, 20, 8);
    TaskEntity task(
      String id, {
      bool completed = false,
      bool skipped = false,
      bool canceled = false,
    }) => TaskEntity(
      id: id,
      title: id,
      createdAt: now,
      isCompleted: completed,
      completedAt: completed ? now : null,
      isSkipped: skipped,
      skippedAt: skipped ? now : null,
      isCanceled: canceled,
      estimatedDuration: const Duration(minutes: 30),
    );

    final DecisionRecommendation result = const DecisionEngine().recommend(
      tasks: <TaskEntity>[
        task('open'),
        task('completed', completed: true),
        task('skipped', skipped: true),
        task('canceled', canceled: true),
      ],
      state: SiStateEntity(energy: .7, attention: .7, fatigue: .2),
      learning: LearningEntity(),
      now: now,
    );

    expect(result.selectedTask?.id, 'open');
    expect(result.orderedTasks.map((TaskEntity item) => item.id), <String>[
      'open',
    ]);
    expect(result.plan.blocks.map((block) => block.taskId), <String>['open']);
  });

  test(
    'current-priority context changes the canonical choice only as a bounded tie-break',
    () {
      final DateTime now = DateTime.utc(2026, 9, 2, 8);
      final List<TaskEntity> tasks = <TaskEntity>[
        _decisionTask('a-expenses', 'File expenses', now: now),
        _decisionTask('b-release', 'Prepare release evidence', now: now),
      ];
      final DecisionRecommendation baseline = _recommend(tasks, now: now);
      final GovernedDecisionContext context = _decisionContext(
        tasks: tasks,
        now: now,
        signals: <PersonContextSignal>[
          _decisionSignal(
            id: 'priority-release',
            kind: PersonContextKind.currentPriority,
            value: 'Make release evidence the current priority',
            now: now,
          ),
        ],
      );
      final DecisionRecommendation changed = _recommend(
        tasks,
        now: now,
        personContext: context,
      );

      expect(baseline.selectedTask?.id, 'a-expenses');
      expect(changed.selectedTask?.id, 'b-release');
      expect(
        changed.rankedCandidates
                .firstWhere((RankedTask item) => item.task.id == 'b-release')
                .score -
            baseline.rankedCandidates
                .firstWhere((RankedTask item) => item.task.id == 'b-release')
                .score,
        closeTo(.25, .0001),
      );
      expect(context.trace?.appliedDeltas.single.changed, isTrue);
      expect(
        context.trace?.appliedDeltas.single.field,
        PersonContextBehaviorField.rankingPriority,
      );

      final List<TaskEntity> separated = <TaskEntity>[
        _decisionTask(
          'a-deadline',
          'Meet filing deadline',
          now: now,
          priority: 5,
        ),
        _decisionTask(
          'b-release',
          'Prepare release evidence',
          now: now,
          priority: 1,
        ),
      ];
      final DecisionRecommendation bounded = _recommend(
        separated,
        now: now,
        personContext: _decisionContext(
          tasks: separated,
          now: now,
          signals: <PersonContextSignal>[
            _decisionSignal(
              id: 'priority-release',
              kind: PersonContextKind.currentPriority,
              value: 'Make release evidence the current priority',
              now: now,
            ),
          ],
        ),
      );
      expect(bounded.selectedTask?.id, 'a-deadline');
    },
  );

  test(
    'boundary then commitment then capacity resolve in binder authority order',
    () {
      final DateTime now = DateTime.utc(2026, 9, 2, 8);
      final List<TaskEntity> tasks = <TaskEntity>[
        _decisionTask(
          'a-release',
          'Prepare release evidence',
          now: now,
          priority: 5,
          minutes: 60,
        ),
        _decisionTask(
          'b-email',
          'Send project email',
          now: now,
          priority: 3,
          minutes: 20,
        ),
      ];
      final PersonContextSignal capacity = _decisionSignal(
        id: 'capacity-25',
        kind: PersonContextKind.presentCapacity,
        value: 'Present capacity is 25 minutes',
        now: now,
      );
      final PersonContextSignal commitment = _decisionSignal(
        id: 'commit-release',
        kind: PersonContextKind.commitment,
        value: 'Scheduled commitment: prepare release evidence',
        now: now,
      );
      final PersonContextSignal boundary = _decisionSignal(
        id: 'boundary-release',
        kind: PersonContextKind.boundary,
        value: 'Do not prepare release evidence',
        now: now,
      );

      final DecisionRecommendation capacityOnly = _recommend(
        tasks,
        now: now,
        personContext: _decisionContext(
          tasks: tasks,
          now: now,
          signals: <PersonContextSignal>[capacity],
        ),
      );
      final DecisionRecommendation commitmentWins = _recommend(
        tasks,
        now: now,
        personContext: _decisionContext(
          tasks: tasks,
          now: now,
          signals: <PersonContextSignal>[capacity, commitment],
        ),
      );
      final DecisionRecommendation boundaryWins = _recommend(
        tasks,
        now: now,
        personContext: _decisionContext(
          tasks: tasks,
          now: now,
          signals: <PersonContextSignal>[capacity, commitment, boundary],
        ),
      );

      expect(capacityOnly.selectedTask?.id, 'b-email');
      expect(capacityOnly.executionMinutes, 20);
      expect(commitmentWins.selectedTask?.id, 'a-release');
      expect(commitmentWins.executionMinutes, 60);
      expect(boundaryWins.selectedTask?.id, 'b-email');
      expect(
        boundaryWins.personContext?.excludedTaskIds,
        contains('a-release'),
      );
      final GovernedDecisionContext resolved = boundaryWins.personContext!;
      expect(resolved.protectedCommitmentTaskIds, isEmpty);
      expect(resolved.appliedSignalIds, isNot(contains('commit-release')));
      expect(
        resolved.explanations.join(' '),
        isNot(contains('Scheduled commitment protected')),
      );
      final PersonContextBehaviorDecision rejectedCommitment = resolved
          .trace!
          .rejected
          .singleWhere(
            (PersonContextBehaviorDecision decision) =>
                decision.signalId == 'commit-release',
          );
      expect(
        rejectedCommitment.rejectionReason,
        PersonContextRejectionReason.supersededByHigherAuthority,
      );
      expect(
        resolved.trace!.appliedDeltas.map(
          (PersonContextBehaviorDelta delta) => delta.signalId,
        ),
        isNot(contains('commit-release')),
      );
    },
  );

  test(
    'irrelevant ignored stale and withdrawn context preserve full no-context behavior',
    () {
      final DateTime now = DateTime.utc(2026, 9, 2, 8);
      final List<TaskEntity> tasks = <TaskEntity>[
        _decisionTask('a-expenses', 'File expenses', now: now),
        _decisionTask('b-release', 'Prepare release evidence', now: now),
      ];
      final DecisionRecommendation baseline = _recommend(tasks, now: now);
      final PersonContextSignal unrelated = _decisionSignal(
        id: 'priority-garden',
        kind: PersonContextKind.currentPriority,
        value: 'Make watering the garden the current priority',
        now: now,
      );
      final PersonContextSignal relevant = _decisionSignal(
        id: 'priority-release',
        kind: PersonContextKind.currentPriority,
        value: 'Make release evidence the current priority',
        now: now,
      );
      final GovernedDecisionContext irrelevant = _decisionContext(
        tasks: tasks,
        now: now,
        signals: <PersonContextSignal>[unrelated],
      );
      final GovernedDecisionContext ignored = _decisionContext(
        tasks: tasks,
        now: now,
        signals: <PersonContextSignal>[relevant],
        ignoredSignalIds: const <String>{'priority-release'},
      );
      final GovernedDecisionContext stale = _decisionContext(
        tasks: tasks,
        now: now,
        signals: <PersonContextSignal>[
          _decisionSignal(
            id: 'priority-release',
            kind: PersonContextKind.currentPriority,
            value: 'Make release evidence the current priority',
            now: now,
            freshUntil: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      );
      final GovernedDecisionContext withdrawn = _decisionContext(
        tasks: tasks,
        now: now,
        signals: <PersonContextSignal>[
          _decisionSignal(
            id: 'priority-release',
            kind: PersonContextKind.currentPriority,
            value: 'Make release evidence the current priority',
            now: now,
            consent: PersonContextConsent.withdrawn,
          ),
        ],
      );

      final Map<String, GovernedDecisionContext> contexts =
          <String, GovernedDecisionContext>{
            'irrelevant': irrelevant,
            'ignored': ignored,
            'stale': stale,
            'withdrawn': withdrawn,
          };
      final Map<String, PersonContextRejectionReason> expectedReasons =
          <String, PersonContextRejectionReason>{
            'irrelevant': PersonContextRejectionReason.irrelevant,
            'ignored': PersonContextRejectionReason.userOverride,
            'stale': PersonContextRejectionReason.stale,
            'withdrawn': PersonContextRejectionReason.consentWithdrawn,
          };
      final String knownEmptyRevision = irrelevant.revision;

      for (final MapEntry<String, GovernedDecisionContext> entry
          in contexts.entries) {
        final GovernedDecisionContext context = entry.value;
        final DecisionRecommendation actual = _recommend(
          tasks,
          now: now,
          personContext: context,
        );
        expect(context.status, GovernedDecisionContextStatus.knownEmpty);
        expect(context.revision, knownEmptyRevision);
        expect(context.appliedSignalIds, isEmpty);
        expect(context.priorityTaskIds, isEmpty);
        expect(context.excludedTaskIds, isEmpty);
        expect(context.protectedCommitmentTaskIds, isEmpty);
        expect(context.capacityCapMinutes, isNull);
        expect(context.explanations, isEmpty);
        expect(context.trace!.appliedDeltas, isEmpty);
        expect(
          context.trace!.rejected.single.rejectionReason,
          expectedReasons[entry.key],
        );
        expect(_decisionBehavior(actual), _decisionBehavior(baseline));
      }
    },
  );
}

TaskEntity _decisionTask(
  String id,
  String title, {
  required DateTime now,
  int priority = 3,
  int minutes = 30,
}) => TaskEntity(
  id: id,
  title: title,
  createdAt: now,
  priority: priority,
  difficulty: 3,
  energyRequired: 3,
  estimatedDuration: Duration(minutes: minutes),
);

PersonContextSignal _decisionSignal({
  required String id,
  required PersonContextKind kind,
  required String value,
  required DateTime now,
  PersonContextConsent consent = PersonContextConsent.granted,
  DateTime? freshUntil,
}) {
  final PersonContextBehaviorRule rule = PersonContextBehaviorPolicy.ruleFor(
    kind,
  );
  return PersonContextSignal(
    id: id,
    kind: kind,
    value: value,
    source: PersonContextSource.userAuthored,
    consent: consent,
    consentedAt: now.subtract(const Duration(minutes: 5)),
    withdrawnAt: consent == PersonContextConsent.withdrawn
        ? now.subtract(const Duration(minutes: 1))
        : null,
    purpose: rule.purpose,
    surfaceScopes: const <PersonContextSurface>{PersonContextSurface.nexus},
    recordedAt: now.subtract(const Duration(minutes: 5)),
    freshUntil:
        freshUntil ??
        (kind == PersonContextKind.presentCapacity
            ? now.add(const Duration(hours: 2))
            : now.add(const Duration(days: 2))),
    expiresAt: now.add(const Duration(days: 3)),
    exportBehavior: PersonContextExportBehavior.include,
    deletionBehavior: PersonContextDeletionBehavior.userRemovable,
  );
}

GovernedDecisionContext _decisionContext({
  required List<TaskEntity> tasks,
  required DateTime now,
  required List<PersonContextSignal> signals,
  Set<String> ignoredSignalIds = const <String>{},
}) => GovernedDecisionContext.resolve(
  view: PersonContextView(
    accountScopeId: 'account-a',
    surface: PersonContextSurface.nexus,
    purposes: const <PersonContextPurpose>{
      ...operationalPersonContextPurposes,
      PersonContextPurpose.outcomeLearning,
    },
    observedAt: now,
    signals: signals,
    unknownKinds: const <PersonContextKind>{},
  ),
  accountScopeId: 'account-a',
  tasks: tasks,
  now: now,
  ignoredSignalIds: ignoredSignalIds,
);

DecisionRecommendation _recommend(
  List<TaskEntity> tasks, {
  required DateTime now,
  GovernedDecisionContext? personContext,
}) => const DecisionEngine().recommend(
  tasks: tasks,
  state: SiStateEntity(energy: .7, attention: .8, fatigue: .2),
  learning: LearningEntity(),
  personContext: personContext,
  now: now,
);

Map<String, Object?> _decisionBehavior(
  DecisionRecommendation value,
) => <String, Object?>{
  'selectedTaskId': value.selectedTask?.id,
  'orderedTaskIds': value.orderedTasks
      .map((TaskEntity task) => task.id)
      .toList(growable: false),
  'shouldTakeBreak': value.shouldTakeBreak,
  'executionMinutes': value.executionMinutes,
  'rationale': value.rationale,
  'evidence': value.evidence
      .map(
        (DecisionEvidence evidence) => <String, Object?>{
          'source': evidence.source,
          'detail': evidence.detail,
          'observedAt': evidence.observedAt.toUtc().toIso8601String(),
        },
      )
      .toList(growable: false),
  'confidence': <String, Object?>{
    'dataSufficiency': value.confidence.dataSufficiency,
    'recommendation': value.confidence.recommendation,
    'safety': value.confidence.safety,
  },
  'plan': <String, Object?>{
    'blocks': value.plan.blocks
        .map(
          (block) => <String, Object?>{
            'id': block.id,
            'taskId': block.taskId,
            'title': block.title,
            'description': block.description,
            'start': block.start.toUtc().toIso8601String(),
            'end': block.end.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false),
    'unscheduledTaskIds': value.plan.unscheduledTaskIds,
    'issues': value.plan.issues
        .map(
          (issue) => <String, Object?>{
            'type': issue.type.name,
            'taskId': issue.taskId,
            'message': issue.message,
          },
        )
        .toList(growable: false),
    'capacity': <String, Object?>{
      'availableMinutes': value.plan.capacity.availableMinutes,
      'occupiedMinutes': value.plan.capacity.occupiedMinutes,
      'requiredMinutes': value.plan.capacity.requiredMinutes,
      'unscheduledMinutes': value.plan.capacity.unscheduledMinutes,
      'overloadRatio': value.plan.capacity.overloadRatio,
      'windowOrigin': value.plan.capacity.windowOrigin.name,
      'blockOrigin': value.plan.capacity.blockOrigin.name,
      'assumptions': value.plan.capacity.assumptions,
    },
  },
  'rankedCandidates': value.rankedCandidates
      .map(
        (RankedTask candidate) => <String, Object?>{
          'taskId': candidate.task.id,
          'score': candidate.score,
          'breakdown': <String, Object?>{
            'taskId': candidate.breakdown.taskId,
            'priority': candidate.breakdown.priority,
            'deadlinePressure': <String, Object?>{
              'taskId': candidate.breakdown.deadlinePressure.taskId,
              'band': candidate.breakdown.deadlinePressure.band.name,
              'score': candidate.breakdown.deadlinePressure.score,
              'slackMinutes':
                  candidate.breakdown.deadlinePressure.slack?.inMinutes,
              'explanation': candidate.breakdown.deadlinePressure.explanation,
              'origin': candidate.breakdown.deadlinePressure.origin.name,
            },
            'energyFit': candidate.breakdown.energyFit,
            'fatigueAdjustment': candidate.breakdown.fatigueAdjustment,
            'difficultyAdjustment': candidate.breakdown.difficultyAdjustment,
            'learningAffinity': candidate.breakdown.learningAffinity,
            'total': candidate.breakdown.total,
            'reasons': candidate.breakdown.reasons,
          },
        },
      )
      .toList(growable: false),
  'recoveryRecommendations': value.recoveryRecommendations
      .map(
        (recommendation) => <String, Object?>{
          'trigger': recommendation.trigger.name,
          'subjectId': recommendation.subjectId,
          'immediateAction': recommendation.immediateAction,
          'why': recommendation.why,
          'consequence': recommendation.consequence,
          'confidence': recommendation.confidence.toJson(),
          'proposedStart': recommendation.proposedStart
              ?.toUtc()
              .toIso8601String(),
          'displacedSubjectIds': recommendation.displacedSubjectIds,
        },
      )
      .toList(growable: false),
  'confidenceProfile': value.confidenceProfile.toJson(),
  'modelVersion': value.modelVersion,
};
