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

/// Immutable evidence that a user elected to track a conditional simulation.
/// It contains no task titles or free-text user content.
class TrajectoryForecastReceipt {
  const TrajectoryForecastReceipt({
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
    this.observed,
    this.schemaVersion = 1,
  });

  factory TrajectoryForecastReceipt.fromScenario({
    required TrajectoryBaseline baseline,
    required TrajectoryScenarioOutcome outcome,
    required DateTime selectedAt,
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
  final TrajectoryObservedOutcome? observed;
  final int schemaVersion;

  DateTime get dueAt => selectedAt.add(horizon);
  bool get isResolved => observed != null;
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
        observed: value,
        schemaVersion: schemaVersion,
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
    'observed': observed?.toJson(),
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
      observed: json['observed'] is Map
          ? TrajectoryObservedOutcome.fromJson(
              Map<String, dynamic>.from(json['observed'] as Map),
            )
          : null,
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
  });

  factory TrajectoryCalibrationSummary.fromReceipts(
    Iterable<TrajectoryForecastReceipt> receipts,
  ) {
    final List<TrajectoryForecastReceipt> resolved = receipts
        .where((TrajectoryForecastReceipt item) => item.observed != null)
        .toList(growable: false);
    if (resolved.isEmpty) {
      return const TrajectoryCalibrationSummary(
        resolvedForecasts: 0,
        momentumMeanAbsoluteError: 0,
        pressureMeanAbsoluteError: 0,
        intervalCoverage: 0,
        state: PredictiveCalibrationState.provisional,
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
    final PredictiveCalibrationState state = resolved.length >= 10
        ? PredictiveCalibrationState.calibrated
        : PredictiveCalibrationState.monitored;
    return TrajectoryCalibrationSummary(
      resolvedForecasts: resolved.length,
      momentumMeanAbsoluteError: momentumError / resolved.length,
      pressureMeanAbsoluteError: pressureError / resolved.length,
      intervalCoverage: covered / resolved.length,
      state: state,
    );
  }

  final int resolvedForecasts;
  final double momentumMeanAbsoluteError;
  final double pressureMeanAbsoluteError;
  final double intervalCoverage;
  final PredictiveCalibrationState state;
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
