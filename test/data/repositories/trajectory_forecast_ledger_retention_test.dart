import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_test_fixture.dart';

/// What the ledger keeps when automatic receipts arrive every day: checked
/// current-version evidence survives, long ranges reach their check, and an
/// unchecked manual receipt is never pushed out by an automatic one.
final AccountStorageScope _scope = AccountStorageScope.authenticated(
  'test-account',
);

/// Local 09:00 on [day] days after 1 September 2026.
DateTime _at(int day) => DateTime(2026, 9, 1 + day, 9).toUtc();

TrajectoryForecastReceipt _receipt(
  int day,
  int horizonDays, {
  TrajectoryForecastOrigin origin = TrajectoryForecastOrigin.automatic,
  String modelVersion = trajectoryConsequenceModelVersion,
  String? id,
}) => TrajectoryForecastReceipt(
  id: id ?? '${origin.name}-$day-$horizonDays',
  accountScope: _scope.v2Namespace!,
  baselineRevision: 'trajectory-v4-day-$day',
  scenarioId: 'trajectory-v4-day-$day:maintain-course',
  interventionType: TrajectoryInterventionType.maintainCourse,
  generatedAt: _at(day),
  selectedAt: _at(day),
  horizon: Duration(days: horizonDays),
  projectedMomentum: 60,
  projectedPressure: 5,
  uncertainty: 20,
  projectedRiskScore: 20,
  confidenceBand: PredictiveConfidenceBand.moderate,
  modelVersion: modelVersion,
  origin: origin,
  schemaVersion: origin == TrajectoryForecastOrigin.automatic ? 3 : 2,
);

TrajectoryObservedOutcome _observed(int day) => TrajectoryObservedOutcome(
  observedAt: _at(day),
  momentum: 60,
  pressure: 5,
  completedInWindow: 6,
  deferredInWindow: 1,
);

TrajectoryBaseline _baselineOn(int day) => trajectoryTestBaseline(
  accountScope: _scope.v2Namespace!,
  observedAt: _at(day),
);

TrajectoryForecastLedgerRepository _repository(
  _MemoryStore store, {
  int maximumReceipts = 120,
}) => TrajectoryForecastLedgerRepository(
  store: store,
  scope: _scope,
  maximumReceipts: maximumReceipts,
);

bool _isEvidence(TrajectoryForecastReceipt r) =>
    r.isMethod(trajectoryConsequenceModelVersion) &&
    r.isResolved &&
    !r.hasAssumptionCorrection;

void main() {
  group('automatic cadence', () {
    test('7-day receipts daily; 30- and 90-day at most once per 7 local '
        'days', () async {
      final TrajectoryForecastLedgerRepository repository = _repository(
        _MemoryStore(),
      );
      for (final int horizon in const <int>[30, 90]) {
        expect(await repository.appendAutomatic(_receipt(1, horizon)), isTrue);
        expect(await repository.appendAutomatic(_receipt(2, horizon)), isFalse);
        expect(await repository.appendAutomatic(_receipt(7, horizon)), isFalse);
        expect(await repository.appendAutomatic(_receipt(8, horizon)), isTrue);
      }
      for (int day = 1; day <= 8; day++) {
        expect(await repository.appendAutomatic(_receipt(day, 7)), isTrue);
      }
    });
  });

  group('the cap keeps evidence', () {
    test('checked current-version receipts stay ahead of unchecked automatic '
        'ones', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(
        store,
        maximumReceipts: 4,
      );
      final TrajectoryForecastReceipt checkedA = _receipt(
        0,
        7,
      ).resolve(_observed(7));
      final TrajectoryForecastReceipt checkedB = _receipt(
        1,
        7,
      ).resolve(_observed(8));
      final TrajectoryForecastReceipt manual = _receipt(
        2,
        90,
        origin: TrajectoryForecastOrigin.manual,
      );
      final TrajectoryForecastReceipt waiting = _receipt(3, 90);
      for (final TrajectoryForecastReceipt r in <TrajectoryForecastReceipt>[
        checkedA,
        checkedB,
        manual,
        waiting,
      ]) {
        await repository.append(r);
      }

      // No room: the new automatic receipt is not kept, and neither the
      // checked evidence nor the older waiting receipt is pushed out.
      expect(await repository.appendAutomatic(_receipt(4, 30)), isFalse);
      expect(
        (await repository.load()).map((TrajectoryForecastReceipt r) => r.id),
        <String>[waiting.id, manual.id, checkedB.id, checkedA.id],
      );
    });

    test('receipts that are not evidence go first', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(
        store,
        maximumReceipts: 3,
      );
      final TrajectoryForecastReceipt earlier = _receipt(
        5,
        7,
        origin: TrajectoryForecastOrigin.manual,
        modelVersion: 'trajectory-consequence-v3',
      ).markEarlierMethod(_at(12));
      final TrajectoryForecastReceipt checked = _receipt(
        0,
        7,
      ).resolve(_observed(7));
      final TrajectoryForecastReceipt corrected = _receipt(
        1,
        7,
      ).resolve(_observed(8)).markAssumptionsCorrected(_at(8));
      for (final TrajectoryForecastReceipt r in <TrajectoryForecastReceipt>[
        earlier,
        checked,
        corrected,
      ]) {
        await repository.append(r);
      }
      final TrajectoryForecastReceipt fresh = _receipt(13, 7);
      expect(await repository.appendAutomatic(fresh), isTrue);
      final TrajectoryForecastReceipt fresher = _receipt(14, 7);
      expect(await repository.appendAutomatic(fresher), isTrue);
      expect(
        (await repository.load()).map((TrajectoryForecastReceipt r) => r.id),
        <String>[fresher.id, fresh.id, checked.id],
      );
    });

    test('three ranges viewed every day for 120 days keep a usable set of '
        'checked receipts, and 90-day receipts are checked', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      // One manual 90-day path tracked on day 100: never dropped.
      final TrajectoryForecastReceipt manual = _receipt(
        100,
        90,
        origin: TrajectoryForecastOrigin.manual,
      );
      for (int day = 0; day < 120; day++) {
        await repository.reconcileDue(
          _baselineOn(day),
          pressureForHorizon: (int _) => 5,
        );
        for (final int horizon in const <int>[7, 30, 90]) {
          await repository.appendAutomatic(_receipt(day, horizon));
        }
        if (day == 100) await repository.append(manual);
      }
      final List<TrajectoryForecastReceipt> kept = await repository.load();
      final List<TrajectoryForecastReceipt> evidence = kept
          .where(_isEvidence)
          .toList();
      expect(kept.length, lessThanOrEqualTo(120));
      expect(evidence.length, greaterThanOrEqualTo(60));
      expect(
        evidence.where(
          (TrajectoryForecastReceipt r) =>
              r.horizon == const Duration(days: 90),
        ),
        isNotEmpty,
      );
      expect(
        evidence.where(
          (TrajectoryForecastReceipt r) =>
              r.horizon == const Duration(days: 30),
        ),
        isNotEmpty,
      );
      expect(
        kept.map((TrajectoryForecastReceipt r) => r.id),
        contains(manual.id),
      );
      // Every 90-day receipt still waiting is kept until its check.
      expect(
        kept.where(
          (TrajectoryForecastReceipt r) =>
              r.isAutomatic &&
              !r.isSettled &&
              r.horizon == const Duration(days: 90),
        ),
        hasLength(13),
      );
    });
  });
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
