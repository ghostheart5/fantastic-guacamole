import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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

class TrajectoryForecastLedgerActions {
  const TrajectoryForecastLedgerActions(this._ref);

  final Ref _ref;

  Future<bool> track({
    required TrajectoryBaseline baseline,
    required TrajectoryScenarioOutcome outcome,
  }) async {
    final bool stored = await _ref
        .read(trajectoryForecastLedgerRepositoryProvider)
        .append(
          TrajectoryForecastReceipt.fromScenario(
            baseline: baseline,
            outcome: outcome,
            selectedAt: DateTime.now().toUtc(),
          ),
        );
    if (stored) _ref.invalidate(trajectoryForecastLedgerProvider);
    return stored;
  }

  Future<int> reconcile(TrajectoryBaseline baseline) async {
    final int count = await _ref
        .read(trajectoryForecastLedgerRepositoryProvider)
        .reconcileDue(baseline);
    if (count > 0) _ref.invalidate(trajectoryForecastLedgerProvider);
    return count;
  }
}
