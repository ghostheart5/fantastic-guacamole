// CHRONOSPARK-CLASS: SHIPPING | Feature: Trajectory forecasting
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';

class TrajectoryObservedOutcome {
  const TrajectoryObservedOutcome({
    required this.observedAt,
    required this.momentum,
    required this.pressure,
    required this.completedInWindow,
    required this.deferredInWindow,
  });

  final DateTime observedAt;
  final int momentum;
  final int pressure;
  final int completedInWindow;
  final int deferredInWindow;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'observedAt': observedAt.toUtc().toIso8601String(),
    'momentum': momentum,
    'pressure': pressure,
    'completedInWindow': completedInWindow,
    'deferredInWindow': deferredInWindow,
  };

  factory TrajectoryObservedOutcome.fromJson(Map<String, dynamic> json) =>
      TrajectoryObservedOutcome(
        observedAt: _requiredDate(json['observedAt'], 'observedAt'),
        momentum: _integer(json['momentum'], 'momentum').clamp(0, 100),
        pressure: _integer(json['pressure'], 'pressure').clamp(0, 100),
        completedInWindow: _integer(
          json['completedInWindow'],
          'completedInWindow',
        ).clamp(0, 1000000),
        deferredInWindow: _integer(
          json['deferredInWindow'],
          'deferredInWindow',
        ).clamp(0, 1000000),
      );
}

/// How a forecast receipt was recorded: by the person tapping "Track this
/// path", or automatically on the device (the keep-going forecast, at most
/// once per range per local day).
enum TrajectoryForecastOrigin { manual, automatic }

/// The receipt schema that added the optional `origin`, `earlierMethodAt`,
/// `calibrationMultiplier`, `unadjustedUncertainty` and `missedAt` fields. A
/// receipt carrying any of
/// them is written as this schema (as
/// [TrajectoryForecastReceipt.markAssumptionsCorrected] raises a receipt to
/// schema 2); receipts without them keep their schema number and their exact
/// JSON, so untouched stored receipts round-trip byte for byte. Older readers
/// ignore these fields.
const int trajectoryForecastReceiptOriginSchemaVersion = 3;

/// Immutable, account-local evidence that a user tracked a conditional model.
/// It stores model assumptions but no task titles.
class TrajectoryForecastReceipt {
  TrajectoryForecastReceipt({
    required this.id,
    required this.accountScope,
    required this.baselineRevision,
    required this.scenarioId,
    required this.interventionType,
    required this.generatedAt,
    required this.selectedAt,
    required this.horizon,
    required this.projectedMomentum,
    required this.projectedPressure,
    required this.uncertainty,
    required this.projectedRiskScore,
    required this.confidenceBand,
    required this.modelVersion,
    List<String> assumptions = const <String>[],
    this.personContextRevision,
    List<String> personContextSignalIds = const <String>[],
    this.assumptionsCorrectedAt,
    this.observed,
    this.origin = TrajectoryForecastOrigin.manual,
    this.earlierMethodAt,
    this.calibrationMultiplier = 1.0,
    this.missedAt,
    this.rawUncertainty,
    this.schemaVersion = 2,
  }) : assumptions = List<String>.unmodifiable(assumptions),
       personContextSignalIds = List<String>.unmodifiable(
         personContextSignalIds,
       );

  factory TrajectoryForecastReceipt.fromScenario({
    required TrajectoryBaseline baseline,
    required TrajectoryScenarioOutcome outcome,
    required DateTime selectedAt,
    TrajectoryForecastOrigin origin = TrajectoryForecastOrigin.manual,
  }) => TrajectoryForecastReceipt(
    id: '${outcome.id}:${selectedAt.toUtc().microsecondsSinceEpoch}',
    accountScope: baseline.accountScope,
    baselineRevision: baseline.revision,
    scenarioId: outcome.id,
    interventionType: outcome.intervention.type,
    generatedAt: outcome.generatedAt.toUtc(),
    selectedAt: selectedAt.toUtc(),
    horizon: outcome.intervention.horizon,
    projectedMomentum: outcome.projectedMomentum,
    projectedPressure: outcome.projectedPressure,
    uncertainty: outcome.uncertainty,
    projectedRiskScore: outcome.risk.projectedScore,
    confidenceBand: outcome.confidence.band,
    modelVersion: outcome.modelVersion,
    assumptions: outcome.assumptions,
    personContextRevision: baseline.personContextWarnings.isEmpty
        ? null
        : baseline.sourceRevisions['person_context_trajectory'],
    personContextSignalIds: _traceSignalIds(baseline.personContextTrace),
    origin: origin,
    calibrationMultiplier: outcome.calibrationMultiplier,
    // Stored whenever a multiplier was applied (even when the clamp made the
    // shown width equal to it, as for every 90-day range), and whenever it
    // differs from the shown width.
    rawUncertainty:
        outcome.calibrationMultiplier != 1.0 ||
            outcome.unadjustedUncertainty != outcome.uncertainty
        ? outcome.unadjustedUncertainty
        : null,
    schemaVersion:
        origin == TrajectoryForecastOrigin.automatic ||
            outcome.calibrationMultiplier != 1.0
        ? trajectoryForecastReceiptOriginSchemaVersion
        : 2,
  );

  final String id;
  final String accountScope;
  final String baselineRevision;
  final String scenarioId;
  final TrajectoryInterventionType interventionType;
  final DateTime generatedAt;
  final DateTime selectedAt;
  final Duration horizon;
  final int projectedMomentum;
  final int projectedPressure;
  final int uncertainty;
  final int projectedRiskScore;
  final PredictiveConfidenceBand confidenceBand;
  final String modelVersion;
  final List<String> assumptions;
  final String? personContextRevision;
  final List<String> personContextSignalIds;
  final DateTime? assumptionsCorrectedAt;
  final TrajectoryObservedOutcome? observed;
  final TrajectoryForecastOrigin origin;

  /// When this forecast fell due but was made by an earlier model version,
  /// so no observation measured the current way was written against it. It
  /// stays in the ledger, unresolved, and is never used for calibration.
  final DateTime? earlierMethodAt;

  /// The multiplier recorded accuracy applied to [uncertainty] when this
  /// forecast was made (1.0 when none was applied, and on every receipt
  /// written before it existed).
  final double calibrationMultiplier;

  /// When this forecast was found too long after it fell due (more than
  /// max(1, H / 7) local days late, H its range in days): no observation was
  /// written against it, and it is never used for calibration.
  final DateTime? missedAt;

  /// The engine's own width (after the engine's clamp to 8..42, before any
  /// recorded-accuracy multiplier), stored as `unadjustedUncertainty`
  /// whenever a multiplier was applied. Null on receipts made with no
  /// multiplier, where it equals [uncertainty].
  final int? rawUncertainty;
  final int schemaVersion;

  /// The engine's own width before recorded accuracy changed it. Coverage is
  /// judged against this, so the rule never measures its own output:
  /// - the stored [rawUncertainty] when present (no reconstruction);
  /// - [uncertainty] when no multiplier was applied (every released and
  ///   Task-3 receipt);
  /// - otherwise, only for development receipts written between the two
  ///   review rounds, uncertainty / multiplier (wrong when that width had
  ///   been clamped).
  int get unadjustedUncertainty =>
      rawUncertainty ??
      (calibrationMultiplier == 1.0
          ? uncertainty
          : (uncertainty / calibrationMultiplier).round());

  DateTime get dueAt => selectedAt.add(horizon);
  bool get isResolved => observed != null;
  bool get isAutomatic => origin == TrajectoryForecastOrigin.automatic;

  /// Nothing more will be written against this forecast: it was checked, it
  /// fell due under an earlier method, or its check was missed.
  bool get isSettled =>
      isResolved || earlierMethodAt != null || missedAt != null;

  /// Local calendar days from this forecast's due day (its local selection
  /// day plus its range) to [at]'s local day: negative before it is due, 0 on
  /// the due day itself.
  int localDaysPastDue(DateTime at) {
    final DateTime selected = selectedAt.toLocal();
    final DateTime checked = at.toLocal();
    return DateTime.utc(checked.year, checked.month, checked.day)
        .difference(
          DateTime.utc(
            selected.year,
            selected.month,
            selected.day + horizon.inDays,
          ),
        )
        .inDays;
  }

  /// Local days after the due day within which a check still counts:
  /// max(1, H / 7) for a range of H days.
  int get allowedDaysLate {
    final int weeks = horizon.inDays ~/ 7;
    return weeks < 1 ? 1 : weeks;
  }

  bool get hasAssumptionCorrection => assumptionsCorrectedAt != null;

  /// Whether this forecast was made by [version] of the model, so its figures
  /// mean the same as that version's.
  bool isMethod(String version) => modelVersion == version;

  /// Whether this receipt can be used to judge [version]'s accuracy: made by
  /// that version, checked, and with its assumptions uncorrected.
  bool isCalibrationEvidence(String version) =>
      isMethod(version) && isResolved && !hasAssumptionCorrection;
  bool isDueAt(DateTime value) => !value.toUtc().isBefore(dueAt.toUtc());

  TrajectoryForecastReceipt resolve(TrajectoryObservedOutcome value) =>
      _copy(observed: value);

  /// Settles a due forecast made by an earlier model version without writing
  /// an observation measured a different way against it.
  TrajectoryForecastReceipt markEarlierMethod(DateTime at) => _copy(
    earlierMethodAt: at.toUtc(),
    schemaAtLeast: trajectoryForecastReceiptOriginSchemaVersion,
  );

  TrajectoryForecastReceipt markAssumptionsCorrected(DateTime correctedAt) =>
      _copy(assumptionsCorrectedAt: correctedAt.toUtc(), schemaAtLeast: 2);

  /// Settles a forecast found too long after it fell due, without writing an
  /// observation from a different moment against it.
  TrajectoryForecastReceipt markMissed(DateTime at) => _copy(
    missedAt: at.toUtc(),
    schemaAtLeast: trajectoryForecastReceiptOriginSchemaVersion,
  );

  /// This receipt with the given fields set; everything else is kept.
  TrajectoryForecastReceipt _copy({
    DateTime? assumptionsCorrectedAt,
    TrajectoryObservedOutcome? observed,
    DateTime? earlierMethodAt,
    DateTime? missedAt,
    int schemaAtLeast = 1,
  }) => TrajectoryForecastReceipt(
    id: id,
    accountScope: accountScope,
    baselineRevision: baselineRevision,
    scenarioId: scenarioId,
    interventionType: interventionType,
    generatedAt: generatedAt,
    selectedAt: selectedAt,
    horizon: horizon,
    projectedMomentum: projectedMomentum,
    projectedPressure: projectedPressure,
    uncertainty: uncertainty,
    projectedRiskScore: projectedRiskScore,
    confidenceBand: confidenceBand,
    modelVersion: modelVersion,
    assumptions: assumptions,
    personContextRevision: personContextRevision,
    personContextSignalIds: personContextSignalIds,
    assumptionsCorrectedAt:
        assumptionsCorrectedAt ?? this.assumptionsCorrectedAt,
    observed: observed ?? this.observed,
    origin: origin,
    earlierMethodAt: earlierMethodAt ?? this.earlierMethodAt,
    calibrationMultiplier: calibrationMultiplier,
    missedAt: missedAt ?? this.missedAt,
    rawUncertainty: rawUncertainty,
    schemaVersion: schemaVersion < schemaAtLeast
        ? schemaAtLeast
        : schemaVersion,
  );

  void validate() {
    if (id.trim().isEmpty ||
        accountScope.trim().isEmpty ||
        baselineRevision.trim().isEmpty ||
        scenarioId.trim().isEmpty ||
        modelVersion.trim().isEmpty) {
      throw const FormatException('Forecast receipt identifiers are required.');
    }
    if (horizon <= Duration.zero ||
        uncertainty < 0 ||
        (rawUncertainty != null && rawUncertainty! < 0)) {
      throw const FormatException('Forecast receipt range is invalid.');
    }
    if (projectedMomentum < 0 ||
        projectedMomentum > 100 ||
        projectedPressure < 0 ||
        projectedPressure > 100 ||
        projectedRiskScore < 0 ||
        projectedRiskScore > 100 ||
        schemaVersion < 1 ||
        !(calibrationMultiplier > 0) ||
        calibrationMultiplier > 10) {
      throw const FormatException('Forecast receipt values are invalid.');
    }
    if (assumptionsCorrectedAt != null &&
        assumptionsCorrectedAt!.toUtc().isBefore(selectedAt.toUtc())) {
      throw const FormatException(
        'Forecast assumption correction cannot predate selection.',
      );
    }
    if (earlierMethodAt != null &&
        earlierMethodAt!.toUtc().isBefore(selectedAt.toUtc())) {
      throw const FormatException(
        'Forecast earlier-method mark cannot predate selection.',
      );
    }
    if (missedAt != null && missedAt!.toUtc().isBefore(selectedAt.toUtc())) {
      throw const FormatException(
        'Forecast missed mark cannot predate selection.',
      );
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'id': id,
    'accountScope': accountScope,
    'baselineRevision': baselineRevision,
    'scenarioId': scenarioId,
    'interventionType': interventionType.name,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'selectedAt': selectedAt.toUtc().toIso8601String(),
    'horizonSeconds': horizon.inSeconds,
    'projectedMomentum': projectedMomentum,
    'projectedPressure': projectedPressure,
    'uncertainty': uncertainty,
    'projectedRiskScore': projectedRiskScore,
    'confidenceBand': confidenceBand.name,
    'modelVersion': modelVersion,
    'assumptions': assumptions,
    'personContextRevision': personContextRevision,
    'personContextSignalIds': personContextSignalIds,
    'assumptionsCorrectedAt': assumptionsCorrectedAt?.toUtc().toIso8601String(),
    'observed': observed?.toJson(),
    // Optional schema-3 fields, written only when set so that every other
    // receipt keeps its exact JSON.
    if (origin == TrajectoryForecastOrigin.automatic) 'origin': origin.name,
    if (earlierMethodAt != null)
      'earlierMethodAt': earlierMethodAt!.toUtc().toIso8601String(),
    if (calibrationMultiplier != 1.0)
      'calibrationMultiplier': calibrationMultiplier,
    if (missedAt != null) 'missedAt': missedAt!.toUtc().toIso8601String(),
    if (rawUncertainty != null) 'unadjustedUncertainty': rawUncertainty,
  };

  factory TrajectoryForecastReceipt.fromJson(Map<String, dynamic> json) {
    final TrajectoryForecastReceipt receipt = TrajectoryForecastReceipt(
      id: _requiredString(json['id'], 'id'),
      accountScope: _requiredString(json['accountScope'], 'accountScope'),
      baselineRevision: _requiredString(
        json['baselineRevision'],
        'baselineRevision',
      ),
      scenarioId: _requiredString(json['scenarioId'], 'scenarioId'),
      interventionType: _enumByName(
        TrajectoryInterventionType.values,
        json['interventionType'],
        'interventionType',
      ),
      generatedAt: _requiredDate(json['generatedAt'], 'generatedAt'),
      selectedAt: _requiredDate(json['selectedAt'], 'selectedAt'),
      horizon: Duration(
        seconds: _integer(json['horizonSeconds'], 'horizonSeconds'),
      ),
      projectedMomentum: _integer(
        json['projectedMomentum'],
        'projectedMomentum',
      ).clamp(0, 100),
      projectedPressure: _integer(
        json['projectedPressure'],
        'projectedPressure',
      ).clamp(0, 100),
      uncertainty: _integer(json['uncertainty'], 'uncertainty'),
      projectedRiskScore: _integer(
        json['projectedRiskScore'],
        'projectedRiskScore',
      ).clamp(0, 100),
      confidenceBand: _enumByName(
        PredictiveConfidenceBand.values,
        json['confidenceBand'],
        'confidenceBand',
      ),
      modelVersion: _requiredString(json['modelVersion'], 'modelVersion'),
      assumptions: json['assumptions'] is List
          ? (json['assumptions'] as List)
                .map((Object? item) => item?.toString().trim() ?? '')
                .where((String item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      personContextRevision: json['personContextRevision']?.toString(),
      personContextSignalIds: json['personContextSignalIds'] is List
          ? (json['personContextSignalIds'] as List)
                .map((Object? item) => item?.toString().trim() ?? '')
                .where((String item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      assumptionsCorrectedAt: json['assumptionsCorrectedAt'] == null
          ? null
          : _requiredDate(
              json['assumptionsCorrectedAt'],
              'assumptionsCorrectedAt',
            ),
      observed: json['observed'] is Map
          ? TrajectoryObservedOutcome.fromJson(
              Map<String, dynamic>.from(json['observed'] as Map),
            )
          : null,
      // Absent or unknown means the person tracked it.
      origin: json['origin'] == TrajectoryForecastOrigin.automatic.name
          ? TrajectoryForecastOrigin.automatic
          : TrajectoryForecastOrigin.manual,
      earlierMethodAt: json['earlierMethodAt'] == null
          ? null
          : _requiredDate(json['earlierMethodAt'], 'earlierMethodAt'),
      // Absent means no recorded accuracy was applied.
      calibrationMultiplier: json['calibrationMultiplier'] == null
          ? 1.0
          : _number(json['calibrationMultiplier'], 'calibrationMultiplier'),
      missedAt: json['missedAt'] == null
          ? null
          : _requiredDate(json['missedAt'], 'missedAt'),
      rawUncertainty: json['unadjustedUncertainty'] == null
          ? null
          : _integer(json['unadjustedUncertainty'], 'unadjustedUncertainty'),
      schemaVersion: _integer(json['schemaVersion'] ?? 1, 'schemaVersion'),
    );
    receipt.validate();
    return receipt;
  }
}

/// What one pass over the due forecasts did: [checked] were measured against
/// the records; [setAside] fell due but could not be measured the same way
/// (an earlier method, found too late, or corrected assumptions) and are
/// kept unused.
class TrajectoryReconcileCounts {
  const TrajectoryReconcileCounts({this.checked = 0, this.setAside = 0});

  static const TrajectoryReconcileCounts none = TrajectoryReconcileCounts();

  final int checked;
  final int setAside;

  /// Receipts changed by the pass.
  int get total => checked + setAside;
}

class TrajectoryCalibrationSummary {
  const TrajectoryCalibrationSummary({
    required this.resolvedForecasts,
    required this.momentumMeanAbsoluteError,
    required this.pressureMeanAbsoluteError,
    required this.intervalCoverage,
    required this.state,
    this.earlierMethodForecasts = 0,
    this.correctedForecasts = 0,
    this.missedForecasts = 0,
    this.accountScope,
    this.checkDays = 0,
    this.checkSpanDays = 0,
  });

  /// Uses only checked, uncorrected forecasts of [modelVersion] (the current
  /// model by default), so every error and coverage figure compares like with
  /// like. Forecasts made by an earlier model version are kept in the ledger
  /// and counted in [earlierMethodForecasts], never used; current-version
  /// forecasts whose assumptions were corrected are counted in
  /// [correctedForecasts], never used.
  factory TrajectoryCalibrationSummary.fromReceipts(
    Iterable<TrajectoryForecastReceipt> receipts, {
    String modelVersion = trajectoryConsequenceModelVersion,
  }) {
    final List<TrajectoryForecastReceipt> all = receipts.toList(
      growable: false,
    );
    final String? accountScope = all.isEmpty ? null : all.first.accountScope;
    final int earlierMethod = all
        .where((TrajectoryForecastReceipt item) => !item.isMethod(modelVersion))
        .length;
    final int corrected = all
        .where(
          (TrajectoryForecastReceipt item) =>
              item.isMethod(modelVersion) && item.hasAssumptionCorrection,
        )
        .length;
    final int missed = all
        .where(
          (TrajectoryForecastReceipt item) =>
              item.isMethod(modelVersion) &&
              !item.hasAssumptionCorrection &&
              item.missedAt != null,
        )
        .length;
    final List<TrajectoryForecastReceipt> resolved = all
        .where(
          (TrajectoryForecastReceipt item) =>
              item.isCalibrationEvidence(modelVersion),
        )
        .toList(growable: false);
    if (resolved.isEmpty) {
      return TrajectoryCalibrationSummary(
        resolvedForecasts: 0,
        momentumMeanAbsoluteError: 0,
        pressureMeanAbsoluteError: 0,
        intervalCoverage: 0,
        state: PredictiveCalibrationState.provisional,
        earlierMethodForecasts: earlierMethod,
        correctedForecasts: corrected,
        missedForecasts: missed,
        accountScope: accountScope,
      );
    }
    double momentumError = 0;
    double pressureError = 0;
    // Forecasts checked on the same local day are checked against the same
    // moment, so independent evidence is counted by distinct check days, and
    // coverage is the average of each check day's share: a cluster of
    // forecasts checked on one day counts as one day.
    final Map<DateTime, List<bool>> coveredByDay = <DateTime, List<bool>>{};
    for (final TrajectoryForecastReceipt receipt in resolved) {
      final TrajectoryObservedOutcome actual = receipt.observed!;
      momentumError += (receipt.projectedMomentum - actual.momentum).abs();
      pressureError += (receipt.projectedPressure - actual.pressure).abs();
      // The engine's own width, before any recorded-accuracy multiplier, so
      // the rule never measures its own output.
      final int width = receipt.unadjustedUncertainty;
      final int lower = (receipt.projectedMomentum - width).clamp(0, 100);
      final int upper = (receipt.projectedMomentum + width).clamp(0, 100);
      final DateTime local = actual.observedAt.toLocal();
      coveredByDay
          .putIfAbsent(
            DateTime.utc(local.year, local.month, local.day),
            () => <bool>[],
          )
          .add(actual.momentum >= lower && actual.momentum <= upper);
    }
    final List<DateTime> checkDays = coveredByDay.keys.toList()..sort();
    final double coverage =
        coveredByDay.values
            .map(
              (List<bool> day) => day.where((bool c) => c).length / day.length,
            )
            .reduce((double a, double b) => a + b) /
        coveredByDay.length;
    return TrajectoryCalibrationSummary(
      resolvedForecasts: resolved.length,
      momentumMeanAbsoluteError: momentumError / resolved.length,
      pressureMeanAbsoluteError: pressureError / resolved.length,
      intervalCoverage: coverage,
      state: PredictiveCalibrationState.monitored,
      earlierMethodForecasts: earlierMethod,
      correctedForecasts: corrected,
      missedForecasts: missed,
      accountScope: accountScope,
      checkDays: checkDays.length,
      checkSpanDays: checkDays.last.difference(checkDays.first).inDays,
    );
  }

  /// Distinct local days on which the used forecasts were checked.
  final int checkDays;

  /// Local days from the first to the last of those check days.
  final int checkSpanDays;

  /// Checked, uncorrected forecasts of the current model version: the only
  /// ones used.
  final int resolvedForecasts;
  final double momentumMeanAbsoluteError;
  final double pressureMeanAbsoluteError;
  final double intervalCoverage;
  final PredictiveCalibrationState state;

  /// Forecasts made by an earlier model version: kept but not used.
  final int earlierMethodForecasts;

  /// Current-version forecasts whose assumptions were corrected: kept but
  /// not used.
  final int correctedForecasts;

  /// Current-version forecasts found too long after they fell due: kept but
  /// not used.
  final int missedForecasts;

  /// Whether any forecast fell due but was set aside unchecked.
  bool get hasSetAside =>
      earlierMethodForecasts > 0 ||
      correctedForecasts > 0 ||
      missedForecasts > 0;

  /// The account whose ledger was summarised; null when it was empty.
  final String? accountScope;
}

String _requiredString(Object? value, String field) {
  final String result = value?.toString().trim() ?? '';
  if (result.isEmpty) throw FormatException('$field is required.');
  return result;
}

DateTime _requiredDate(Object? value, String field) {
  final DateTime? result = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  if (result == null) throw FormatException('$field is invalid.');
  return result;
}

double _number(Object? value, String field) {
  if (value is num) return value.toDouble();
  final double? result = double.tryParse(value?.toString() ?? '');
  if (result == null) throw FormatException('$field is invalid.');
  return result;
}

int _integer(Object? value, String field) {
  if (value is num) return value.toInt();
  final int? result = int.tryParse(value?.toString() ?? '');
  if (result == null) throw FormatException('$field is invalid.');
  return result;
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String field) {
  final String name = _requiredString(raw, field);
  for (final T value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('$field is unsupported.');
}

List<String> _traceSignalIds(Map<String, Object?> trace) {
  final Object? used = trace['used'];
  if (used is! List) return const <String>[];
  final Set<String> ids = used
      .whereType<Map<Object?, Object?>>()
      .map(
        (Map<Object?, Object?> item) =>
            item['signalId']?.toString().trim() ?? '',
      )
      .where((String id) => id.isNotEmpty)
      .toSet();
  return ids.toList(growable: false)..sort();
}
