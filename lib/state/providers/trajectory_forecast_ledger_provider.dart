import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
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
