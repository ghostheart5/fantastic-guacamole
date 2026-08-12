import 'package:flutter_test/flutter_test.dart';

import '../support/phase11/performance_measurement.dart';

void main() {
  group('Phase 11 performance measurement contract', () {
    const PerformanceRunMetadata metadata = PerformanceRunMetadata(
      commitSha: 'abc123',
      binaryHash: 'sha256:test-binary',
      device: 'local-test-host',
      os: 'test-os',
      buildMode: 'test',
      dataset: 'small',
      measurementMethod: 'deterministic-local-workload',
      warmupPolicy: 'one discarded sample',
    );

    test('calculates immutable samples, percentiles, and regression metadata', () {
      final PerformanceMeasurement result = PerformanceMeasurement(
        metric: 'timeline-local-ordering',
        metadata: metadata,
        samplesMs: <int>[7, 3, 5, 9, 4],
        allowedThresholdMs: 10,
        baselineMedianMs: 4,
      );

      expect(result.samplesMs, <int>[7, 3, 5, 9, 4]);
      expect(result.medianMs, 5);
      expect(result.p95Ms, 9);
      expect(result.regressionPercent, 25);
      expect(result.meetsThreshold, isTrue);
      expect(result.toJson()['sampleCount'], 5);
      expect(result.toJson()['warmupPolicy'], 'one discarded sample');
    });

    test('rejects incomplete candidate identity and invalid samples', () {
      const PerformanceRunMetadata incomplete = PerformanceRunMetadata(
        commitSha: '',
        binaryHash: 'hash',
        device: 'device',
        os: 'os',
        buildMode: 'profile',
        dataset: 'small',
        measurementMethod: 'method',
        warmupPolicy: 'warmup',
      );

      expect(
        () => PerformanceMeasurement(
          metric: 'metric',
          metadata: incomplete,
          samplesMs: <int>[1],
          allowedThresholdMs: 1,
          baselineMedianMs: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => PerformanceMeasurement(
          metric: 'metric',
          metadata: metadata,
          samplesMs: const <int>[],
          allowedThresholdMs: 1,
          baselineMedianMs: 1,
        ),
        throwsArgumentError,
      );
    });

    test('defines every required dataset scale without a production fixture', () {
      expect(PerformanceDataset.values, hasLength(5));
      expect(PerformanceDataset.extreme.description, contains('100,000'));
    });
  });
}
