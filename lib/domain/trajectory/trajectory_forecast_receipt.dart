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

/// The receipt schema that added the optional `origin` and `earlierMethodAt`
/// fields. A receipt carrying either is written as this schema (as
/// [TrajectoryForecastReceipt.markAssumptionsCorrected] raises a receipt to
/// schema 2); receipts without them keep their schema number and their exact
/// JSON, so untouched stored receipts round-trip byte for byte. Older readers
/// ignore both fields.
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
    schemaVersion: origin == TrajectoryForecastOrigin.automatic
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
  final int schemaVersion;

  DateTime get dueAt => selectedAt.add(horizon);
  bool get isResolved => observed != null;
  bool get isAutomatic => origin == TrajectoryForecastOrigin.automatic;

  /// Nothing more will be written against this forecast: it was checked, or
  /// it fell due under an earlier method.
  bool get isSettled => isResolved || earlierMethodAt != null;
  bool get hasAssumptionCorrection => assumptionsCorrectedAt != null;

  /// Whether this forecast was made by [version] of the model, so its figures
  /// mean the same as that version's.
  bool isMethod(String version) => modelVersion == version;
  bool isDueAt(DateTime value) => !value.toUtc().isBefore(dueAt.toUtc());

  TrajectoryForecastReceipt resolve(TrajectoryObservedOutcome value) =>
      TrajectoryForecastReceipt(
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
        assumptionsCorrectedAt: assumptionsCorrectedAt,
        observed: value,
        origin: origin,
        earlierMethodAt: earlierMethodAt,
        schemaVersion: schemaVersion,
      );

  /// Settles a due forecast made by an earlier model version without writing
  /// an observation measured a different way against it.
  TrajectoryForecastReceipt markEarlierMethod(DateTime at) =>
      TrajectoryForecastReceipt(
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
        assumptionsCorrectedAt: assumptionsCorrectedAt,
        observed: observed,
        origin: origin,
        earlierMethodAt: at.toUtc(),
        schemaVersion:
            schemaVersion < trajectoryForecastReceiptOriginSchemaVersion
            ? trajectoryForecastReceiptOriginSchemaVersion
            : schemaVersion,
      );

  TrajectoryForecastReceipt markAssumptionsCorrected(DateTime correctedAt) =>
      TrajectoryForecastReceipt(
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
        assumptionsCorrectedAt: correctedAt.toUtc(),
        observed: observed,
        origin: origin,
        earlierMethodAt: earlierMethodAt,
        schemaVersion: schemaVersion < 2 ? 2 : schemaVersion,
      );

  void validate() {
    if (id.trim().isEmpty ||
        accountScope.trim().isEmpty ||
        baselineRevision.trim().isEmpty ||
        scenarioId.trim().isEmpty ||
        modelVersion.trim().isEmpty) {
      throw const FormatException('Forecast receipt identifiers are required.');
    }
    if (horizon <= Duration.zero || uncertainty < 0) {
      throw const FormatException('Forecast receipt range is invalid.');
    }
    if (projectedMomentum < 0 ||
        projectedMomentum > 100 ||
        projectedPressure < 0 ||
        projectedPressure > 100 ||
        projectedRiskScore < 0 ||
        projectedRiskScore > 100 ||
        schemaVersion < 1) {
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
      schemaVersion: _integer(json['schemaVersion'] ?? 1, 'schemaVersion'),
    );
    receipt.validate();
    return receipt;
  }
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
    this.accountScope,
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
    final List<TrajectoryForecastReceipt> resolved = all
        .where(
          (TrajectoryForecastReceipt item) =>
              item.isMethod(modelVersion) &&
              item.observed != null &&
              !item.hasAssumptionCorrection,
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
        accountScope: accountScope,
      );
    }
    double momentumError = 0;
    double pressureError = 0;
    int covered = 0;
    for (final TrajectoryForecastReceipt receipt in resolved) {
      final TrajectoryObservedOutcome actual = receipt.observed!;
      momentumError += (receipt.projectedMomentum - actual.momentum).abs();
      pressureError += (receipt.projectedPressure - actual.pressure).abs();
      final int lower = (receipt.projectedMomentum - receipt.uncertainty).clamp(
        0,
        100,
      );
      final int upper = (receipt.projectedMomentum + receipt.uncertainty).clamp(
        0,
        100,
      );
      if (actual.momentum >= lower && actual.momentum <= upper) covered++;
    }
    return TrajectoryCalibrationSummary(
      resolvedForecasts: resolved.length,
      momentumMeanAbsoluteError: momentumError / resolved.length,
      pressureMeanAbsoluteError: pressureError / resolved.length,
      intervalCoverage: covered / resolved.length,
      state: PredictiveCalibrationState.monitored,
      earlierMethodForecasts: earlierMethod,
      correctedForecasts: corrected,
      accountScope: accountScope,
    );
  }

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
