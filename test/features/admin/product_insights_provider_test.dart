import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _ThrowingAccumulator extends LocalMetricsAccumulator {
  const _ThrowingAccumulator();

  @override
  Future<Map<String, dynamic>> snapshot() {
    throw StateError('snapshot failure should not leak to UI');
  }
}

void main() {
  test('exposes degraded fallback state when snapshot source fails', () async {
    final container = ProviderContainer(
      overrides: [
        localMetricsAccumulatorProvider.overrideWithValue(
          const _ThrowingAccumulator(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ProductInsightsState state = await container.read(
      productInsightsProvider.future,
    );

    expect(state.isFallback, isTrue);
    expect(state.warningMessage, isNotNull);
    expect(state.insights, isNotEmpty);
  });
}
