import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/controllers/signal_controller.dart';
import 'package:fantastic_guacamole/state/models/completion_score_view.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_score_provider.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('signal evidence providers', () {
    late SecureStore store;
    late ProviderContainer container;

    setUp(() {
      store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      ).forAccount(AccountStorageScope.authenticated('account-a'));
      container = ProviderContainer(
        overrides: [
          accountSecureStoreProvider.overrideWithValue(store),
          energyProvider.overrideWithValue(0.75),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('completion signal stays absent until a completion is recorded', () {
      expect(container.read(completionSignalProvider), isNull);

      container
          .read(completionScoreProvider.notifier)
          .set(
            const CompletionScoreView(
              xp: 12,
              quality: 0.9,
              feedback: 'Strong completion',
              durationSeconds: 320,
            ),
          );

      final signal = container.read(completionSignalProvider);
      expect(signal, isNotNull);
      expect(signal!.summary, 'You worked for 320 seconds.');
      expect(signal.observation, 'Strong completion.');
      expect(signal.suggestion, contains('keep building'));
    });

    test(
      'pattern signal handles absent, valid, and malformed ledgers',
      () async {
        expect(
          await container.read(patternSignalProvider.future),
          'No data yet.',
        );

        await store.writeString(
          'neural_dump',
          jsonEncode(<Map<String, dynamic>>[
            _outcome('Plan release', true, 300).toJson(),
            _outcome('Review release', true, 360).toJson(),
          ]),
        );
        container.invalidate(patternSignalProvider);
        expect(
          await container.read(patternSignalProvider.future),
          'You perform best with your current rhythm.',
        );

        await store.writeString('neural_dump', '{not-json');
        container.invalidate(patternSignalProvider);
        expect(
          await container.read(patternSignalProvider.future),
          'No data yet.',
        );
      },
    );
  });

  group('prediction evidence provider', () {
    late SecureStore store;
    late ProviderContainer container;

    setUp(() {
      store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      ).forAccount(AccountStorageScope.authenticated('account-a'));
      container = ProviderContainer(
        overrides: [accountSecureStoreProvider.overrideWithValue(store)],
      );
    });

    tearDown(() => container.dispose());

    test('reports cold start rather than inventing a forecast', () async {
      final Prediction result = await container.read(
        predictionProvider('Unknown task').future,
      );

      expect(result.outcome, 'Unknown');
      expect(result.sampleSize, 0);
      expect(result.signals, <String>['cold-start']);
    });

    test('falls back safely when the local ledger is malformed', () async {
      await store.writeString('neural_dump', 'not-json');

      final Prediction result = await container.read(
        predictionProvider('Unknown task').future,
      );

      expect(result.outcome, 'Unknown');
      expect(result.confidence, 0.35);
    });

    test(
      'uses exact outcomes and labels higher and lower follow-through',
      () async {
        await store.writeString(
          'neural_dump',
          jsonEncode(<Map<String, dynamic>>[
            _outcome('Write brief', true, 300).toJson(),
            _outcome('Write brief', true, 300).toJson(),
            _outcome('Write brief', true, 300).toJson(),
            _outcome('Other task', false, 0).toJson(),
          ]),
        );

        final Prediction higher = await container.read(
          predictionProvider(' write brief ').future,
        );
        final Prediction lower = buildObservedFollowThroughPrediction(
          history: <NeuralEntry>[
            _outcome('Avoided task', false, 0),
            _outcome('Avoided task', false, 0),
            _outcome('Avoided task', false, 0),
          ],
          taskTitle: 'Avoided task',
        );
        final Prediction fallback = buildObservedFollowThroughPrediction(
          history: <NeuralEntry>[_outcome('Different task', true, 300)],
          taskTitle: 'Missing task',
        );

        expect(higher.outcome, 'Higher observed follow-through');
        expect(higher.sampleSize, 3);
        expect(lower.outcome, 'Lower observed follow-through');
        expect(fallback.explanation, startsWith('No exact task history'));
      },
    );
  });

  test('momentum controller records and resets a completion chain', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final MomentumController controller = container.read(
      momentumProvider.notifier,
    );
    controller.onCompletionRecorded();
    controller.onCompletionRecorded();
    expect(container.read(momentumProvider).active, isTrue);
    expect(container.read(momentumProvider).chainCount, 2);

    controller.reset();
    expect(container.read(momentumProvider).active, isFalse);
    expect(container.read(momentumProvider).chainCount, 0);
  });

  group('explainable SI evidence', () {
    const DailyDecisionIntelligence decision = DailyDecisionIntelligence(
      primaryAction: 'Complete the smallest release task.',
      momentum: '60% Stable',
      trajectory: 'Path is stable.',
      energy: '60% energy',
      warning: 'No material constraint.',
      recovery: 'Recovered',
      recommendedAction: 'Complete the smallest release task.',
      rationale: 'Supported by current task and outcome evidence.',
      changeSummary: 'No significant change.',
      evidence: <String>['task-count=2'],
      confidence: 0.7,
      observedOutcomes: 4,
    );

    test(
      'classifies positive, neutral, and warning evidence independently',
      () {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            momentumEngineProvider.overrideWithValue(
              const MomentumEngineState(
                score: 75,
                trend: 'Rising',
                recovery: 'Watch Load',
                forecast: 'Observed momentum is rising.',
                energyPercent: 50,
                pressurePercent: 75,
                streak: 3,
                completedToday: 2,
              ),
            ),
            dailyDecisionIntelligenceProvider.overrideWithValue(decision),
          ],
        );
        addTearDown(container.dispose);

        final ExplainableSIState result = container.read(explainableSIProvider);
        expect(result.primaryReason, decision.rationale);
        expect(result.recommendation, decision.recommendedAction);
        expect(
          result.reasons.map((ExplainableSIReason value) => value.severity),
          <ExplainableSISeverity>[
            ExplainableSISeverity.positive,
            ExplainableSISeverity.neutral,
            ExplainableSISeverity.warning,
            ExplainableSISeverity.neutral,
          ],
        );
      },
    );

    test(
      'reports low evidence as warnings without changing the recommendation',
      () {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            momentumEngineProvider.overrideWithValue(
              const MomentumEngineState(
                score: 30,
                trend: 'Declining',
                recovery: 'Recovery Needed',
                forecast: 'Recovery evidence is elevated.',
                energyPercent: 25,
                pressurePercent: 30,
                streak: 0,
                completedToday: 0,
              ),
            ),
            dailyDecisionIntelligenceProvider.overrideWithValue(decision),
          ],
        );
        addTearDown(container.dispose);

        final ExplainableSIState result = container.read(explainableSIProvider);
        expect(result.reasons[0].severity, ExplainableSISeverity.warning);
        expect(result.reasons[1].severity, ExplainableSISeverity.warning);
        expect(result.reasons[2].severity, ExplainableSISeverity.positive);
        expect(result.reasons[3].severity, ExplainableSISeverity.warning);
        expect(result.recommendation, decision.recommendedAction);
      },
    );
  });
}

NeuralEntry _outcome(String task, bool completed, int duration) {
  return NeuralEntry(
    task: task,
    reasoning: completed
        ? 'Observed completed task outcome.'
        : 'Observed skipped task outcome.',
    confidence: 1,
    duration: duration,
    quality: completed ? 0.9 : 0.1,
    timestamp: DateTime.utc(2026, 8, 19),
    completed: completed,
  );
}
