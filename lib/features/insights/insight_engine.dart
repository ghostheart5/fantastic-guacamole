import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/features/insights/models/insight_model.dart';

class InsightEngine {
  const InsightEngine(this.state);

  final SIState state;

  List<Insight> generate() {
    final insights = <Insight>[];

    if (state.fatigue > 0.7) {
      insights.add(
        const Insight(
          title: 'Overload Detected',
          description:
              'Fatigue is high. Consider a short recovery block before the next task.',
        ),
      );
    }

    if (state.energy > 0.6) {
      insights.add(
        const Insight(
          title: 'High Energy Window',
          description:
              'You are in a strong focus state. Prioritise your hardest task now.',
        ),
      );
    } else if (state.energy < 0.35) {
      insights.add(
        const Insight(
          title: 'Low Energy Detected',
          description:
              'Energy reserves are low. Shift to lighter tasks or take a break.',
        ),
      );
    }

    if (state.completedToday >= 3) {
      insights.add(
        Insight(
          title: 'Strong Progress',
          description:
              'You have completed ${state.completedToday} tasks today. Momentum is building.',
        ),
      );
    } else if (state.completedToday == 0) {
      insights.add(
        const Insight(
          title: 'No Tasks Completed',
          description:
              'Start with the smallest task on your list to break inertia.',
        ),
      );
    }

    if (state.fatigue < 0.3 && state.energy > 0.7) {
      insights.add(
        const Insight(
          title: 'Peak Condition',
          description:
              'Low fatigue and high energy. Ideal conditions for deep work.',
        ),
      );
    }

    return insights;
  }
}
