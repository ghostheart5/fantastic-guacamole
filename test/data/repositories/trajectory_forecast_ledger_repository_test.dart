import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_test_fixture.dart';

void main() {
  group('TrajectoryForecastLedgerRepository', () {
    test('stores only the matching authenticated account scope', () async {
      final _MemoryStore store = _MemoryStore();
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'user-a',
      );
      final TrajectoryForecastLedgerRepository repository =
          TrajectoryForecastLedgerRepository(store: store, scope: scope);
      final TrajectoryComparison comparison = _comparisonFor(
        scope.v2Namespace!,
      );
      final TrajectoryForecastReceipt receipt =
          TrajectoryForecastReceipt.fromScenario(
            baseline: comparison.baseline,
            outcome: comparison.outcomes.first,
            selectedAt: trajectoryFixtureNow,
          );

      expect(await repository.append(receipt), isTrue);
      final TrajectoryForecastReceipt stored = (await repository.load()).single;
      expect(stored.assumptions, receipt.assumptions);
      expect(
        TrajectoryForecastReceipt.fromJson(stored.toJson()).assumptions,
        receipt.assumptions,
      );
      final TrajectoryForecastLedgerRepository other =
          TrajectoryForecastLedgerRepository(
            store: store,
            scope: AccountStorageScope.authenticated('user-b'),
          );
      expect(await other.load(), isEmpty);
      expect(await other.append(receipt), isFalse);
    });

    test('quarantines and rebuilds a corrupt top-level ledger', () async {
      final _MemoryStore store = _MemoryStore();
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'user-a',
      );
      final TrajectoryForecastLedgerRepository repository =
          TrajectoryForecastLedgerRepository(store: store, scope: scope);
      store.values[repository.storageKey!] = '{not-json';

      expect(await repository.load(), isEmpty);
      expect(
        store.values.keys.where((String key) => key.contains('.corrupt.')),
        hasLength(1),
      );
      expect(
        jsonDecode(store.values[repository.storageKey!]!)
            as Map<String, dynamic>,
        containsPair('records', <dynamic>[]),
      );
      expect(await repository.load(), isEmpty);
    });

    test(
      'preserves valid records while quarantining a corrupt entry',
      () async {
        final _MemoryStore store = _MemoryStore();
        final AccountStorageScope scope = AccountStorageScope.authenticated(
          'user-a',
        );
        final TrajectoryForecastLedgerRepository repository =
            TrajectoryForecastLedgerRepository(store: store, scope: scope);
        final TrajectoryComparison comparison = _comparisonFor(
          scope.v2Namespace!,
        );
        final TrajectoryForecastReceipt valid =
            TrajectoryForecastReceipt.fromScenario(
              baseline: comparison.baseline,
              outcome: comparison.outcomes.first,
              selectedAt: trajectoryFixtureNow,
            );
        store.values[repository.storageKey!] = jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'records': <Object?>[
            valid.toJson(),
            <String, Object?>{'id': ''},
          ],
        });

        final List<TrajectoryForecastReceipt> loaded = await repository.load();

        expect(loaded.single.id, valid.id);
        expect(
          store.values.keys.where((String key) => key.contains('.corrupt.')),
          hasLength(1),
        );
        final Map<String, dynamic> rewritten =
            jsonDecode(store.values[repository.storageKey!]!)
                as Map<String, dynamic>;
        expect(rewritten['records'], hasLength(1));
      },
    );

    test(
      'reconciles only due forecasts and computes monitoring evidence',
      () async {
        final _MemoryStore store = _MemoryStore();
        final AccountStorageScope scope = AccountStorageScope.authenticated(
          'user-a',
        );
        final TrajectoryForecastLedgerRepository repository =
            TrajectoryForecastLedgerRepository(store: store, scope: scope);
        final TrajectoryComparison comparison = _comparisonFor(
          scope.v2Namespace!,
        );
        await repository.append(
          TrajectoryForecastReceipt.fromScenario(
            baseline: comparison.baseline,
            outcome: comparison.outcomes.first,
            selectedAt: trajectoryFixtureNow.subtract(const Duration(days: 8)),
          ),
        );

        expect(await repository.reconcileDue(comparison.baseline), 1);
        final List<TrajectoryForecastReceipt> loaded = await repository.load();
        expect(loaded.single.observed, isNotNull);
        final TrajectoryCalibrationSummary summary =
            TrajectoryCalibrationSummary.fromReceipts(loaded);
        expect(summary.resolvedForecasts, 1);
        expect(summary.state.name, 'monitored');
        expect(summary.momentumMeanAbsoluteError, greaterThanOrEqualTo(0));
        expect(summary.intervalCoverage, inInclusiveRange(0, 1));
      },
    );

    test('stores a local correction and excludes it from monitoring', () async {
      final _MemoryStore store = _MemoryStore();
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'user-a',
      );
      final TrajectoryForecastLedgerRepository repository =
          TrajectoryForecastLedgerRepository(store: store, scope: scope);
      final TrajectoryComparison comparison = _comparisonFor(
        scope.v2Namespace!,
      );
      final TrajectoryScenarioOutcome outcome = comparison.outcomes.first;
      await repository.append(
        TrajectoryForecastReceipt.fromScenario(
          baseline: comparison.baseline,
          outcome: outcome,
          selectedAt: trajectoryFixtureNow.subtract(const Duration(days: 8)),
        ),
      );

      expect(
        await repository.recordAssumptionCorrection(
          baseline: comparison.baseline,
          outcome: outcome,
          correctedAt: trajectoryFixtureNow,
        ),
        isTrue,
      );
      expect(await repository.reconcileDue(comparison.baseline), 1);

      final TrajectoryForecastReceipt corrected =
          (await repository.load()).single;
      expect(corrected.hasAssumptionCorrection, isTrue);
      expect(corrected.assumptionsCorrectedAt, trajectoryFixtureNow);
      expect(corrected.observed, isNotNull);
      expect(
        TrajectoryCalibrationSummary.fromReceipts(<TrajectoryForecastReceipt>[
          corrected,
        ]).state,
        PredictiveCalibrationState.provisional,
      );
    });

    test(
      'context revision change invalidates a tracked forecast assumption',
      () async {
        final _MemoryStore store = _MemoryStore();
        final AccountStorageScope scope = AccountStorageScope.authenticated(
          'user-a',
        );
        final TrajectoryForecastLedgerRepository repository =
            TrajectoryForecastLedgerRepository(store: store, scope: scope);
        final TrajectoryComparison comparison = _comparisonFor(
          scope.v2Namespace!,
        );
        final Map<String, dynamic> json =
            TrajectoryForecastReceipt.fromScenario(
                baseline: comparison.baseline,
                outcome: comparison.outcomes.first,
                selectedAt: trajectoryFixtureNow,
              ).toJson()
              ..['personContextRevision'] = 'context-before'
              ..['personContextSignalIds'] = <String>['shared-capacity'];
        await repository.append(TrajectoryForecastReceipt.fromJson(json));

        expect(await repository.reconcileDue(comparison.baseline), 1);
        final TrajectoryForecastReceipt invalidated =
            (await repository.load()).single;
        expect(invalidated.hasAssumptionCorrection, isTrue);
        expect(invalidated.personContextSignalIds, <String>['shared-capacity']);
        expect(invalidated.observed, isNull);
      },
    );

    test('resolved receipts remain monitored without model adjustment', () {
      final TrajectoryComparison comparison = trajectoryTestComparison();
      final List<TrajectoryForecastReceipt> resolved = List.generate(10, (
        int index,
      ) {
        return TrajectoryForecastReceipt.fromScenario(
          baseline: comparison.baseline,
          outcome: comparison.outcomes.first,
          selectedAt: trajectoryFixtureNow.subtract(Duration(days: 20 - index)),
        ).resolve(
          TrajectoryObservedOutcome(
            observedAt: trajectoryFixtureNow,
            momentum: comparison.baseline.momentum,
            pressure: comparison.baseline.pressure,
            completedInWindow: comparison.baseline.completedInWindow,
            deferredInWindow: comparison.baseline.deferredInWindow,
          ),
        );
      });

      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(resolved);

      expect(summary.resolvedForecasts, 10);
      expect(summary.state, PredictiveCalibrationState.monitored);
    });
  });
}

TrajectoryComparison _comparisonFor(String scope) {
  final TrajectoryBaseline fixture = trajectoryTestBaseline();
  final TrajectoryBaseline baseline = TrajectoryBaseline(
    accountScope: scope,
    revision: fixture.revision,
    observedAt: fixture.observedAt,
    evidenceWindow: fixture.evidenceWindow,
    momentum: fixture.momentum,
    pressure: fixture.pressure,
    energy: fixture.energy,
    completedInWindow: fixture.completedInWindow,
    deferredInWindow: fixture.deferredInWindow,
    observationCount: fixture.observationCount,
    availableMinutes: fixture.availableMinutes,
    occupiedMinutes: fixture.occupiedMinutes,
    unscheduledMinutes: fixture.unscheduledMinutes,
    tasks: fixture.tasks,
    goals: fixture.goals,
    blocks: fixture.blocks,
    timelineSignals: fixture.timelineSignals,
    progression: fixture.progression,
    confidence: fixture.confidence,
    sourceRevisions: fixture.sourceRevisions,
  );
  final TrajectoryComparison comparison = trajectoryTestComparison();
  return TrajectoryComparison(
    baseline: baseline,
    outcomes: comparison.outcomes
        .map(
          (TrajectoryScenarioOutcome item) => TrajectoryScenarioOutcome(
            id: item.id,
            baselineRevision: baseline.revision,
            intervention: item.intervention,
            generatedAt: item.generatedAt,
            projectedMomentum: item.projectedMomentum,
            projectedPressure: item.projectedPressure,
            uncertainty: item.uncertainty,
            confidence: item.confidence,
            risk: item.risk,
            timeline: item.timeline,
            goals: item.goals,
            progression: item.progression,
            evidence: item.evidence,
            assumptions: item.assumptions,
            explanation: item.explanation,
            utilityScore: item.utilityScore,
          ),
        )
        .toList(growable: false),
    recommendedScenarioId: comparison.recommendedScenarioId,
  );
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
}
