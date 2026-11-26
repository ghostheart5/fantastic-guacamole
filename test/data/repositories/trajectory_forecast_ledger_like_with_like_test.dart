import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
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
TrajectoryBaseline _baseline({int horizonDays = 7}) => trajectoryTestBaseline(
  accountScope: _scope.v2Namespace!,
  horizonDays: horizonDays,
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
        // reads without the new key (what an older reader sees).
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
        final TrajectoryForecastReceipt asOldReader =
            TrajectoryForecastReceipt.fromJson(
              Map<String, dynamic>.of(json)..remove('earlierMethodAt'),
            );
        expect(asOldReader.id, settled.id);
        expect(asOldReader.observed, isNull);
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

    test('an automatic receipt keeps every old key and reads without the new '
        'one', () {
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
      final TrajectoryForecastReceipt asOldReader =
          TrajectoryForecastReceipt.fromJson(
            Map<String, dynamic>.of(json)..remove('origin'),
          );
      expect(asOldReader.isAutomatic, isFalse);
      expect(asOldReader.projectedPressure, receipt.projectedPressure);
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
