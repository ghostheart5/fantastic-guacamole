import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/features/insights/models/insight_model.dart';

class InsightsLogic {
  const InsightsLogic();

  double computeHealthScore(SIState state) {
    final double energyScore = state.energy.clamp(0.0, 1.0);
    final double fatigueScore = (1.0 - state.fatigue).clamp(0.0, 1.0);
    return (energyScore * 0.6 + fatigueScore * 0.4).clamp(0.0, 1.0);
  }

  String summarize(List<Insight> insights) {
    if (insights.isEmpty) {
      return 'No notable system patterns yet.';
    }
    if (insights.length == 1) {
      return insights.first.title;
    }
    return '${insights.first.title} • ${insights.length - 1} more signals';
  }
}
