import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../support/phase11/performance_measurement.dart';

void main() {
  test('local deterministic ordering workload records a complete non-release sample', () {
    final List<int> samples = <int>[];
    final List<int> source = List<int>.generate(
      2000,
      (int index) => (index * 7919) % 2003,
    );

    // The first run is warm-up and intentionally excluded from the result.
    for (int run = 0; run < 6; run += 1) {
      final Stopwatch stopwatch = Stopwatch()..start();
      final List<int> ordered = List<int>.from(source)..sort();
      final int matching = ordered.where((int value) => value % 13 == 0).length;
      stopwatch.stop();
      expect(matching, greaterThan(0));
      if (run > 0) {
        samples.add(max(1, stopwatch.elapsedMicroseconds ~/ 1000));
      }
    }

    final PerformanceMeasurement result = PerformanceMeasurement(
      metric: 'local-timeline-ordering-and-search-harness',
      metadata: const PerformanceRunMetadata(
        commitSha: 'local-unversioned-test',
        binaryHash: 'not-a-candidate-binary',
        device: 'dart-vm-test-host',
        os: 'host-os',
        buildMode: 'test',
        dataset: 'realistic',
        measurementMethod: 'in-process deterministic collection workload',
        warmupPolicy: 'discard first of six samples',
      ),
      samplesMs: samples,
      allowedThresholdMs: 2000,
      baselineMedianMs: 2000,
    );

    expect(result.samplesMs, hasLength(5));
    expect(result.meetsThreshold, isTrue);
    expect(result.toJson()['measurementMethod'], contains('in-process'));
  });
}
