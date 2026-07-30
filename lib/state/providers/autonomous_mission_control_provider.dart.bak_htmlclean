import 'package:fantastic_guacamole/state/providers/autonomous_daily_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_life_optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_review_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_fusion_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissionControlState {
  const MissionControlState({
    required this.status,
    required this.primaryAction,
    required this.primaryRisk,
    required this.primaryOpportunity,
    required this.todayFocus,
    required this.tomorrowAdjustment,
  });

  final String status;
  final String primaryAction;
  final String primaryRisk;
  final String primaryOpportunity;
  final String todayFocus;
  final String tomorrowAdjustment;
}

final autonomousMissionControlProvider = Provider<MissionControlState>((ref) {
  final fusion = ref.watch(intelligenceFusionProvider);
  final daily = ref.watch(autonomousDailyPlannerProvider);
  final review = ref.watch(autonomousReviewProvider);
  final optimization = ref.watch(autonomousLifeOptimizationProvider);

  return MissionControlState(
    status: optimization.optimizationScore >= 80
        ? 'Optimal'
        : optimization.optimizationScore >= 60
        ? 'Stable'
        : 'Needs Correction',

    primaryAction: fusion.nextAction,
    primaryRisk: fusion.primaryThreat,
    primaryOpportunity: fusion.primaryOpportunity,

    todayFocus: daily.focus,
    tomorrowAdjustment: review.tomorrowAdjustment,
  );
});
