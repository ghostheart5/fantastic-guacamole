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

  /// Stores [receipt]. [isCurrent] is checked after the ledger is read and
  /// before anything is written: when it returns false (the account changed
  /// meanwhile) nothing is written.
  @override
  Future<bool> append(
    TrajectoryForecastReceipt receipt, {
    bool Function()? isCurrent,
  }) async {
    final String? key = storageKey;
    if (key == null || receipt.accountScope != scope.v2Namespace) return false;
    receipt.validate();
    final List<TrajectoryForecastReceipt> existing = await load();
    if (isCurrent != null && !isCurrent()) return false;
    final List<TrajectoryForecastReceipt> next = <TrajectoryForecastReceipt>[
      receipt,
      ...existing.where(
        (TrajectoryForecastReceipt item) => item.id != receipt.id,
      ),
    ];
    final List<TrajectoryForecastReceipt> kept = _bounded(next);
    if (!kept.contains(receipt)) return false;
    await _save(kept);
    return true;
  }

  /// Stores an automatic [receipt] unless an automatic receipt for the same
  /// range was recorded recently (the same local day for the 7-day range,
  /// the last 7 local days for the 30- and 90-day ranges), or there is no
  /// room for it under the cap without dropping checked evidence or an
  /// unchecked receipt (see [_bounded]). Returns whether it was stored.
  Future<bool> appendAutomatic(
    TrajectoryForecastReceipt receipt, {
    bool Function()? isCurrent,
  }) async {
    final String? key = storageKey;
    if (key == null ||
        !receipt.isAutomatic ||
        receipt.accountScope != scope.v2Namespace) {
      return false;
    }
    receipt.validate();
    final List<TrajectoryForecastReceipt> existing = await load();
    if (isCurrent != null && !isCurrent()) return false;
    final int interval = receipt.horizon.inDays > 7
        ? automaticLongRangeIntervalDays
        : 1;
    final bool recent = existing.any(
      (TrajectoryForecastReceipt item) =>
          item.isAutomatic &&
          item.horizon == receipt.horizon &&
          _localDaysBetween(item.selectedAt, receipt.selectedAt).abs() <
              interval,
    );
    if (recent) return false;
    final List<TrajectoryForecastReceipt> kept =
        _bounded(<TrajectoryForecastReceipt>[
          receipt,
          ...existing.where(
            (TrajectoryForecastReceipt item) => item.id != receipt.id,
          ),
        ]);
    if (!kept.contains(receipt)) return false;
    await _save(kept);
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

  /// Settles the forecasts that are due at [current].observedAt.
  ///
  /// Like with like: a forecast of the current model version with range H is
  /// checked against the workload over that same range length measured now
  /// ([pressureForHorizon] for H; without it, the baseline's own range or
  /// next-7-days figure when H matches, otherwise the forecast is left for a
  /// later check). A due forecast of an earlier model version gets no
  /// observation measured a different way: it is marked as settled under an
  /// earlier method and kept. [isCurrent] is checked after the ledger is read
  /// and before anything is written.
  @override
  Future<int> reconcileDue(
    TrajectoryBaseline current, {
    int Function(int horizonDays)? pressureForHorizon,
    bool Function()? isCurrent,
    String modelVersion = trajectoryConsequenceModelVersion,
  }) async {
    if (storageKey == null || current.accountScope != scope.v2Namespace) {
      return 0;
    }
    final List<TrajectoryForecastReceipt> receipts = await load();
    if (isCurrent != null && !isCurrent()) return 0;
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
          if (receipt.isSettled || !receipt.isDueAt(current.observedAt)) {
            return receipt;
          }
          if (!receipt.isMethod(modelVersion)) {
            resolved++;
            return receipt.markEarlierMethod(current.observedAt);
          }
          final int? pressure = _observedPressure(
            receipt,
            current,
            pressureForHorizon,
          );
          if (pressure == null) return receipt;
          resolved++;
          return receipt.resolve(
            TrajectoryObservedOutcome(
              observedAt: current.observedAt,
              momentum: current.momentum,
              pressure: pressure,
              completedInWindow: current.completedInWindow,
              deferredInWindow: current.deferredInWindow,
            ),
          );
        })
        .toList(growable: false);
    if (resolved > 0) await _save(next);
    return resolved;
  }

  /// The workload over the receipt's own range length, measured now; null
  /// when it cannot be measured the same way.
  static int? _observedPressure(
    TrajectoryForecastReceipt receipt,
    TrajectoryBaseline current,
    int Function(int horizonDays)? pressureForHorizon,
  ) {
    final int days = receipt.horizon.inDays < 1 ? 1 : receipt.horizon.inDays;
    if (pressureForHorizon != null) {
      return pressureForHorizon(days).clamp(0, 100);
    }
    if (days == current.horizonDays) return current.pressureInHorizon;
    if (days == 7) return current.pressure;
    return null;
  }

  /// Keeps at most [maximumReceipts], newest first. When some must go, they
  /// go in this order:
  /// 1. receipts that are not calibration evidence and are settled (due under
  ///    an earlier method, missed, or corrected), oldest settled first;
  /// 2. checked current-version receipts beyond the newest
  ///    [maximumReceipts] / 2 (the evidence floor), earliest checked first;
  /// 3. unchecked automatic receipts, newest first: a new automatic receipt is
  ///    simply not kept, and one already waiting for its check is kept;
  /// 4. the remaining checked current-version receipts, earliest checked
  ///    first;
  /// 5. unchecked manual receipts, oldest first.
  /// So an unchecked manual receipt is never dropped while anything else could
  /// go, and an automatic receipt never pushes out the evidence floor.
  List<TrajectoryForecastReceipt> _bounded(
    List<TrajectoryForecastReceipt> receipts,
  ) {
    final List<TrajectoryForecastReceipt> ordered =
        <TrajectoryForecastReceipt>[...receipts]..sort(
          (TrajectoryForecastReceipt a, TrajectoryForecastReceipt b) =>
              b.selectedAt.compareTo(a.selectedAt),
        );
    int excess = ordered.length - maximumReceipts;
    if (excess <= 0) return ordered;
    final Set<TrajectoryForecastReceipt> dropped =
        Set<TrajectoryForecastReceipt>.identity();
    bool isEvidence(TrajectoryForecastReceipt r) =>
        r.isCalibrationEvidence(trajectoryConsequenceModelVersion);
    DateTime settledAt(TrajectoryForecastReceipt r) =>
        r.observed?.observedAt ??
        r.earlierMethodAt ??
        r.assumptionsCorrectedAt ??
        r.selectedAt;
    List<TrajectoryForecastReceipt> earliestSettledFirst(
      bool Function(TrajectoryForecastReceipt) test,
    ) => ordered.where(test).toList()
      ..sort(
        (TrajectoryForecastReceipt a, TrajectoryForecastReceipt b) =>
            settledAt(a).compareTo(settledAt(b)),
      );
    void drop(Iterable<TrajectoryForecastReceipt> candidates, {int? limit}) {
      int allowed = limit ?? excess;
      for (final TrajectoryForecastReceipt receipt in candidates) {
        if (excess == 0 || allowed == 0) return;
        if (!dropped.add(receipt)) continue;
        excess--;
        allowed--;
      }
    }

    // 1. Settled, not evidence.
    drop(
      earliestSettledFirst(
        (TrajectoryForecastReceipt r) => r.isSettled && !isEvidence(r),
      ),
    );
    // 2. Evidence beyond the floor.
    final List<TrajectoryForecastReceipt> evidence = earliestSettledFirst(
      isEvidence,
    );
    final int floor = maximumReceipts ~/ 2;
    if (evidence.length > floor) drop(evidence, limit: evidence.length - floor);
    // 3. Unchecked automatic, newest first.
    drop(
      ordered.where(
        (TrajectoryForecastReceipt r) => !r.isSettled && r.isAutomatic,
      ),
    );
    // 4. The rest of the evidence.
    drop(evidence);
    // 5. Unchecked manual (and anything left), oldest first.
    drop(ordered.reversed);
    return ordered
        .where((TrajectoryForecastReceipt item) => !dropped.contains(item))
        .toList(growable: false);
  }

  /// Automatic 30- and 90-day receipts are recorded at most once in this many
  /// local days; 7-day ones at most once a local day.
  static const int automaticLongRangeIntervalDays = 7;

  /// Calendar days from [from]'s local day to [to]'s local day.
  static int _localDaysBetween(DateTime from, DateTime to) {
    final DateTime a = from.toLocal();
    final DateTime b = to.toLocal();
    return DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  Future<void> _save(List<TrajectoryForecastReceipt> receipts) async {
    final String? key = storageKey;
    if (key == null) return;
    final List<TrajectoryForecastReceipt> bounded = _bounded(receipts);
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
