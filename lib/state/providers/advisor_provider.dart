import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/advisor/weekly_advisor.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productInsightsProvider = FutureProvider<List<ProductInsight>>((
  ref,
) async {
  try {
    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final snapshot = await accumulator.snapshot();
    final momentum = ref.watch(momentumProvider);
    return const ProductAdvisorEngine().fromSnapshot(
      snapshot,
      momentum.chainCount,
    );
  } catch (_) {
    return const ProductAdvisorEngine().analyze(
      nextSeen: 0,
      started: 0,
      completed: 0,
      focusStarted: 0,
      focusCompleted: 0,
      momentumPeak: 0,
    );
  }
});

final weeklySummaryProvider = FutureProvider<String>((ref) async {
  try {
    final insights = await ref.watch(productInsightsProvider.future);
    return const WeeklyAdvisor().summarize(insights);
  } catch (_) {
    return 'Not enough data yet. Keep using the app to generate insights.';
  }
});
