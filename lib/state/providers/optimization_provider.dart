import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/optimizer/global_optimizer.dart';
import 'package:fantastic_guacamole/engine/optimizer/local_optimizer.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_merger.dart';
import 'package:fantastic_guacamole/engine/optimizer/self_optimizer.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart'
    show identityServiceProvider;
import 'package:fantastic_guacamole/system/analytics/global_aggregation_service.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localMetricsAccumulatorProvider = Provider<LocalMetricsAccumulator>(
  (_) => const LocalMetricsAccumulator(),
);

final globalAggregationServiceProvider = Provider<GlobalAggregationService>((
  ref,
) {
  return GlobalAggregationService(
    client: ref.read(supabaseClientProvider),
    ensureIdentity: ref.read(identityServiceProvider).ensureIdentity,
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
    final globalConfig = const GlobalOptimizer().compute(
      averageTaskCompletionRate: globalMetrics.avgTaskCompletionRate,
    );
    final merged = const OptimizationMerger().merge(localConfig, globalConfig);

    // Apply insight-driven self-optimization (once per day, bounded 0.5–1.5)
    await SharedPrefsService.init();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    if (SharedPrefsService.load(_lastOptimizationDateKey) == today) {
      return _loadOptimizationConfig() ?? merged;
    }

    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final snapshot = await accumulator.snapshot();
    final momentum = ref.read(momentumProvider);
    final insights = const ProductAdvisorEngine().fromSnapshot(
      snapshot,
      momentum.chainCount,
    );
    final OptimizationConfig adjusted = const SelfOptimizer().adjust(
      merged,
      insights,
    );
    await _saveOptimizationConfig(adjusted, today);
    return adjusted;
  } catch (_) {
    return OptimizationConfig.neutral();
  }
});

const String _optimizationConfigKey = 'self_opt_config_v1';
const String _lastOptimizationDateKey = 'self_opt_last_adjust';

OptimizationConfig? _loadOptimizationConfig() {
  final String? raw = SharedPrefsService.load(_optimizationConfigKey);
  if (raw == null) return null;
  try {
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return OptimizationConfig(
      focusDurationMultiplier:
          (json['focusDurationMultiplier'] as num?)?.toDouble() ?? 1,
      taskDifficultyScale:
          (json['taskDifficultyScale'] as num?)?.toDouble() ?? 1,
      nextActionAggressiveness:
          (json['nextActionAggressiveness'] as num?)?.toDouble() ?? 1,
    );
  } catch (_) {
    return null;
  }
}

Future<void> _saveOptimizationConfig(
  OptimizationConfig config,
  String date,
) async {
  await SharedPrefsService.save(_lastOptimizationDateKey, date);
  await SharedPrefsService.save(
    _optimizationConfigKey,
    jsonEncode(<String, double>{
      'focusDurationMultiplier': config.focusDurationMultiplier,
      'taskDifficultyScale': config.taskDifficultyScale,
      'nextActionAggressiveness': config.nextActionAggressiveness,
    }),
  );
}
