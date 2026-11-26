import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
// The forecast clock lives with the comparison provider, which in turn reads
// the calibration from this file (a deliberate two-way import).
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trajectoryForecastLedgerRepositoryProvider =
    Provider<TrajectoryForecastLedgerRepository>((Ref ref) {
      return TrajectoryForecastLedgerRepository(
        store: ref.watch(sharedPrefsStoreProvider),
        scope: ref.watch(accountStorageScopeProvider),
      );
    });

final trajectoryForecastLedgerProvider =
    FutureProvider<List<TrajectoryForecastReceipt>>((Ref ref) {
      return ref.watch(trajectoryForecastLedgerRepositoryProvider).load();
    });

final trajectoryCalibrationSummaryProvider =
    Provider<AsyncValue<TrajectoryCalibrationSummary>>((Ref ref) {
      return ref
          .watch(trajectoryForecastLedgerProvider)
          .whenData(TrajectoryCalibrationSummary.fromReceipts);
    });

/// How recorded forecast accuracy changes the current account's forecast
/// ranges. Provisional (no change) while the ledger is loading or has failed,
/// and whenever the summary belongs to another account (for example while a
/// newly signed-in account's ledger is still loading).
final trajectoryCalibrationAdjustmentProvider =
    Provider<TrajectoryCalibrationAdjustment>((Ref ref) {
      final String? namespace = ref
          .watch(accountStorageScopeProvider)
          .v2Namespace;
      final AsyncValue<TrajectoryCalibrationSummary> summary = ref.watch(
        trajectoryCalibrationSummaryProvider,
      );
      final TrajectoryCalibrationSummary? value = summary.hasError
          ? null
          : summary.value;
      if (value == null ||
          namespace == null ||
          (value.accountScope != null && value.accountScope != namespace)) {
        return TrajectoryCalibrationAdjustment.provisional;
      }
      return TrajectoryCalibrationAdjustment.fromSummary(value);
    });

final trajectoryForecastLedgerActionsProvider =
    Provider<TrajectoryForecastLedgerActions>(
      (Ref ref) => TrajectoryForecastLedgerActions(ref),
    );

/// The workload over any range length for [baseline], measured the way the
/// forecast measures it: what a baseline built for that range exposes as
/// pressureInHorizon. Used to check a forecast against its own range.
int Function(int horizonDays) trajectoryRangeWorkload(
  TrajectoryBaseline baseline,
) =>
    (int days) => FutureConsequenceEngine.capacityLoad(
      requiredMinutes: FutureConsequenceEngine.horizonWorkload(
        tasks: baseline.tasks,
        now: baseline.observedAt,
        horizonDays: days,
        completedLast7Days: baseline.completedInWindow,
      ).requiredMinutes,
      dailyFreeMinutes: baseline.dailyFreeMinutes,
      days: days,
    );

class TrajectoryForecastLedgerActions {
  const TrajectoryForecastLedgerActions(this._ref);

  final Ref _ref;

  Future<bool> track({
    required TrajectoryBaseline baseline,
    required TrajectoryScenarioOutcome outcome,
  }) async {
    final AccountOperation operation = AccountOperation.capture(_ref);
    final bool stored = await _ref
        .read(trajectoryForecastLedgerRepositoryProvider)
        .append(
          TrajectoryForecastReceipt.fromScenario(
            baseline: baseline,
            outcome: outcome,
            selectedAt: _ref.read(trajectoryClockProvider)().toUtc(),
          ),
          isCurrent: () => operation.isCurrent,
        );
    if (stored && operation.isCurrent) {
      _ref.invalidate(trajectoryForecastLedgerProvider);
    }
    return stored;
  }

  Future<int> reconcile(TrajectoryBaseline baseline) async {
    final AccountOperation operation = AccountOperation.capture(_ref);
    final int count = await _ref
        .read(trajectoryForecastLedgerRepositoryProvider)
        .reconcileDue(
          baseline,
          pressureForHorizon: trajectoryRangeWorkload(baseline),
          isCurrent: () => operation.isCurrent,
        );
    if (count > 0 && operation.isCurrent) {
      _ref.invalidate(trajectoryForecastLedgerProvider);
    }
    return count;
  }
}

/// Whether the current account's calibration summary has loaded, so a
/// comparison built now uses its recorded accuracy (an automatic receipt
/// then stores the multiplier that was really applied).
final trajectoryCalibrationLoadedProvider = Provider<bool>((Ref ref) {
  final String? namespace = ref.watch(accountStorageScopeProvider).v2Namespace;
  final AsyncValue<TrajectoryCalibrationSummary> summary = ref.watch(
    trajectoryCalibrationSummaryProvider,
  );
  final TrajectoryCalibrationSummary? value = summary.hasError
      ? null
      : summary.value;
  return namespace != null &&
      value != null &&
      (value.accountScope == null || value.accountScope == namespace);
});

/// Whether the app is in the foreground. Unknown (no lifecycle reported yet,
/// or no Flutter binding, as in plain unit tests) counts as foreground.
final trajectoryAppInForegroundProvider = Provider<bool Function()>(
  (Ref ref) => () {
    try {
      final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
      return state == null || state == AppLifecycleState.resumed;
    } on Object {
      return true;
    }
  },
);

final trajectoryForecastAutoRecorderProvider =
    Provider<TrajectoryForecastAutoRecorder>(
      TrajectoryForecastAutoRecorder.new,
    );

/// Records and checks forecasts automatically, on the device only.
///
/// When a comparison is ready for the current account (the caller decides
/// readiness: not loading, not empty, not in the learning state):
/// - due forecasts are checked at most once per account per local day (in
///   memory, so the first ready comparison after the app starts checks again;
///   checking is idempotent);
/// - the keep-going forecast for the selected range is recorded as an
///   automatic receipt (the stored ledger allows one per local day for the
///   7-day range and one per 7 local days for the 30- and 90-day ranges, so
///   this holds across restarts), within the cap.
/// The account namespace and session generation are captured when the
/// comparison is ready and checked after every await: an account change in
/// between writes nothing to either ledger, and the attempt can be repeated
/// for that account later the same day. Any other failure is logged and not
/// retried until the next local day or a restart.
class TrajectoryForecastAutoRecorder {
  TrajectoryForecastAutoRecorder(this._ref);

  final Ref _ref;
  final Set<String> _checked = <String>{};
  final Set<String> _recorded = <String>{};

  void comparisonReady(TrajectoryComparison comparison) {
    final AccountOperation operation = AccountOperation.capture(_ref);
    final String? namespace = operation.namespace;
    if (namespace == null ||
        !operation.isCurrent ||
        comparison.baseline.accountScope != namespace ||
        !_ref.read(trajectoryAppInForegroundProvider)()) {
      return;
    }
    final DateTime now = _ref.read(trajectoryClockProvider)().toUtc();
    final DateTime local = now.toLocal();
    final String day = '$namespace|${local.year}-${local.month}-${local.day}';
    TrajectoryScenarioOutcome? keepGoing;
    for (final TrajectoryScenarioOutcome outcome in comparison.outcomes) {
      if (outcome.intervention.type ==
          TrajectoryInterventionType.maintainCourse) {
        keepGoing = outcome;
        break;
      }
    }
    final String? checkKey = _checked.add(day) ? day : null;
    final String rangeKey = '$day|${keepGoing?.intervention.horizon.inDays}';
    final String? recordKey = keepGoing != null && _recorded.add(rangeKey)
        ? rangeKey
        : null;
    if (checkKey == null && recordKey == null) return;
    unawaited(
      _run(
        operation: operation,
        repository: _ref.read(trajectoryForecastLedgerRepositoryProvider),
        comparison: comparison,
        keepGoing: recordKey == null ? null : keepGoing,
        now: now,
        checkKey: checkKey,
        recordKey: recordKey,
      ),
    );
  }

  Future<void> _run({
    required AccountOperation operation,
    required TrajectoryForecastLedgerRepository repository,
    required TrajectoryComparison comparison,
    required TrajectoryScenarioOutcome? keepGoing,
    required DateTime now,
    required String? checkKey,
    required String? recordKey,
  }) async {
    try {
      // Leave the provider build that reported the comparison first.
      await Future<void>.value();
      operation.check();
      bool changed = false;
      if (checkKey != null) {
        final int checked = await repository.reconcileDue(
          comparison.baseline,
          pressureForHorizon: trajectoryRangeWorkload(comparison.baseline),
          isCurrent: () => operation.isCurrent,
        );
        operation.check();
        changed = checked > 0;
      }
      if (keepGoing != null) {
        final bool stored = await repository.appendAutomatic(
          TrajectoryForecastReceipt.fromScenario(
            baseline: comparison.baseline,
            outcome: keepGoing,
            selectedAt: now,
            origin: TrajectoryForecastOrigin.automatic,
          ),
          isCurrent: () => operation.isCurrent,
        );
        operation.check();
        changed = changed || stored;
      }
      if (changed) _ref.invalidate(trajectoryForecastLedgerProvider);
    } on StaleAccountOperation {
      // The account changed: nothing was written for this attempt, so allow
      // it again for this account and day.
      if (checkKey != null) _checked.remove(checkKey);
      if (recordKey != null) _recorded.remove(recordKey);
    } on Object catch (error) {
      // Storage or data failed: keep the memo, so it is tried again on the
      // next local day or after a restart, not on every rebuild.
      Logger.warn('Automatic forecast recording failed: ${error.runtimeType}.');
    }
  }
}
