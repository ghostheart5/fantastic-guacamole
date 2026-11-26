import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_live_container.dart';

final DateTime _now = DateTime(2026, 12, 1, 9);
final String _accountA = AccountStorageScope.authenticated(
  'account-a',
).v2Namespace!;
final String _accountB = AccountStorageScope.authenticated(
  'account-b',
).v2Namespace!;

/// Four checked current-version forecasts, two inside their range: coverage
/// 0.5, so the rule widens by 1.5.
List<TrajectoryForecastReceipt> _poorlyCovered(String accountScope) =>
    <TrajectoryForecastReceipt>[
      for (int i = 0; i < 4; i++)
        TrajectoryForecastReceipt(
          id: 'checked-$i',
          accountScope: accountScope,
          baselineRevision: 'trajectory-v4-old',
          scenarioId: 'trajectory-v4-old:maintain-course',
          interventionType: TrajectoryInterventionType.maintainCourse,
          generatedAt: DateTime.utc(2026, 11, 1 + i, 12),
          selectedAt: DateTime.utc(2026, 11, 1 + i, 12),
          horizon: const Duration(days: 7),
          projectedMomentum: 60,
          projectedPressure: 5,
          uncertainty: 10,
          projectedRiskScore: 20,
          confidenceBand: PredictiveConfidenceBand.moderate,
          modelVersion: trajectoryConsequenceModelVersion,
        ).resolve(
          TrajectoryObservedOutcome(
            observedAt: DateTime.utc(2026, 11, 8 + i, 12),
            momentum: i.isEven ? 60 : 0,
            pressure: 5,
            completedInWindow: 7,
            deferredInWindow: 0,
          ),
        ),
    ];

Future<TrajectoryComparison> _comparison(ProviderContainer container) async {
  await container.read(siStateAggregationProvider.future);
  final AsyncValue<TrajectoryComparison> value = container.read(
    trajectoryConsequenceProvider,
  );
  expect(value.hasValue, isTrue, reason: 'the comparison is never delayed');
  return value.requireValue;
}

TrajectoryScenarioOutcome _keepGoing(TrajectoryComparison comparison) =>
    comparison.outcomes.firstWhere(
      (TrajectoryScenarioOutcome o) =>
          o.intervention.type == TrajectoryInterventionType.maintainCourse,
    );

void main() {
  test('while the summary loads the comparison is provisional; when it '
      'arrives the uncertainty and the revision change', () async {
    final Completer<List<TrajectoryForecastReceipt>> ledger =
        Completer<List<TrajectoryForecastReceipt>>();
    final ProviderContainer container = trajectoryLiveContainer(
      now: _now,
      clock: () => _now.toUtc(),
      store: TrajectoryMemoryStore(),
      overrides: [
        trajectoryForecastLedgerProvider.overrideWith(
          (Ref ref) => ledger.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    final TrajectoryComparison loading = await _comparison(container);
    expect(
      container.read(trajectoryCalibrationAdjustmentProvider),
      TrajectoryCalibrationAdjustment.provisional,
    );
    expect(_keepGoing(loading).uncertainty, 20);
    expect(
      loading.outcomes.map(
        (TrajectoryScenarioOutcome o) => o.confidence.calibration,
      ),
      everyElement(PredictiveCalibrationState.provisional),
    );
    expect(
      loading.baseline.sourceRevisions.containsKey('calibration'),
      isFalse,
    );

    ledger.complete(_poorlyCovered(_accountA));
    await container.read(trajectoryForecastLedgerProvider.future);
    final TrajectoryComparison arrived = await _comparison(container);

    expect(_keepGoing(arrived).uncertainty, 30);
    expect(
      arrived.outcomes.map(
        (TrajectoryScenarioOutcome o) => o.confidence.calibration,
      ),
      everyElement(PredictiveCalibrationState.monitored),
    );
    expect(arrived.baseline.sourceRevisions['calibration'], 'monitored:1.5');
    expect(arrived.baseline.revision, isNot(loading.baseline.revision));
    expect(
      _keepGoing(arrived).projectedPressure,
      _keepGoing(loading).projectedPressure,
    );
  });

  test('a failed summary gives a provisional comparison', () async {
    final ProviderContainer container = trajectoryLiveContainer(
      now: _now,
      clock: () => _now.toUtc(),
      store: TrajectoryMemoryStore(),
      overrides: [
        trajectoryForecastLedgerProvider.overrideWith(
          (Ref ref) => Future<List<TrajectoryForecastReceipt>>.error(
            StateError('ledger unavailable'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await _comparison(container);
    await expectLater(
      container.read(trajectoryForecastLedgerProvider.future),
      throwsStateError,
    );

    final TrajectoryComparison failed = await _comparison(container);
    expect(
      container.read(trajectoryCalibrationSummaryProvider).hasError,
      isTrue,
    );
    expect(_keepGoing(failed).uncertainty, 20);
    expect(
      _keepGoing(failed).confidence.calibration,
      PredictiveCalibrationState.provisional,
    );
  });

  test('a summary of another account is never used', () {
    final ProviderContainer container = trajectoryLiveContainer(
      now: _now,
      clock: () => _now.toUtc(),
      store: TrajectoryMemoryStore(),
      overrides: [
        trajectoryCalibrationSummaryProvider.overrideWithValue(
          AsyncData<TrajectoryCalibrationSummary>(
            TrajectoryCalibrationSummary.fromReceipts(
              _poorlyCovered(_accountA),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(trajectoryCalibrationAdjustmentProvider).multiplier,
      1.5,
    );
    container.read(trajectoryLiveAccountProvider.notifier).use('account-b');
    expect(
      container.read(trajectoryCalibrationAdjustmentProvider),
      TrajectoryCalibrationAdjustment.provisional,
    );
  });

  test('account B never uses account A ledger or adjustment', () async {
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final ProviderContainer container = trajectoryLiveContainer(
      now: _now,
      clock: () => _now.toUtc(),
      store: store,
    );
    addTearDown(container.dispose);
    for (final TrajectoryForecastReceipt receipt in _poorlyCovered(_accountA)) {
      await container
          .read(trajectoryForecastLedgerRepositoryProvider)
          .append(receipt);
    }
    await container.read(trajectoryForecastLedgerProvider.future);
    final TrajectoryComparison a = await _comparison(container);
    expect(a.baseline.accountScope, _accountA);
    expect(_keepGoing(a).uncertainty, 30);

    container.read(trajectoryLiveAccountProvider.notifier).use('account-b');
    // Immediately after the switch, before B's ledger has loaded.
    final TrajectoryComparison switching = await _comparison(container);
    expect(switching.baseline.accountScope, _accountB);
    expect(
      container.read(trajectoryCalibrationAdjustmentProvider),
      TrajectoryCalibrationAdjustment.provisional,
    );
    expect(_keepGoing(switching).uncertainty, 20);

    expect(
      await container.read(trajectoryForecastLedgerProvider.future),
      isEmpty,
    );
    final TrajectoryComparison b = await _comparison(container);
    expect(_keepGoing(b).uncertainty, 20);
    expect(b.baseline.sourceRevisions.containsKey('calibration'), isFalse);
  });
}
