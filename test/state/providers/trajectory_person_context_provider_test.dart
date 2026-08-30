import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Trajectory binds fresh decision context into baseline and outcomes',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final PersonContextView view = _view(now, <PersonContextSignal>[
        _signal(
          id: 'capacity-boundary',
          value: 'Keep the evening unscheduled',
          now: now,
        ),
      ]);
      final ProviderContainer container = _container(view);
      addTearDown(container.dispose);
      await container.read(siStateAggregationProvider.future);

      final comparison = container
          .read(trajectoryConsequenceProvider)
          .requireValue;
      final String? revision =
          comparison.baseline.sourceRevisions['person_context_trajectory'];

      expect(
        trajectoryPersonContextRequest.surface,
        PersonContextSurface.trajectory,
      );
      expect(
        trajectoryPersonContextRequest.purposes,
        operationalPersonContextPurposes,
      );
      expect(revision, isNot(anyOf('unavailable', 'available_empty')));
      expect(
        comparison.outcomes.every(
          (outcome) =>
              outcome.evidence.contains('person_context_trajectory=$revision'),
        ),
        isTrue,
      );
      expect(
        comparison.outcomes.every(
          (outcome) => outcome.assumptions.any(
            (String assumption) =>
                assumption.contains('Keep the evening unscheduled') &&
                assumption.contains('not treated as identity'),
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'Trajectory keeps valid empty distinct and excludes ineligible context',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final PersonContextView view = _view(now, <PersonContextSignal>[
        _signal(
          id: 'stale-boundary',
          value: 'Stale trajectory context',
          now: now,
          freshUntil: now.subtract(const Duration(minutes: 1)),
        ),
        _signal(
          id: 'outcome-only',
          value: 'Outcome-only trajectory context',
          now: now,
          purpose: PersonContextPurpose.outcomeLearning,
        ),
      ]);
      final ProviderContainer container = _container(view);
      addTearDown(container.dispose);
      await container.read(siStateAggregationProvider.future);

      final comparison = container
          .read(trajectoryConsequenceProvider)
          .requireValue;

      expect(
        comparison.baseline.sourceRevisions['person_context_trajectory'],
        'available_empty',
      );
      expect(
        comparison.outcomes.every(
          (outcome) => outcome.assumptions.contains(
            'Person context was available but contained no fresh consented Trajectory operational signals.',
          ),
        ),
        isTrue,
      );
      expect(
        comparison.outcomes.any(
          (outcome) => outcome.assumptions.any(
            (String assumption) =>
                assumption.contains('Stale trajectory context') ||
                assumption.contains('Outcome-only trajectory context'),
          ),
        ),
        isFalse,
      );
    },
  );

  test('Trajectory records unavailable context without inferring it', () async {
    final ProviderContainer container = _container(null);
    addTearDown(container.dispose);
    await container.read(siStateAggregationProvider.future);

    final comparison = container
        .read(trajectoryConsequenceProvider)
        .requireValue;

    expect(
      comparison.baseline.sourceRevisions['person_context_trajectory'],
      'unavailable',
    );
    expect(
      comparison.outcomes.every(
        (outcome) => outcome.assumptions.contains(
          'Person context was unavailable at scenario construction, so no personal context was inferred.',
        ),
      ),
      isTrue,
    );
  });
}

ProviderContainer _container(PersonContextView? view) => ProviderContainer(
  overrides: [
    accountStorageScopeProvider.overrideWithValue(
      const AccountStorageScope.signedOut(),
    ),
    siStateAggregationProvider.overrideWith((Ref ref) async => _aggregation),
    progressionProvider.overrideWithValue(ProgressionState.initial()),
    executionSignalsProvider.overrideWithValue(_execution),
    personContextForSurfaceProvider(
      trajectoryPersonContextRequest,
    ).overrideWithValue(view),
  ],
);

PersonContextView _view(DateTime now, List<PersonContextSignal> signals) =>
    PersonContextView(
      accountScopeId: 'v2.test-account',
      surface: PersonContextSurface.trajectory,
      purposes: operationalPersonContextPurposes,
      observedAt: now,
      signals: signals,
      unknownKinds: const <PersonContextKind>{},
    );

PersonContextSignal _signal({
  required String id,
  required String value,
  required DateTime now,
  PersonContextPurpose purpose = PersonContextPurpose.decisionSupport,
  DateTime? freshUntil,
}) => PersonContextSignal(
  id: id,
  kind: PersonContextKind.boundary,
  value: value,
  source: PersonContextSource.userAuthored,
  consent: PersonContextConsent.granted,
  consentedAt: now.subtract(const Duration(minutes: 5)),
  purpose: purpose,
  surfaceScopes: const <PersonContextSurface>{PersonContextSurface.trajectory},
  recordedAt: now.subtract(const Duration(minutes: 5)),
  freshUntil: freshUntil ?? now.add(const Duration(hours: 2)),
  expiresAt: now.add(const Duration(days: 1)),
  exportBehavior: PersonContextExportBehavior.include,
  deletionBehavior: PersonContextDeletionBehavior.userRemovable,
);

final SIStateAggregation _aggregation = SIStateAggregation(
  tasks: <Task>[
    Task(
      id: 'task-a',
      title: 'Task A',
      priority: 5,
      difficulty: 3,
      energyRequired: 3,
      dueDate: DateTime.now().toUtc().add(const Duration(days: 1)),
      estimatedDuration: const Duration(minutes: 30),
    ),
  ],
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
);

const ExecutionSignals _execution = ExecutionSignals(
  createdToday: 1,
  completedToday: 0,
  skippedToday: 0,
  delayedToday: 0,
  created7d: 1,
  completed7d: 0,
  skipped7d: 0,
  delayed7d: 0,
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
