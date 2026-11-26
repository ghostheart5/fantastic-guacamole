import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_live_container.dart';

/// Local clock for the tests: 1 December 2026, 09:00 local time.
class _Clock {
  DateTime local = DateTime(2026, 12, 1, 9);
  DateTime call() => local.toUtc();
  void nextDay() => local = DateTime(local.year, local.month, local.day + 1, 9);
}

TrajectoryForecastLedgerRepository _ledgerOf(
  TrajectoryMemoryStore store,
  String userId,
) => TrajectoryForecastLedgerRepository(
  store: store,
  scope: AccountStorageScope.authenticated(userId),
);

String _namespace(String userId) =>
    AccountStorageScope.authenticated(userId).v2Namespace!;

/// A store whose writes always fail; it counts the attempts.
class _FailingStore extends TrajectoryMemoryStore {
  @override
  Future<void> save(String key, String value) async {
    saves++;
    throw StateError('disk full');
  }
}

/// Lets the deferred automatic work finish (the in-memory store completes
/// in microtasks).
Future<void> _settle() async {
  for (int i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Reads the engine model the way a watching screen does: once, then again
/// after pending loads (such as the calibration summary) have settled.
Future<TrajectoryEngineModel> _watchModel(ProviderContainer container) async {
  container.read(trajectoryEngineModelProvider);
  await _settle();
  final TrajectoryEngineModel model = container.read(
    trajectoryEngineModelProvider,
  );
  await _settle();
  return model;
}

/// Builds the engine model once the planning evidence is loaded, which is
/// what reports a ready comparison.
Future<TrajectoryEngineModel> _ready(ProviderContainer container) async {
  await container.read(siStateAggregationProvider.future);
  return _watchModel(container);
}

/// A new ready comparison for the same account (as after a refresh).
Future<void> _readyAgain(ProviderContainer container) async {
  container.invalidate(trajectoryConsequenceProvider);
  await _watchModel(container);
}

TrajectoryForecastReceipt _manual(
  String userId,
  DateTime selectedAt, {
  int horizonDays = 7,
}) => TrajectoryForecastReceipt(
  id: 'manual-${selectedAt.microsecondsSinceEpoch}-$horizonDays',
  accountScope: _namespace(userId),
  baselineRevision: 'trajectory-v4-earlier',
  scenarioId: 'trajectory-v4-earlier:maintain-course',
  interventionType: TrajectoryInterventionType.maintainCourse,
  generatedAt: selectedAt,
  selectedAt: selectedAt,
  horizon: Duration(days: horizonDays),
  projectedMomentum: 55,
  projectedPressure: 3,
  uncertainty: 20,
  projectedRiskScore: 20,
  confidenceBand: PredictiveConfidenceBand.moderate,
  modelVersion: trajectoryConsequenceModelVersion,
);

void main() {
  test('one automatic keep-going receipt per range per local day', () async {
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
    );
    addTearDown(container.dispose);

    final TrajectoryEngineModel model = await _ready(container);
    expect(model.status, isNot(TrajectoryEngineStatus.learning));
    List<TrajectoryForecastReceipt> ledger = await _ledgerOf(
      store,
      'account-a',
    ).load();
    expect(ledger, hasLength(1));
    final TrajectoryForecastReceipt first = ledger.single;
    expect(first.isAutomatic, isTrue);
    expect(first.interventionType, TrajectoryInterventionType.maintainCourse);
    expect(first.horizon, const Duration(days: 7));
    expect(first.selectedAt, clock());
    expect(first.accountScope, _namespace('account-a'));
    expect(first.schemaVersion, 3);

    // A second ready comparison the same day records nothing.
    await _readyAgain(container);
    expect(await _ledgerOf(store, 'account-a').load(), hasLength(1));

    // Nor does one after a restart the same day (a new container).
    final ProviderContainer restarted = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
    );
    addTearDown(restarted.dispose);
    await _ready(restarted);
    expect(await _ledgerOf(store, 'account-a').load(), hasLength(1));

    // Changing the range records one for that range.
    container.read(trajectoryHorizonDaysProvider.notifier).select(30);
    container.read(trajectoryEngineModelProvider);
    await _settle();
    ledger = await _ledgerOf(store, 'account-a').load();
    expect(ledger, hasLength(2));
    expect(ledger.first.horizon, const Duration(days: 30));
    expect(ledger.first.isAutomatic, isTrue);

    // The next local day records again.
    container.read(trajectoryHorizonDaysProvider.notifier).select(7);
    clock.nextDay();
    await _readyAgain(container);
    ledger = await _ledgerOf(store, 'account-a').load();
    expect(ledger, hasLength(3));
    expect(ledger.first.selectedAt, clock());
    expect(ledger.first.horizon, const Duration(days: 7));
  });

  test('nothing is recorded from a comparison built while the calibration '
      'summary is still loading', () async {
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final Completer<List<TrajectoryForecastReceipt>> ledger =
        Completer<List<TrajectoryForecastReceipt>>();
    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
      overrides: [
        trajectoryForecastLedgerProvider.overrideWith(
          (Ref ref) => ledger.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final TrajectoryEngineModel model = await _ready(container);
    expect(model.hasComparison, isTrue);
    expect(store.saves, 0);

    ledger.complete(const <TrajectoryForecastReceipt>[]);
    await container.read(trajectoryForecastLedgerProvider.future);
    container.read(trajectoryEngineModelProvider);
    await _settle();
    expect(await _ledgerOf(store, 'account-a').load(), hasLength(1));
  });

  test('when the ledger fails to load nothing is recorded or checked, and '
      'it is logged once', () async {
    final List<String?> logs = <String?>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = original);
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
      overrides: [
        trajectoryForecastLedgerProvider.overrideWith(
          (Ref ref) => Future<List<TrajectoryForecastReceipt>>.error(
            StateError('ledger unreadable'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final TrajectoryEngineModel model = await _ready(container);
    await _readyAgain(container);
    await _readyAgain(container);
    expect(model.hasComparison, isTrue);
    expect(store.saves, 0);
    expect(
      logs.where(
        (String? m) =>
            m?.contains('Forecast ledger could not be loaded') ?? false,
      ),
      hasLength(1),
    );
  });

  test('nothing is recorded while the app is not in the foreground', () async {
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
      overrides: [
        trajectoryAppInForegroundProvider.overrideWithValue(() => false),
      ],
    );
    addTearDown(container.dispose);
    final TrajectoryEngineModel model = await _ready(container);
    expect(model.hasComparison, isTrue);
    expect(store.saves, 0);
  });

  test('nothing is recorded or checked in the learning state', () async {
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
      completed7d: 2,
    );
    addTearDown(container.dispose);
    final TrajectoryEngineModel model = await _ready(container);
    expect(model.status, TrajectoryEngineStatus.learning);
    expect(store.saves, 0);
    expect(await _ledgerOf(store, 'account-a').load(), isEmpty);
  });

  test('the cap holds and an unchecked manual receipt is never dropped for '
      'an automatic one', () async {
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final TrajectoryForecastLedgerRepository ledger = _ledgerOf(
      store,
      'account-a',
    );
    // 120 unchecked manual 90-day receipts, none due yet.
    for (int i = 0; i < 120; i++) {
      await ledger.append(
        _manual(
          'account-a',
          clock().subtract(Duration(hours: i + 1)),
          horizonDays: 90,
        ),
      );
    }
    expect(await ledger.load(), hasLength(120));
    final int savesBefore = store.saves;

    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
    );
    addTearDown(container.dispose);
    await _ready(container);

    final List<TrajectoryForecastReceipt> after = await ledger.load();
    expect(after, hasLength(120));
    expect(
      after.where((TrajectoryForecastReceipt r) => r.isAutomatic),
      isEmpty,
    );
    expect(store.saves, savesBefore);
  });

  test('due forecasts are checked once per account per local day', () async {
    final _Clock clock = _Clock();
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final TrajectoryForecastLedgerRepository ledger = _ledgerOf(
      store,
      'account-a',
    );
    final TrajectoryForecastReceipt due = _manual(
      'account-a',
      clock().subtract(const Duration(days: 8)),
    );
    await ledger.append(due);

    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
    );
    addTearDown(container.dispose);
    await _ready(container);
    TrajectoryForecastReceipt checked = (await ledger.load()).firstWhere(
      (TrajectoryForecastReceipt r) => r.id == due.id,
    );
    expect(checked.isResolved, isTrue);
    // Measured like with like: the 7-day workload of the live fixture.
    expect(
      checked.observed!.pressure,
      container
          .read(trajectoryConsequenceProvider)
          .requireValue
          .baseline
          .pressure,
    );

    // Another forecast, due today, is added after today's check: not checked
    // again today; checked tomorrow (one day late is still in time).
    final TrajectoryForecastReceipt dueLater = _manual(
      'account-a',
      clock().subtract(const Duration(days: 7)),
    );
    await ledger.append(dueLater);
    await _readyAgain(container);
    checked = (await ledger.load()).firstWhere(
      (TrajectoryForecastReceipt r) => r.id == dueLater.id,
    );
    expect(checked.isResolved, isFalse);

    clock.nextDay();
    await _readyAgain(container);
    checked = (await ledger.load()).firstWhere(
      (TrajectoryForecastReceipt r) => r.id == dueLater.id,
    );
    expect(checked.isResolved, isTrue);
  });

  test('a failing store is tried once a day, not on every rebuild, and the '
      'failure is logged', () async {
    final List<String?> logs = <String?>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = original);
    final _Clock clock = _Clock();
    final _FailingStore store = _FailingStore();
    final ProviderContainer container = trajectoryLiveContainer(
      now: clock.local,
      clock: clock.call,
      store: store,
    );
    addTearDown(container.dispose);

    await _ready(container);
    expect(store.saves, 1);
    await _readyAgain(container);
    await _readyAgain(container);
    expect(store.saves, 1);
    expect(
      logs.where((String? m) => m?.contains('forecast') ?? false),
      isNotEmpty,
    );

    clock.nextDay();
    await _readyAgain(container);
    expect(store.saves, 2);
  });

  group('account safety', () {
    test('an account switch between ready and the write records nothing in '
        'either ledger', () async {
      final _Clock clock = _Clock();
      final TrajectoryMemoryStore store = TrajectoryMemoryStore();
      final ProviderContainer container = trajectoryLiveContainer(
        now: clock.local,
        clock: clock.call,
        store: store,
      );
      addTearDown(container.dispose);
      await container.read(siStateAggregationProvider.future);
      await container.read(trajectoryForecastLedgerProvider.future);

      container.read(trajectoryEngineModelProvider);
      // Before the deferred write runs, the person switches accounts.
      container.read(trajectoryLiveAccountProvider.notifier).use('account-b');
      await _settle();

      expect(await _ledgerOf(store, 'account-a').load(), isEmpty);
      expect(await _ledgerOf(store, 'account-b').load(), isEmpty);
      expect(store.saves, 0);

      // Back on account A the same day, the attempt is made again.
      container.read(trajectoryLiveAccountProvider.notifier).use('account-a');
      await _watchModel(container);
      expect(await _ledgerOf(store, 'account-a').load(), hasLength(1));
      expect(await _ledgerOf(store, 'account-b').load(), isEmpty);
    });

    test(
      'a new session generation for the same account writes nothing',
      () async {
        final _Clock clock = _Clock();
        final TrajectoryMemoryStore store = TrajectoryMemoryStore();
        final ProviderContainer container = trajectoryLiveContainer(
          now: clock.local,
          clock: clock.call,
          store: store,
        );
        addTearDown(container.dispose);
        await container.read(siStateAggregationProvider.future);
        await container.read(trajectoryForecastLedgerProvider.future);

        container.read(trajectoryEngineModelProvider);
        container
            .read(authSessionBoundaryProvider.notifier)
            .begin(userId: 'account-a', isTransitioning: false);
        await _settle();
        expect(store.saves, 0);
        expect(await _ledgerOf(store, 'account-a').load(), isEmpty);
      },
    );

    test('each account records only into its own ledger', () async {
      final _Clock clock = _Clock();
      final TrajectoryMemoryStore store = TrajectoryMemoryStore();
      final ProviderContainer container = trajectoryLiveContainer(
        now: clock.local,
        clock: clock.call,
        store: store,
      );
      addTearDown(container.dispose);
      await _ready(container);
      container.read(trajectoryLiveAccountProvider.notifier).use('account-b');
      await _watchModel(container);

      final List<TrajectoryForecastReceipt> a = await _ledgerOf(
        store,
        'account-a',
      ).load();
      final List<TrajectoryForecastReceipt> b = await _ledgerOf(
        store,
        'account-b',
      ).load();
      expect(a.single.accountScope, _namespace('account-a'));
      expect(b.single.accountScope, _namespace('account-b'));
      expect(
        await container.read(trajectoryForecastLedgerProvider.future),
        hasLength(1),
      );
      expect(
        (await container.read(
          trajectoryForecastLedgerProvider.future,
        )).single.accountScope,
        _namespace('account-b'),
      );
    });
  });

  group('manual actions', () {
    test('tracking uses the injected clock and stays manual', () async {
      final _Clock clock = _Clock();
      final TrajectoryMemoryStore store = TrajectoryMemoryStore();
      final ProviderContainer container = trajectoryLiveContainer(
        now: clock.local,
        clock: clock.call,
        store: store,
      );
      addTearDown(container.dispose);
      await container.read(siStateAggregationProvider.future);
      final TrajectoryComparison comparison = container
          .read(trajectoryConsequenceProvider)
          .requireValue;
      clock.local = clock.local.add(const Duration(minutes: 5));

      expect(
        await container
            .read(trajectoryForecastLedgerActionsProvider)
            .track(
              baseline: comparison.baseline,
              outcome: comparison.outcomes.first,
            ),
        isTrue,
      );
      final TrajectoryForecastReceipt receipt = (await _ledgerOf(
        store,
        'account-a',
      ).load()).single;
      expect(receipt.selectedAt, clock());
      expect(receipt.isAutomatic, isFalse);
    });

    test(
      'reconciling checks a 30-day forecast with the 30-day workload',
      () async {
        final _Clock clock = _Clock();
        final TrajectoryMemoryStore store = TrajectoryMemoryStore();
        final TrajectoryForecastLedgerRepository ledger = _ledgerOf(
          store,
          'account-a',
        );
        final TrajectoryForecastReceipt due = _manual(
          'account-a',
          clock().subtract(const Duration(days: 31)),
          horizonDays: 30,
        );
        await ledger.append(due);
        final ProviderContainer container = trajectoryLiveContainer(
          now: clock.local,
          clock: clock.call,
          store: store,
        );
        addTearDown(container.dispose);
        await container.read(siStateAggregationProvider.future);
        final TrajectoryBaseline baseline = container
            .read(trajectoryConsequenceProvider)
            .requireValue
            .baseline;
        // 90 minutes against 240 free minutes a day: 5 over the next 7 days,
        // 1 over 30 days.
        expect(baseline.pressure, 5);
        expect(trajectoryRangeWorkload(baseline)(30), 1);

        expect(
          await container
              .read(trajectoryForecastLedgerActionsProvider)
              .reconcile(baseline),
          1,
        );
        expect((await ledger.load()).single.observed!.pressure, 1);
      },
    );
  });
}
