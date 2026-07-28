import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GoalRestructureAction { keepCourse, simplify, defer, rebuild }

class GoalRestructureRecommendation {
  const GoalRestructureRecommendation({
    required this.action,
    required this.title,
    required this.reason,
  });

  final GoalRestructureAction action;
  final String title;
  final String reason;
}

final autonomousGoalRestructureProvider =
    Provider<GoalRestructureRecommendation>((ref) {
      final success = ref.watch(goalSuccessProbabilityProvider);
      final risk = ref.watch(predictiveRiskProvider);

      final highRisk = risk.risks.any(
        (r) => r.level == PredictiveRiskLevel.high,
      );

      if (success.probability < 40) {
        return const GoalRestructureRecommendation(
          action: GoalRestructureAction.rebuild,
          title: 'Rebuild Goal Structure',
          reason:
              'Current success probability is too low for the existing plan.',
        );
      }

      if (highRisk) {
        return const GoalRestructureRecommendation(
          action: GoalRestructureAction.simplify,
          title: 'Simplify Active Goals',
          reason:
              'Risk profile suggests reducing complexity before scaling effort.',
        );
      }

      if (success.probability < 60) {
        return const GoalRestructureRecommendation(
          action: GoalRestructureAction.defer,
          title: 'Defer Lower-Leverage Goals',
          reason: 'Focus should remain on the highest-value objective.',
        );
      }

      return const GoalRestructureRecommendation(
        action: GoalRestructureAction.keepCourse,
        title: 'Maintain Current Direction',
        reason: 'Current goals remain aligned with projected success.',
      );
    });
