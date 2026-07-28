import 'package:fantastic_guacamole/system/analytics/global_aggregation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GlobalAggregationService', () {
    test('uses loaded rows when available', () async {
      final service = GlobalAggregationService(
        client: null,
        ensureIdentity: () async => 'device-id',
        metricsRowsLoader: (_) async => <Map<String, dynamic>>[
          {
            'tasks_created': 10,
            'tasks_completed': 8,
            'momentum_peak': 4.5,
          },
          {
            'tasks_created': 4,
            'tasks_completed': 1,
            'momentum_peak': 2.0,
          },
        ],
      );

      final metrics = await service.fetchGlobalMetrics();

      expect(metrics.avgTaskCompletionRate, 0.525);
      expect(metrics.avgMomentumPeak, 3.25);
    });
  });
}
