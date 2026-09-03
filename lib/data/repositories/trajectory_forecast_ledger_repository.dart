import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';

/// Account-scoped, bounded evidence ledger for forecast monitoring.
class TrajectoryForecastLedgerRepository
    implements ITrajectoryForecastLedgerRepository {
  const TrajectoryForecastLedgerRepository({
    required this.store,
    required this.scope,
    this.maximumReceipts = 120,
  });

  final SharedPrefsStore store;
  final AccountStorageScope scope;
  final int maximumReceipts;

  String? get storageKey {
    final String? namespace = scope.v2Namespace;
    if (!scope.isWritable || namespace == null) return null;
    return 'chronospark.trajectory.forecast_ledger.v1.$namespace';
  }

  @override
  Future<List<TrajectoryForecastReceipt>> load() async {
    final String? key = storageKey;
    if (key == null) return const <TrajectoryForecastReceipt>[];
    await store.init();
    final String? raw = store.load(key);
    if (raw == null || raw.trim().isEmpty) {
      return const <TrajectoryForecastReceipt>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Ledger is not a map.');
      final Object? records = decoded['records'];
      if (records is! List) {
        throw const FormatException('Ledger records are missing.');
      }
      final List<TrajectoryForecastReceipt> valid =
          <TrajectoryForecastReceipt>[];
      final List<Object?> rejected = <Object?>[];
      for (final Object? record in records) {
        try {
          if (record is! Map) {
            throw const FormatException('Record is not a map.');
          }
          final TrajectoryForecastReceipt receipt =
              TrajectoryForecastReceipt.fromJson(
                Map<String, dynamic>.from(record),
              );
          if (receipt.accountScope != scope.v2Namespace) {
            throw const FormatException(
              'Record belongs to another account scope.',
            );
          }
          valid.add(receipt);
        } on Object {
          rejected.add(record);
        }
      }
      if (rejected.isNotEmpty) {
        await _quarantine(key, jsonEncode(rejected));
        await _save(valid);
      }
      valid.sort(
        (TrajectoryForecastReceipt a, TrajectoryForecastReceipt b) =>
            b.selectedAt.compareTo(a.selectedAt),
      );
      return List<TrajectoryForecastReceipt>.unmodifiable(valid);
    } on Object {
      await _quarantine(key, raw);
      await _save(const <TrajectoryForecastReceipt>[]);
      return const <TrajectoryForecastReceipt>[];
    }
  }

  @override
  Future<bool> append(TrajectoryForecastReceipt receipt) async {
    final String? key = storageKey;
    if (key == null || receipt.accountScope != scope.v2Namespace) return false;
    receipt.validate();
    final List<TrajectoryForecastReceipt> existing = await load();
    final List<TrajectoryForecastReceipt> next = <TrajectoryForecastReceipt>[
      receipt,
      ...existing.where(
        (TrajectoryForecastReceipt item) => item.id != receipt.id,
      ),
    ];
    await _save(next);
    return true;
  }

  Future<bool> recordAssumptionCorrection({
    required TrajectoryBaseline baseline,
    required TrajectoryScenarioOutcome outcome,
    required DateTime correctedAt,
  }) async {
    final String? key = storageKey;
    if (key == null || baseline.accountScope != scope.v2Namespace) return false;

    final DateTime correctedAtUtc = correctedAt.toUtc();
    final List<TrajectoryForecastReceipt> existing = await load();
    bool matched = false;
    final List<TrajectoryForecastReceipt> corrected = existing
        .map((receipt) {
          final bool isSameForecast =
              receipt.baselineRevision == baseline.revision &&
              receipt.scenarioId == outcome.id;
          if (!isSameForecast) return receipt;
          matched = true;
          if (receipt.hasAssumptionCorrection) return receipt;
          return receipt.markAssumptionsCorrected(correctedAtUtc);
        })
        .toList(growable: true);

    if (!matched) {
      corrected.add(
        TrajectoryForecastReceipt.fromScenario(
          baseline: baseline,
          outcome: outcome,
          selectedAt: correctedAtUtc,
        ).markAssumptionsCorrected(correctedAtUtc),
      );
    }
    await _save(corrected);
    return true;
  }

  @override
  Future<int> reconcileDue(TrajectoryBaseline current) async {
    if (storageKey == null || current.accountScope != scope.v2Namespace) {
      return 0;
    }
    final List<TrajectoryForecastReceipt> receipts = await load();
    int resolved = 0;
    final List<TrajectoryForecastReceipt> next = receipts
        .map((receipt) {
          final String currentContextRevision =
              current.sourceRevisions['person_context_trajectory'] ??
              'unavailable';
          final bool contextChanged =
              receipt.personContextRevision != null &&
              receipt.personContextRevision != currentContextRevision;
          if (contextChanged && !receipt.hasAssumptionCorrection) {
            resolved++;
            final DateTime correctedAt =
                current.observedAt.isBefore(receipt.selectedAt)
                ? receipt.selectedAt
                : current.observedAt;
            return receipt.markAssumptionsCorrected(correctedAt);
          }
          if (receipt.isResolved || !receipt.isDueAt(current.observedAt)) {
            return receipt;
          }
          resolved++;
          return receipt.resolve(
            TrajectoryObservedOutcome(
              observedAt: current.observedAt,
              momentum: current.momentum,
              pressure: current.pressure,
              completedInWindow: current.completedInWindow,
              deferredInWindow: current.deferredInWindow,
            ),
          );
        })
        .toList(growable: false);
    if (resolved > 0) await _save(next);
    return resolved;
  }

  Future<void> _save(List<TrajectoryForecastReceipt> receipts) async {
    final String? key = storageKey;
    if (key == null) return;
    final List<TrajectoryForecastReceipt> ordered =
        <TrajectoryForecastReceipt>[...receipts]..sort(
          (TrajectoryForecastReceipt a, TrajectoryForecastReceipt b) =>
              b.selectedAt.compareTo(a.selectedAt),
        );
    final List<TrajectoryForecastReceipt> bounded =
        ordered.length <= maximumReceipts
        ? ordered
        : ordered.sublist(0, maximumReceipts);
    await store.save(
      key,
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'records': bounded
            .map((TrajectoryForecastReceipt item) => item.toJson())
            .toList(growable: false),
      }),
    );
  }

  Future<void> _quarantine(String key, String raw) {
    final String timestamp = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toString();
    return store.save('$key.corrupt.$timestamp', raw);
  }
}
