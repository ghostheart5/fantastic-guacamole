import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_test_fixture.dart';

/// A stored receipt written by the v3 model (before Phase 5), unresolved.
const String _storedV3Unresolved =
    '{"schemaVersion":2,"id":"trajectory-v3-1a2b:maintain-course:1786892400000000",'
    '"accountScope":"v2.dGVzdC1hY2NvdW50","baselineRevision":"trajectory-v3-1a2b",'
    '"scenarioId":"trajectory-v3-1a2b:maintain-course",'
    '"interventionType":"maintainCourse",'
    '"generatedAt":"2026-08-01T15:00:00.000Z",'
    '"selectedAt":"2026-08-01T15:00:00.000Z","horizonSeconds":604800,'
    '"projectedMomentum":61,"projectedPressure":58,"uncertainty":15,'
    '"projectedRiskScore":44,"confidenceBand":"moderate",'
    '"modelVersion":"trajectory-consequence-v3",'
    '"assumptions":["Current completion and deferral rates remain directionally similar."],'
    '"personContextRevision":null,"personContextSignalIds":[],'
    '"assumptionsCorrectedAt":null,"observed":null}';

/// A stored receipt written by the v3 model and resolved by the old code.
const String _storedV3Resolved =
    '{"schemaVersion":2,"id":"trajectory-v3-1a2b:maintain-course:1786287600000000",'
    '"accountScope":"v2.dGVzdC1hY2NvdW50","baselineRevision":"trajectory-v3-1a2b",'
    '"scenarioId":"trajectory-v3-1a2b:maintain-course",'
    '"interventionType":"maintainCourse",'
    '"generatedAt":"2026-07-25T15:00:00.000Z",'
    '"selectedAt":"2026-07-25T15:00:00.000Z","horizonSeconds":604800,'
    '"projectedMomentum":61,"projectedPressure":58,"uncertainty":15,'
    '"projectedRiskScore":44,"confidenceBand":"moderate",'
    '"modelVersion":"trajectory-consequence-v3",'
    '"assumptions":["Current completion and deferral rates remain directionally similar."],'
    '"personContextRevision":null,"personContextSignalIds":[],'
    '"assumptionsCorrectedAt":null,'
    '"observed":{"observedAt":"2026-08-01T15:00:00.000Z","momentum":64,'
    '"pressure":52,"completedInWindow":6,"deferredInWindow":2}}';

/// A stored receipt written by Task 3's v4 code (30-day range), unresolved.
const String _storedV4Task3 =
    '{"schemaVersion":2,"id":"trajectory-v4-5c6d:maintain-course:1786978800000000",'
    '"accountScope":"v2.dGVzdC1hY2NvdW50","baselineRevision":"trajectory-v4-5c6d",'
    '"scenarioId":"trajectory-v4-5c6d:maintain-course",'
    '"interventionType":"maintainCourse",'
    '"generatedAt":"2026-08-17T15:00:00.000Z",'
    '"selectedAt":"2026-08-17T15:00:00.000Z","horizonSeconds":2592000,'
    '"projectedMomentum":61,"projectedPressure":4,"uncertainty":27,'
    '"projectedRiskScore":21,"confidenceBand":"moderate",'
    '"modelVersion":"trajectory-consequence-v4",'
    '"assumptions":["Current completion and deferral rates remain directionally similar.",'
    '"Tasks without a date are counted in every time range."],'
    '"personContextRevision":null,"personContextSignalIds":[],'
    '"assumptionsCorrectedAt":null,"observed":null}';

/// An automatic receipt exactly as the first Task 4 code wrote it.
const String _storedRound1Automatic =
    '{"schemaVersion":3,"id":"trajectory-v4-65fb252f:maintain-course:1796137200000000",'
    '"accountScope":"v2.YWNjb3VudC1h","baselineRevision":"trajectory-v4-65fb252f",'
    '"scenarioId":"trajectory-v4-65fb252f:maintain-course",'
    '"interventionType":"maintainCourse",'
    '"generatedAt":"2026-12-01T15:00:00.000Z",'
    '"selectedAt":"2026-12-01T15:00:00.000Z","horizonSeconds":604800,'
    '"projectedMomentum":50,"projectedPressure":5,"uncertainty":20,'
    '"projectedRiskScore":2,"confidenceBand":"moderate",'
    '"modelVersion":"trajectory-consequence-v4",'
    '"assumptions":["Current completion and deferral rates remain directionally similar."],'
    '"personContextRevision":null,"personContextSignalIds":[],'
    '"assumptionsCorrectedAt":null,"observed":null,"origin":"automatic"}';

/// A v3 receipt the first Task 4 code settled under an earlier method.
const String _storedRound1EarlierMethod =
    '{"schemaVersion":3,"id":"trajectory-v3-1a2b:maintain-course:1786892400000000",'
    '"accountScope":"v2.dGVzdC1hY2NvdW50","baselineRevision":"trajectory-v3-1a2b",'
    '"scenarioId":"trajectory-v3-1a2b:maintain-course",'
    '"interventionType":"maintainCourse",'
    '"generatedAt":"2026-08-01T15:00:00.000Z",'
    '"selectedAt":"2026-08-01T15:00:00.000Z","horizonSeconds":604800,'
    '"projectedMomentum":61,"projectedPressure":58,"uncertainty":15,'
    '"projectedRiskScore":44,"confidenceBand":"moderate",'
    '"modelVersion":"trajectory-consequence-v3",'
    '"assumptions":["Current completion and deferral rates remain directionally similar."],'
    '"personContextRevision":null,"personContextSignalIds":[],'
    '"assumptionsCorrectedAt":null,"observed":null,'
    '"earlierMethodAt":"2026-08-16T15:00:00.000Z"}';

/// An automatic receipt as written between the two review rounds: it has a
/// multiplier but no stored engine width.
const String _storedRound2Multiplier =
    '{"schemaVersion":3,"id":"trajectory-v4-64a69808:maintain-course:1796137200000000",'
    '"accountScope":"v2.YWNjb3VudC1h","baselineRevision":"trajectory-v4-64a69808",'
    '"scenarioId":"trajectory-v4-64a69808:maintain-course",'
    '"interventionType":"maintainCourse",'
    '"generatedAt":"2026-12-01T15:00:00.000Z",'
    '"selectedAt":"2026-12-01T15:00:00.000Z","horizonSeconds":604800,'
    '"projectedMomentum":50,"projectedPressure":5,"uncertainty":30,'
    '"projectedRiskScore":2,"confidenceBand":"moderate",'
    '"modelVersion":"trajectory-consequence-v4",'
    '"assumptions":["Current completion and deferral rates remain directionally similar."],'
    '"personContextRevision":null,"personContextSignalIds":[],'
    '"assumptionsCorrectedAt":null,"observed":null,"origin":"automatic",'
    '"calibrationMultiplier":1.5}';

const List<String> _oldReceiptKeys = <String>[
  'schemaVersion',
  'id',
  'accountScope',
  'baselineRevision',
  'scenarioId',
  'interventionType',
  'generatedAt',
  'selectedAt',
  'horizonSeconds',
  'projectedMomentum',
  'projectedPressure',
  'uncertainty',
  'projectedRiskScore',
  'confidenceBand',
  'modelVersion',
  'assumptions',
  'personContextRevision',
  'personContextSignalIds',
  'assumptionsCorrectedAt',
  'observed',
];

final AccountStorageScope _scope = AccountStorageScope.authenticated(
  'test-account',
);

/// The fixture baseline in the test account's storage namespace.
TrajectoryBaseline _baseline({int horizonDays = 7, DateTime? observedAt}) =>
    trajectoryTestBaseline(
      accountScope: _scope.v2Namespace!,
      horizonDays: horizonDays,
      observedAt: observedAt,
    );

TrajectoryForecastLedgerRepository _repository(
  _MemoryStore store, {
  int maximumReceipts = 120,
}) => TrajectoryForecastLedgerRepository(
  store: store,
  scope: _scope,
  maximumReceipts: maximumReceipts,
);

/// The keep-going outcome of the fixture comparison for [horizonDays].
TrajectoryScenarioOutcome _keepGoing(int horizonDays) =>
    trajectoryTestComparison(
      horizonDays: horizonDays,
      baseline: _baseline(horizonDays: horizonDays),
    ).outcomes.firstWhere(
      (TrajectoryScenarioOutcome o) =>
          o.intervention.type == TrajectoryInterventionType.maintainCourse,
    );

TrajectoryForecastReceipt _receiptAt(
  DateTime selectedAt, {
  int horizonDays = 7,
  TrajectoryForecastOrigin origin = TrajectoryForecastOrigin.manual,
  bool resolved = false,
}) {
  final TrajectoryForecastReceipt receipt =
      TrajectoryForecastReceipt.fromScenario(
        baseline: _baseline(horizonDays: horizonDays),
        outcome: _keepGoing(horizonDays),
        selectedAt: selectedAt,
        origin: origin,
      );
  if (!resolved) return receipt;
  return receipt.resolve(
    TrajectoryObservedOutcome(
      observedAt: selectedAt.add(Duration(days: horizonDays)),
      momentum: 60,
      pressure: 18,
      completedInWindow: 6,
      deferredInWindow: 3,
    ),
  );
}

/// The workload over [days] for the fixture baseline, measured the way the
/// forecast measures it (what a baseline built for that range exposes as
/// pressureInHorizon).
int _workload(TrajectoryBaseline b, int days) =>
    FutureConsequenceEngine.capacityLoad(
      requiredMinutes: FutureConsequenceEngine.horizonWorkload(
        tasks: b.tasks,
        now: b.observedAt,
        horizonDays: days,
        completedLast7Days: b.completedInWindow,
      ).requiredMinutes,
      dailyFreeMinutes: b.dailyFreeMinutes,
      days: days,
    );

void main() {
  group('like with like at reconciliation', () {
    test('the fixture workload differs between 7 and 30 days', () {
      final TrajectoryBaseline current = _baseline();
      expect(current.pressure, 18);
      expect(_workload(current, 30), 4);
    });

    test('a v4 30-day receipt is resolved with the 30-day workload', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      await repository.append(
        _receiptAt(
          trajectoryFixtureNow.subtract(const Duration(days: 31)),
          horizonDays: 30,
        ),
      );
      final TrajectoryBaseline current = _baseline();

      expect(
        await repository.reconcileDue(
          current,
          pressureForHorizon: (int days) => _workload(current, days),
        ),
        1,
      );
      final TrajectoryForecastReceipt resolved =
          (await repository.load()).single;
      expect(resolved.observed!.pressure, 4);
      expect(resolved.observed!.pressure, isNot(current.pressure));
      expect(resolved.observed!.momentum, current.momentum);
    });

    test(
      'without a range measure, a baseline built for the same range is used',
      () async {
        final _MemoryStore store = _MemoryStore();
        final TrajectoryForecastLedgerRepository repository = _repository(
          store,
        );
        await repository.append(
          _receiptAt(
            trajectoryFixtureNow.subtract(const Duration(days: 31)),
            horizonDays: 30,
          ),
        );

        // A 7-day baseline cannot measure a 30-day range: left for later,
        // never resolved with the 7-day figure.
        expect(await repository.reconcileDue(_baseline()), 0);
        expect((await repository.load()).single.observed, isNull);

        expect(await repository.reconcileDue(_baseline(horizonDays: 30)), 1);
        expect((await repository.load()).single.observed!.pressure, 4);
      },
    );

    test('a 7-day receipt is resolved with the next-7-days workload', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      await repository.append(
        _receiptAt(trajectoryFixtureNow.subtract(const Duration(days: 8))),
      );
      expect(await repository.reconcileDue(_baseline(horizonDays: 30)), 1);
      expect((await repository.load()).single.observed!.pressure, 18);
    });

    test(
      'a due v3 receipt gets no v4 observation and counts as earlier method',
      () async {
        final _MemoryStore store = _MemoryStore();
        final TrajectoryForecastLedgerRepository repository = _repository(
          store,
        );
        store.values[repository.storageKey!] =
            '{"schemaVersion":1,"records":[$_storedV3Unresolved]}';
        final TrajectoryBaseline current = _baseline();

        expect(
          await repository.reconcileDue(
            current,
            pressureForHorizon: (int days) => _workload(current, days),
          ),
          1,
        );
        final TrajectoryForecastReceipt settled =
            (await repository.load()).single;
        expect(settled.observed, isNull);
        expect(settled.isResolved, isFalse);
        expect(settled.earlierMethodAt, trajectoryFixtureNow);
        expect(settled.isSettled, isTrue);
        expect(settled.schemaVersion, 3);

        // Reconciling again changes nothing.
        expect(await repository.reconcileDue(current), 0);

        final TrajectoryCalibrationSummary summary =
            TrajectoryCalibrationSummary.fromReceipts(
              <TrajectoryForecastReceipt>[settled],
            );
        expect(summary.resolvedForecasts, 0);
        expect(summary.earlierMethodForecasts, 1);

        // The stored JSON keeps every old key, with observed still null, and
        // parses with the new key removed. (The released reader itself is not
        // run here; it ignores unknown keys, which review checked on main.)
        final List<dynamic> records =
            (jsonDecode(store.values[repository.storageKey!]!)
                    as Map<String, dynamic>)['records']
                as List<dynamic>;
        final Map<String, dynamic> json =
            records.single as Map<String, dynamic>;
        expect(json.keys, containsAll(_oldReceiptKeys));
        expect(json['observed'], isNull);
        expect(json['earlierMethodAt'], '2026-08-16T15:00:00.000Z');
        expect(json.keys.toSet().difference(_oldReceiptKeys.toSet()), <String>{
          'earlierMethodAt',
        });
        final TrajectoryForecastReceipt withoutNewKey =
            TrajectoryForecastReceipt.fromJson(
              Map<String, dynamic>.of(json)..remove('earlierMethodAt'),
            );
        expect(withoutNewKey.id, settled.id);
        expect(withoutNewKey.observed, isNull);
      },
    );

    test('a v3 receipt resolved by the old code is left as it is', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      final String raw = '{"schemaVersion":1,"records":[$_storedV3Resolved]}';
      store.values[repository.storageKey!] = raw;
      expect(await repository.reconcileDue(_baseline()), 0);
      expect(store.values[repository.storageKey!], raw);
      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(await repository.load());
      expect(summary.resolvedForecasts, 0);
      expect(summary.earlierMethodForecasts, 1);
    });

    test('a stale account check writes nothing', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      await repository.append(
        _receiptAt(trajectoryFixtureNow.subtract(const Duration(days: 8))),
      );
      final String before = store.values[repository.storageKey!]!;
      expect(
        await repository.reconcileDue(_baseline(), isCurrent: () => false),
        0,
      );
      expect(
        await repository.append(
          _receiptAt(trajectoryFixtureNow),
          isCurrent: () => false,
        ),
        isFalse,
      );
      expect(
        await repository.appendAutomatic(
          _receiptAt(
            trajectoryFixtureNow,
            origin: TrajectoryForecastOrigin.automatic,
          ),
          isCurrent: () => false,
        ),
        isFalse,
      );
      expect(store.values[repository.storageKey!], before);
    });
  });

  group('due by local day; late checks are missed', () {
    /// Local [hour]:00 on [day] days after 1 October 2026.
    DateTime local(int day, [int hour = 9]) =>
        DateTime(2026, 10, 1 + day, hour).toUtc();

    Future<TrajectoryForecastReceipt> checkOn(
      TrajectoryForecastReceipt receipt,
      DateTime at,
    ) async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      await repository.append(receipt);
      await repository.reconcileDue(
        _baseline(observedAt: at),
        pressureForHorizon: (int _) => 18,
      );
      return (await repository.load()).single;
    }

    test('a forecast is due from the start of its local due day', () async {
      // Tracked at 18:00; checked at 09:00 seven local days later.
      final TrajectoryForecastReceipt checked = await checkOn(
        _receiptAt(local(0, 18)),
        local(7),
      );
      expect(checked.isResolved, isTrue);
      final TrajectoryForecastReceipt early = await checkOn(
        _receiptAt(local(0, 18)),
        local(6, 23),
      );
      expect(early.isSettled, isFalse);
    });

    test('a 7-day forecast checked one day late is used; two days late is '
        'missed', () async {
      final TrajectoryForecastReceipt oneLate = await checkOn(
        _receiptAt(local(0)),
        local(8),
      );
      expect(oneLate.isResolved, isTrue);
      expect(oneLate.missedAt, isNull);

      final TrajectoryForecastReceipt twoLate = await checkOn(
        _receiptAt(local(0)),
        local(9),
      );
      expect(twoLate.isResolved, isFalse);
      expect(twoLate.missedAt, local(9));
      expect(twoLate.isSettled, isTrue);
      expect(twoLate.schemaVersion, 3);
      final TrajectoryCalibrationSummary summary =
          TrajectoryCalibrationSummary.fromReceipts(<TrajectoryForecastReceipt>[
            twoLate,
          ]);
      expect(summary.resolvedForecasts, 0);
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(twoLate.toJson())) as Map<String, dynamic>;
      expect(json.keys, containsAll(_oldReceiptKeys));
      expect(json['observed'], isNull);
      expect(json['missedAt'], local(9).toIso8601String());
      expect(
        jsonEncode(TrajectoryForecastReceipt.fromJson(json).toJson()),
        jsonEncode(twoLate.toJson()),
      );
    });

    test('a 30-day forecast may be checked up to 4 days late', () async {
      final TrajectoryForecastReceipt late4 = await checkOn(
        _receiptAt(local(0), horizonDays: 30),
        local(34),
      );
      expect(late4.isResolved, isTrue);
      final TrajectoryForecastReceipt late5 = await checkOn(
        _receiptAt(local(0), horizonDays: 30),
        local(35),
      );
      expect(late5.isResolved, isFalse);
      expect(late5.missedAt, local(35));
    });

    test('a 90-day forecast may be checked up to 12 days late', () async {
      final TrajectoryForecastReceipt late12 = await checkOn(
        _receiptAt(local(0), horizonDays: 90),
        local(102),
      );
      expect(late12.isResolved, isTrue);
      final TrajectoryForecastReceipt late13 = await checkOn(
        _receiptAt(local(0), horizonDays: 90),
        local(103),
      );
      expect(late13.isResolved, isFalse);
      expect(late13.missedAt, isNotNull);
    });
  });

  group('stored data stays compatible', () {
    test('v3 and Task-3 v4 receipts round-trip byte for byte', () {
      for (final String stored in <String>[
        _storedV3Unresolved,
        _storedV3Resolved,
        _storedV4Task3,
      ]) {
        final TrajectoryForecastReceipt receipt =
            TrajectoryForecastReceipt.fromJson(
              jsonDecode(stored) as Map<String, dynamic>,
            );
        expect(receipt.origin, TrajectoryForecastOrigin.manual);
        expect(receipt.earlierMethodAt, isNull);
        expect(jsonEncode(receipt.toJson()), stored);
      }
    });

    test('untouched stored receipts stay byte-identical in the ledger', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      final String raw =
          '{"schemaVersion":1,"records":[$_storedV4Task3,$_storedV3Unresolved]}';
      store.values[repository.storageKey!] = raw;

      expect(await repository.load(), hasLength(2));
      expect(store.values[repository.storageKey!], raw);

      await repository.append(_receiptAt(trajectoryFixtureNow));
      final String rewritten = store.values[repository.storageKey!]!;
      expect(rewritten, contains(_storedV4Task3));
      expect(rewritten, contains(_storedV3Unresolved));
    });

    test('a manual receipt from the new code has exactly the old keys', () {
      final Map<String, dynamic> json = _receiptAt(
        trajectoryFixtureNow,
      ).toJson();
      expect(json.keys.toList(), _oldReceiptKeys);
      expect(json['schemaVersion'], 2);
    });

    test('an automatic receipt keeps every old key and parses with the new '
        'key removed', () {
      final TrajectoryForecastReceipt receipt = _receiptAt(
        trajectoryFixtureNow,
        origin: TrajectoryForecastOrigin.automatic,
      );
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(receipt.toJson())) as Map<String, dynamic>;
      expect(json.keys, containsAll(_oldReceiptKeys));
      expect(json['origin'], 'automatic');
      expect(json['schemaVersion'], 3);
      expect(json.keys.toSet().difference(_oldReceiptKeys.toSet()), <String>{
        'origin',
      });
      final TrajectoryForecastReceipt reread =
          TrajectoryForecastReceipt.fromJson(json);
      expect(reread.isAutomatic, isTrue);
      expect(jsonEncode(reread.toJson()), jsonEncode(receipt.toJson()));
      final TrajectoryForecastReceipt withoutNewKey =
          TrajectoryForecastReceipt.fromJson(
            Map<String, dynamic>.of(json)..remove('origin'),
          );
      expect(withoutNewKey.isAutomatic, isFalse);
      expect(withoutNewKey.projectedPressure, receipt.projectedPressure);
    });

    test('resolving and correcting keep the automatic mark', () {
      final TrajectoryForecastReceipt receipt = _receiptAt(
        trajectoryFixtureNow,
        origin: TrajectoryForecastOrigin.automatic,
        resolved: true,
      ).markAssumptionsCorrected(trajectoryFixtureNow);
      expect(receipt.isAutomatic, isTrue);
      expect(receipt.isResolved, isTrue);
      expect(receipt.schemaVersion, 3);
    });

    test('receipts written by the first Task 4 code round-trip byte for '
        'byte', () {
      for (final String stored in <String>[
        _storedRound1Automatic,
        _storedRound1EarlierMethod,
      ]) {
        final TrajectoryForecastReceipt receipt =
            TrajectoryForecastReceipt.fromJson(
              jsonDecode(stored) as Map<String, dynamic>,
            );
        expect(receipt.calibrationMultiplier, 1.0);
        expect(jsonEncode(receipt.toJson()), stored);
      }
    });

    test('a forecast made under a calibration rule stores the multiplier', () {
      final TrajectoryBaseline baseline = _baseline();
      final TrajectoryScenarioOutcome keepGoing =
          const FutureConsequenceEngine()
              .compare(
                baseline: baseline,
                generatedAt: trajectoryFixtureNow,
                interventions: <TrajectoryIntervention>[
                  _keepGoing(7).intervention,
                ],
                calibration: const TrajectoryCalibrationAdjustment(
                  multiplier: 1.5,
                  state: PredictiveCalibrationState.monitored,
                ),
              )
              .outcomes
              .single;
      final TrajectoryForecastReceipt manual =
          TrajectoryForecastReceipt.fromScenario(
            baseline: baseline,
            outcome: keepGoing,
            selectedAt: trajectoryFixtureNow,
          );
      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(manual.toJson())) as Map<String, dynamic>;
      expect(json['calibrationMultiplier'], 1.5);
      expect(json['unadjustedUncertainty'], 15);
      expect(json['schemaVersion'], 3);
      expect(json['uncertainty'], 23);
      expect(json.keys, containsAll(_oldReceiptKeys));
      final TrajectoryForecastReceipt reread =
          TrajectoryForecastReceipt.fromJson(json);
      expect(reread.calibrationMultiplier, 1.5);
      expect(reread.unadjustedUncertainty, 15);
      expect(jsonEncode(reread.toJson()), jsonEncode(manual.toJson()));
    });

    TrajectoryForecastReceipt underRule(
      TrajectoryBaseline baseline,
      int horizonDays,
      double multiplier,
    ) => TrajectoryForecastReceipt.fromScenario(
      baseline: baseline,
      outcome: const FutureConsequenceEngine()
          .compare(
            baseline: baseline,
            generatedAt: trajectoryFixtureNow,
            interventions: <TrajectoryIntervention>[
              _keepGoing(horizonDays).intervention,
            ],
            calibration: TrajectoryCalibrationAdjustment(
              multiplier: multiplier,
              state: PredictiveCalibrationState.monitored,
            ),
          )
          .outcomes
          .single,
      selectedAt: trajectoryFixtureNow,
    );

    test('a clamped 90-day width is stored even when it equals the shown '
        'one', () {
      final TrajectoryBaseline thin = trajectoryTestBaseline(
        accountScope: _scope.v2Namespace!,
        horizonDays: 90,
        observationCount: 3,
      );
      for (final double multiplier in const <double>[1.5, 1.2]) {
        final Map<String, dynamic> json = underRule(
          thin,
          90,
          multiplier,
        ).toJson();
        expect(json['uncertainty'], 42);
        expect(json['unadjustedUncertainty'], 42);
        expect(
          TrajectoryForecastReceipt.fromJson(json).unadjustedUncertainty,
          42,
        );
      }
    });

    test('a narrowed width keeps the exact engine width', () {
      // Width 17 (10 outcomes at 7 days): 17 x 0.85 = 14.45, shown 14, and
      // 14 / 0.85 = 16.5 would reconstruct 16, so only the stored width
      // gives 17 back. (15 would not tell the two apart.)
      final TrajectoryForecastReceipt narrowed = underRule(
        trajectoryTestBaseline(
          accountScope: _scope.v2Namespace!,
          observationCount: 10,
        ),
        7,
        .85,
      );
      expect(narrowed.uncertainty, 14);
      expect(narrowed.unadjustedUncertainty, 17);
      expect(narrowed.toJson()['unadjustedUncertainty'], 17);
      expect((narrowed.uncertainty / .85).round(), isNot(17));
    });

    test('a receipt with no rule has no stored width key', () {
      expect(
        _receiptAt(
          trajectoryFixtureNow,
        ).toJson().containsKey('unadjustedUncertainty'),
        isFalse,
      );
    });

    test('a receipt written between the review rounds (multiplier, no stored '
        'width) round-trips byte for byte', () {
      final TrajectoryForecastReceipt receipt =
          TrajectoryForecastReceipt.fromJson(
            jsonDecode(_storedRound2Multiplier) as Map<String, dynamic>,
          );
      expect(receipt.rawUncertainty, isNull);
      expect(receipt.unadjustedUncertainty, 20);
      expect(jsonEncode(receipt.toJson()), _storedRound2Multiplier);
    });
  });

  group('the 120-receipt cap', () {
    final DateTime start = trajectoryFixtureNow.subtract(
      const Duration(days: 60),
    );
    DateTime at(int day) => start.add(Duration(days: day));

    test('the default cap is 120', () {
      expect(_repository(_MemoryStore()).maximumReceipts, 120);
    });

    test('an unresolved manual receipt is never dropped for an automatic '
        'one', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(
        store,
        maximumReceipts: 3,
      );
      for (int day = 0; day < 3; day++) {
        await repository.append(_receiptAt(at(day)));
      }
      final String before = store.values[repository.storageKey!]!;

      expect(
        await repository.appendAutomatic(
          _receiptAt(at(10), origin: TrajectoryForecastOrigin.automatic),
        ),
        isFalse,
      );
      expect(store.values[repository.storageKey!], before);
      expect(
        (await repository.load()).every(
          (TrajectoryForecastReceipt r) => !r.isAutomatic,
        ),
        isTrue,
      );
    });

    test('checked receipts are dropped first, oldest first', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(
        store,
        maximumReceipts: 3,
      );
      final TrajectoryForecastReceipt oldManual = _receiptAt(at(0));
      final TrajectoryForecastReceipt newerChecked = _receiptAt(
        at(1),
        resolved: true,
      );
      final TrajectoryForecastReceipt newestChecked = _receiptAt(
        at(2),
        resolved: true,
      );
      for (final TrajectoryForecastReceipt r in <TrajectoryForecastReceipt>[
        oldManual,
        newerChecked,
        newestChecked,
      ]) {
        await repository.append(r);
      }

      final TrajectoryForecastReceipt automatic = _receiptAt(
        at(10),
        origin: TrajectoryForecastOrigin.automatic,
      );
      expect(await repository.appendAutomatic(automatic), isTrue);
      expect(
        (await repository.load()).map((TrajectoryForecastReceipt r) => r.id),
        <String>[automatic.id, newestChecked.id, oldManual.id],
      );
    });

    test(
      'unchecked automatic receipts go before unchecked manual ones',
      () async {
        final _MemoryStore store = _MemoryStore();
        final TrajectoryForecastLedgerRepository repository = _repository(
          store,
          maximumReceipts: 3,
        );
        final TrajectoryForecastReceipt oldManual = _receiptAt(at(0));
        final TrajectoryForecastReceipt oldAutomatic = _receiptAt(
          at(1),
          origin: TrajectoryForecastOrigin.automatic,
        );
        final TrajectoryForecastReceipt manual = _receiptAt(at(2));
        await repository.append(oldManual);
        await repository.appendAutomatic(oldAutomatic);
        await repository.append(manual);

        final TrajectoryForecastReceipt latest = _receiptAt(at(3));
        expect(await repository.append(latest), isTrue);
        expect(
          (await repository.load()).map((TrajectoryForecastReceipt r) => r.id),
          <String>[latest.id, manual.id, oldManual.id],
        );
      },
    );

    test('a manual receipt can replace the oldest unchecked manual one when '
        'nothing else can go', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(
        store,
        maximumReceipts: 2,
      );
      final TrajectoryForecastReceipt first = _receiptAt(at(0));
      final TrajectoryForecastReceipt second = _receiptAt(at(1));
      final TrajectoryForecastReceipt third = _receiptAt(at(2));
      for (final TrajectoryForecastReceipt r in <TrajectoryForecastReceipt>[
        first,
        second,
        third,
      ]) {
        await repository.append(r);
      }
      expect(
        (await repository.load()).map((TrajectoryForecastReceipt r) => r.id),
        <String>[third.id, second.id],
      );
    });
  });

  group('one automatic receipt per range per local day', () {
    DateTime localNoon(int day) => DateTime(2026, 12, day, 12).toUtc();

    test('a second one the same local day is not recorded', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      expect(
        await repository.appendAutomatic(
          _receiptAt(localNoon(1), origin: TrajectoryForecastOrigin.automatic),
        ),
        isTrue,
      );
      expect(
        await repository.appendAutomatic(
          _receiptAt(
            DateTime(2026, 12, 1, 23, 50).toUtc(),
            origin: TrajectoryForecastOrigin.automatic,
          ),
        ),
        isFalse,
      );
      // Another range the same day, and the same range the next day.
      expect(
        await repository.appendAutomatic(
          _receiptAt(
            localNoon(1).add(const Duration(minutes: 1)),
            horizonDays: 30,
            origin: TrajectoryForecastOrigin.automatic,
          ),
        ),
        isTrue,
      );
      expect(
        await repository.appendAutomatic(
          _receiptAt(localNoon(2), origin: TrajectoryForecastOrigin.automatic),
        ),
        isTrue,
      );
      expect(await repository.load(), hasLength(3));
    });

    test('a manual receipt does not use up the automatic one', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      await repository.append(_receiptAt(localNoon(1)));
      expect(
        await repository.appendAutomatic(
          _receiptAt(
            localNoon(1).add(const Duration(minutes: 1)),
            origin: TrajectoryForecastOrigin.automatic,
          ),
        ),
        isTrue,
      );
    });

    test('appendAutomatic refuses a manual receipt', () async {
      final _MemoryStore store = _MemoryStore();
      final TrajectoryForecastLedgerRepository repository = _repository(store);
      expect(
        await repository.appendAutomatic(_receiptAt(localNoon(1))),
        isFalse,
      );
      expect(await repository.load(), isEmpty);
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
