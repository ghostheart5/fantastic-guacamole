import 'package:fantastic_guacamole/core/analytics/global_aggregation_service.dart';
import 'package:fantastic_guacamole/core/analytics/local_metrics_accumulator.dart';
import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/optimizer/global_optimizer.dart';
import 'package:fantastic_guacamole/engine/optimizer/local_optimizer.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_merger.dart';
import 'package:fantastic_guacamole/engine/optimizer/self_optimizer.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localMetricsAccumulatorProvider = Provider<LocalMetricsAccumulator>(
  (_) => const LocalMetricsAccumulator(),
);

final globalAggregationServiceProvider = Provider<GlobalAggregationService>((
  ref,
) {
  return GlobalAggregationService(
    client: ref.read(supabaseClientProvider),
    identity: ref.read(identityServiceProvider),
  );
});

final optimizationConfigProvider = FutureProvider<OptimizationConfig>((
  ref,
) async {
  try {
    final streak = ref.watch(profileProvider).streak;
    final localConfig = const LocalOptimizer().compute(streak: streak);

    final globalMetrics = await ref
        .read(globalAggregationServiceProvider)
        .fetchGlobalMetrics();
    final globalConfig = const GlobalOptimizer().compute(globalMetrics);
    final merged = const OptimizationMerger().merge(localConfig, globalConfig);

    // Apply insight-driven self-optimization (once per day, bounded 0.5–1.5)
    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final snapshot = await accumulator.snapshot();
    final momentum = ref.read(momentumProvider);
    final insights = const ProductAdvisorEngine().fromSnapshot(
      snapshot,
      momentum.chainCount,
    );
    return const SelfOptimizer().adjust(merged, insights);
  } catch (_) {
    return OptimizationConfig.neutral();
  }
});
