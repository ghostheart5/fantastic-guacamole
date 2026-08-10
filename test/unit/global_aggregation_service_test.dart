import 'package:fantastic_guacamole/system/analytics/global_aggregation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GlobalAggregationService', () {
    test('uses loaded rows when available', () async {
      final service = GlobalAggregationService(
        client: null,
        ensureIdentity: () async => 'device-id',
        metricsRowsLoader: (_) async => <Map<String, dynamic>>[
          {'tasks_created': 10, 'tasks_completed': 8, 'momentum_peak': 4.5},
          {'tasks_created': 4, 'tasks_completed': 1, 'momentum_peak': 2.0},
        ],
      );

      final metrics = await service.fetchGlobalMetrics();

      expect(metrics.avgTaskCompletionRate, 0.525);
      expect(metrics.avgMomentumPeak, 3.25);
    });

    test('suppresses known non-fatal Postgres conflict errors', () {
      const error = sb.PostgrestException(
        message:
            'there is no unique or exclusion constraint matching the ON CONFLICT specification',
        code: '42P10',
        details: 'Bad Request',
        hint: null,
      );

      expect(
        GlobalAggregationService.isExpectedNonFatalPushError(error),
        isTrue,
      );
    });

    test('does not suppress unexpected errors', () {
      expect(
        GlobalAggregationService.isExpectedNonFatalPushError(Exception('boom')),
        isFalse,
      );
    });
  });
}
