import 'package:fantastic_guacamole/state/providers/autonomous_focus_scheduler_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_goal_restructure_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_review_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeOptimizationState {
  const LifeOptimizationState({
    required this.optimizationScore,
    required this.primaryAdjustment,
    required this.reason,
    required this.nextDirective,
  });

  final int optimizationScore;
  final String primaryAdjustment;
  final String reason;
  final String nextDirective;
}

final autonomousLifeOptimizationProvider = Provider<LifeOptimizationState>((
  ref,
) {
  final review = ref.watch(autonomousReviewProvider);
  final focus = ref.watch(autonomousFocusSchedulerProvider);
  final restructure = ref.watch(autonomousGoalRestructureProvider);
  final lifeOs = ref.watch(lifeOSProvider);

  final int score = ((review.score + 75) / 2).round().clamp(0, 100);

  return LifeOptimizationState(
    optimizationScore: score,
    primaryAdjustment: restructure.title,
    reason: restructure.reason,
    nextDirective:
        '${lifeOs.primaryAction} - ${focus.durationMinutes} minute focus block',
  );
});
