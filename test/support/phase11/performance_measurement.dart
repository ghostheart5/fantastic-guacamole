import 'dart:collection';

/// Immutable, candidate-identifying metadata required for a performance run.
///
/// This model is deliberately test-only. It records measurements but neither
/// starts the application nor changes any production performance behavior.
class PerformanceRunMetadata {
  const PerformanceRunMetadata({
    required this.commitSha,
    required this.binaryHash,
    required this.device,
    required this.os,
    required this.buildMode,
    required this.dataset,
    required this.measurementMethod,
    required this.warmupPolicy,
  });

  final String commitSha;
  final String binaryHash;
  final String device;
  final String os;
  final String buildMode;
  final String dataset;
  final String measurementMethod;
  final String warmupPolicy;

  bool get isComplete => <String>[
    commitSha,
    binaryHash,
    device,
    os,
    buildMode,
    dataset,
    measurementMethod,
    warmupPolicy,
  ].every((String value) => value.trim().isNotEmpty);
}

/// A calculated performance result. Values are in milliseconds.
class PerformanceMeasurement {
  PerformanceMeasurement({
    required this.metric,
    required this.metadata,
    required Iterable<int> samplesMs,
    required this.allowedThresholdMs,
    required this.baselineMedianMs,
  }) : samplesMs = UnmodifiableListView<int>(List<int>.from(samplesMs)) {
    if (!metadata.isComplete) {
      throw ArgumentError.value(metadata, 'metadata', 'must be complete');
    }
    if (this.samplesMs.isEmpty || this.samplesMs.any((int value) => value < 0)) {
      throw ArgumentError.value(samplesMs, 'samplesMs', 'must be non-empty and non-negative');
    }
    if (allowedThresholdMs <= 0 || baselineMedianMs <= 0) {
      throw ArgumentError('threshold and baseline must be positive');
    }
  }

  final String metric;
  final PerformanceRunMetadata metadata;
  final UnmodifiableListView<int> samplesMs;
  final int allowedThresholdMs;
  final int baselineMedianMs;

  int get medianMs => _percentile(0.50);
  int get p95Ms => _percentile(0.95);
  double get regressionPercent =>
      ((medianMs - baselineMedianMs) / baselineMedianMs) * 100;
  bool get meetsThreshold => p95Ms <= allowedThresholdMs;

  int _percentile(double fraction) {
    final List<int> sorted = List<int>.from(samplesMs)..sort();
    final int index = ((sorted.length - 1) * fraction).ceil();
    return sorted[index];
  }

  Map<String, Object> toJson() => <String, Object>{
        'metric': metric,
        'commitSha': metadata.commitSha,
        'binaryHash': metadata.binaryHash,
        'device': metadata.device,
        'os': metadata.os,
        'buildMode': metadata.buildMode,
        'dataset': metadata.dataset,
        'measurementMethod': metadata.measurementMethod,
        'warmupPolicy': metadata.warmupPolicy,
        'sampleCount': samplesMs.length,
        'medianMs': medianMs,
        'p95Ms': p95Ms,
        'allowedThresholdMs': allowedThresholdMs,
        'regressionPercent': regressionPercent,
        'meetsThreshold': meetsThreshold,
      };
}

/// Dataset definitions used by all Phase 11 runners.
enum PerformanceDataset { empty, small, realistic, heavy, extreme }

extension PerformanceDatasetDescription on PerformanceDataset {
  String get id => name;

  String get description => switch (this) {
        PerformanceDataset.empty => '0 user-created records',
        PerformanceDataset.small => '25 tasks and 50 timeline events',
        PerformanceDataset.realistic => '250 tasks and 2,000 timeline events',
        PerformanceDataset.heavy => '2,000 tasks and 20,000 timeline events',
        PerformanceDataset.extreme => '10,000 tasks and 100,000 timeline events',
      };
}
