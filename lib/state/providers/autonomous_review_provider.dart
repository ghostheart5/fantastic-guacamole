import 'package:fantastic_guacamole/state/providers/autonomous_daily_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutonomousReviewState {
  const AutonomousReviewState({
    required this.score,
    required this.summary,
    required this.tomorrowAdjustment,
    required this.alignment,
  });

  final int score;
  final String summary;
  final String tomorrowAdjustment;
  final String alignment;
}

final autonomousReviewProvider = Provider<AutonomousReviewState>((ref) {
  final daily = ref.watch(autonomousDailyPlannerProvider);
  final drift = ref.watch(identityDriftProvider);
  final lifeOs = ref.watch(lifeOSProvider);

  final int score = ((drift.score * 0.7) + 30).clamp(0, 100).toInt();

  final String summary = score >= 80
      ? 'Execution remained strongly aligned with ${lifeOs.primaryAction} and current identity direction.'
      : score >= 60
      ? 'Execution was mostly aligned, but daily focus drift appeared under load.'
      : 'Execution drifted from intended direction and needs immediate narrowing.';

  final String tomorrowAdjustment = score >= 80
      ? 'Continue the same operating mode and preserve one high-focus block.'
      : score >= 60
      ? 'Reduce context switching and execute the top directive before opening new work.'
      : 'Simplify commitments, recover pressure, and restart with one definitive completion.';

  return AutonomousReviewState(
    score: score,
    summary: summary,
    tomorrowAdjustment: tomorrowAdjustment,
    alignment: '${lifeOs.identityStage} - ${daily.focus}',
  );
});
