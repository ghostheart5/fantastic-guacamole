import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'task revision changes when priority changes without a count change',
    () {
      final SIStateAggregation before = _aggregation(<Task>[
        _task('task-a', priority: 2),
      ]);
      final SIStateAggregation after = _aggregation(<Task>[
        _task('task-a', priority: 5),
      ]);

      expect(before.tasks.length, after.tasks.length);
      expect(
        operatingSourceRevisions(before)['tasks'],
        isNot(operatingSourceRevisions(after)['tasks']),
      );
    },
  );

  test('task revision is stable when repository order changes', () {
    final SIStateAggregation first = _aggregation(<Task>[
      _task('task-a', priority: 2),
      _task('task-b', priority: 4),
    ]);
    final SIStateAggregation reordered = _aggregation(<Task>[
      _task('task-b', priority: 4),
      _task('task-a', priority: 2),
    ]);

    expect(
      operatingSourceRevisions(first)['tasks'],
      operatingSourceRevisions(reordered)['tasks'],
    );
  });

  test(
    'receipt action and subject come from the same canonical decision',
    () async {
      final SIStateAggregation aggregation = _aggregation(<Task>[
        _task('priority-task', priority: 5),
        _task('feasible-task', priority: 3),
      ]);
      final String selectedTitle =
          aggregation.planningDecision.selectedTask!.title;
      final String otherTitle = aggregation.tasks
          .firstWhere((Task task) => task.title != selectedTitle)
          .title;
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('test-account'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          siStateAggregationProvider.overrideWith(
            (Ref ref) async => aggregation,
          ),
          siDecisionOutputProvider.overrideWith(
            (Ref ref) async => SIDecisionOutput(
              nextAction: 'Work on: $otherTitle',
              plannerMessage: 'Intentionally mismatched supporting copy.',
              suggestedPlanAdjustments: const <String>[],
              signalPrompts: const <String>[],
              progressionFeedback: '',
              warnings: const <String>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final receipt = await container.read(
        operatingDecisionReceiptProvider.future,
      );

      expect(receipt.subjectId, aggregation.planningDecision.selectedTask!.id);
      expect(receipt.recommendedAction, contains(selectedTitle));
      expect(receipt.recommendedAction, isNot(contains(otherTitle)));
      expect(receipt.actionIntent.targetEntityId, receipt.subjectId);
      expect(receipt.sourceRevisions['person_context_nexus'], 'unavailable');
    },
  );

  test(
    'all six consuming surfaces receive the same decision receipt',
    () async {
      final SIStateAggregation aggregation = _aggregation(<Task>[
        _task('shared-task', priority: 5),
      ]);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('test-account'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          siStateAggregationProvider.overrideWith(
            (Ref ref) async => aggregation,
          ),
          siDecisionOutputProvider.overrideWith(
            (Ref ref) async => _supportingOutput,
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<SurfaceDecisionReceipt> receipts = await Future.wait(
        OperatingDecisionSurface.values.map(
          (OperatingDecisionSurface surface) => container.read(
            operatingDecisionForSurfaceProvider(surface).future,
          ),
        ),
      );
      final OperatingDecisionPlan plan = await container.read(
        operatingDecisionPlanProvider.future,
      );

      expect(receipts, hasLength(6));
      expect(
        receipts.map(
          (SurfaceDecisionReceipt value) => value.receipt.decisionId,
        ),
        everyElement(receipts.first.receipt.decisionId),
      );
      expect(
        receipts.map((SurfaceDecisionReceipt value) => value.receipt.planId),
        everyElement(receipts.first.receipt.planId),
      );
      expect(receipts.first.receipt.planId, plan.planId);
      expect(receipts.first.receipt.snapshotId, plan.snapshotId);
      expect(
        receipts.map(
          (SurfaceDecisionReceipt value) => value.receipt.snapshotId,
        ),
        everyElement(receipts.first.receipt.snapshotId),
      );
    },
  );

  test('Nexus binds fresh consented decision context into its receipt', () async {
    final DateTime now = DateTime.now().toUtc();
    final List<Task> tasks = <Task>[
      _task('priority-task', priority: 5, title: 'Prepare release evidence'),
    ];
    final PersonContextView view = _personContextView(
      now: now,
      surface: PersonContextSurface.nexus,
      signals: <PersonContextSignal>[
        _personContextSignal(
          id: 'protected-time',
          value: 'Make release evidence the current priority',
          now: now,
          surface: PersonContextSurface.nexus,
          surfaceScopes: sharedDecisionContextSurfaces,
        ),
      ],
    );
    final GovernedDecisionContext personContext =
        GovernedDecisionContext.resolve(
          view: view,
          accountScopeId: view.accountScopeId,
          tasks: tasks,
          now: now,
        );
    final SIStateAggregation aggregation = _aggregation(
      tasks,
      personContext: personContext,
      now: now,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('test-account'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        siStateAggregationProvider.overrideWith((Ref ref) async => aggregation),
        siDecisionOutputProvider.overrideWith(
          (Ref ref) async => _supportingOutput,
        ),
      ],
    );
    addTearDown(container.dispose);

    final OperatingDecisionReceipt receipt = await container.read(
      operatingDecisionReceiptProvider.future,
    );
    final OperatingEvidence contextEvidence = receipt.evidence.singleWhere(
      (OperatingEvidence item) => item.source == 'person_context_policy',
    );

    expect(nexusPersonContextRequest.surface, PersonContextSurface.nexus);
    expect(nexusPersonContextRequest.purposes, nexusPersonContextPurposes);
    expect(contextEvidence.kind, OperatingEvidenceKind.derived);
    expect(contextEvidence.description, contains('Prepare release evidence'));
    expect(
      receipt.sourceRevisions['person_context_nexus'],
      isNot(anyOf('unavailable', 'available_empty')),
    );
    expect(
      receipt.assumptions,
      contains(
        contains(
          'not interpreted as identity, diagnosis, intent, relationship quality, or a guaranteed outcome',
        ),
      ),
    );
    expect(receipt.personContextAppliedSignalIds, <String>['protected-time']);
    expect(receipt.personContextTrace, isNotNull);
  });

  test(
    'Nexus keeps valid empty distinct and excludes stale or wrong-purpose context',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final List<Task> tasks = <Task>[_task('priority-task', priority: 5)];
      final PersonContextView view = _personContextView(
        now: now,
        surface: PersonContextSurface.nexus,
        signals: <PersonContextSignal>[
          _personContextSignal(
            id: 'stale-priority',
            value: 'Stale private priority',
            now: now,
            surface: PersonContextSurface.nexus,
            freshUntil: now.subtract(const Duration(minutes: 1)),
          ),
          _personContextSignal(
            id: 'outcome-only',
            value: 'Outcome-only private context',
            now: now,
            surface: PersonContextSurface.nexus,
            purpose: PersonContextPurpose.outcomeLearning,
          ),
        ],
      );
      final GovernedDecisionContext personContext =
          GovernedDecisionContext.resolve(
            view: view,
            accountScopeId: view.accountScopeId,
            tasks: tasks,
            now: now,
          );
      final SIStateAggregation aggregation = _aggregation(
        tasks,
        personContext: personContext,
        now: now,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('test-account'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          siStateAggregationProvider.overrideWith(
            (Ref ref) async => aggregation,
          ),
          siDecisionOutputProvider.overrideWith(
            (Ref ref) async => _supportingOutput,
          ),
        ],
      );
      addTearDown(container.dispose);

      final OperatingDecisionReceipt receipt = await container.read(
        operatingDecisionReceiptProvider.future,
      );

      expect(
        receipt.sourceRevisions['person_context_nexus'],
        isNot('unavailable'),
      );
      expect(
        receipt.evidence.any(
          (OperatingEvidence item) =>
              item.code == 'person_context_available_empty',
        ),
        isTrue,
      );
      expect(
        receipt.evidence.any(
          (OperatingEvidence item) =>
              item.description.contains('Stale private priority') ||
              item.description.contains('Planning-only private context'),
        ),
        isFalse,
      );
    },
  );
}

const SIDecisionOutput _supportingOutput = SIDecisionOutput(
  nextAction: '',
  plannerMessage: '',
  suggestedPlanAdjustments: <String>[],
  signalPrompts: <String>[],
  progressionFeedback: '',
  warnings: <String>[],
);

PersonContextView _personContextView({
  required DateTime now,
  required PersonContextSurface surface,
  required List<PersonContextSignal> signals,
}) => PersonContextView(
  accountScopeId: AccountStorageScope.authenticated(
    'test-account',
  ).v2Namespace!,
  surface: surface,
  purposes: nexusPersonContextPurposes,
  observedAt: now,
  signals: signals,
  unknownKinds: const <PersonContextKind>{},
);

PersonContextSignal _personContextSignal({
  required String id,
  required String value,
  required DateTime now,
  required PersonContextSurface surface,
  PersonContextPurpose purpose = PersonContextPurpose.decisionSupport,
  DateTime? freshUntil,
  Set<PersonContextSurface>? surfaceScopes,
}) => PersonContextSignal(
  id: id,
  kind: PersonContextKind.currentPriority,
  value: value,
  source: PersonContextSource.userAuthored,
  consent: PersonContextConsent.granted,
  consentedAt: now.subtract(const Duration(minutes: 5)),
  purpose: purpose,
  surfaceScopes: surfaceScopes ?? <PersonContextSurface>{surface},
  recordedAt: now.subtract(const Duration(minutes: 5)),
  freshUntil: freshUntil ?? now.add(const Duration(hours: 2)),
  expiresAt: now.add(const Duration(days: 1)),
  exportBehavior: PersonContextExportBehavior.include,
  deletionBehavior: PersonContextDeletionBehavior.userRemovable,
);

Task _task(String id, {required int priority, String? title}) => Task(
  id: id,
  title: title ?? 'Task $id',
  priority: priority,
  difficulty: 3,
  energyRequired: 3,
  dueDate: DateTime.utc(2026, 8, 20),
  estimatedDuration: const Duration(minutes: 30),
);

SIStateAggregation _aggregation(
  List<Task> tasks, {
  GovernedDecisionContext? personContext,
  DateTime? now,
}) => SIStateAggregation(
  tasks: tasks,
  goals: const [],
  signals: const SignalsBundle(
    items: <Signal>[],
    summary: 'Stable',
    healthScore: .7,
  ),
  planningEvidence: const SIPlanningEvidence(
    friction: false,
    overwhelm: false,
    streakHealth: 'steady',
    goalDrift: false,
    taskAvoidance: false,
    emotion: 'neutral',
    emotionalStrain: false,
    emotionalStability: true,
    emotionalPatterns: <String>[],
  ),
  logs: const [],
  timeline: const [],
  memories: const [],
  notifications: const [],
  planPreview: const [],
  profile: ProfileState(),
  siState: const SIState(energy: .7, fatigue: .2),
  trajectory: _trajectory,
  planningDecision: const DecisionEngine().recommend(
    tasks: tasks,
    state: SiStateEntity(energy: .7, attention: .8, fatigue: .2),
    learning: LearningEntity(),
    personContext: personContext,
    now: now ?? DateTime.utc(2026, 8, 19, 12),
  ),
);

const TrajectorySummaryView _trajectory = TrajectorySummaryView(
  pendingTasks: 1,
  completedTasks: 0,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: .7,
  momentum: .5,
  adaptability: .5,
  lastCompletionXp: 0,
  lastCompletionQuality: 0,
  pressureIndex: 20,
  behaviorDivergence: 0,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
