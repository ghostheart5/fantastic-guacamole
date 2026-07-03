import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';

class ProgressSignals {
  const ProgressSignals({
    required this.momentum,
    required this.consistency,
    required this.load,
    required this.direction,
  });

  final String momentum;     // 'Low' | 'Medium' | 'High'
  final String consistency;  // 'N day streak'
  final String load;         // 'Light' | 'Balanced' | 'Heavy'
  final String direction;    // 'On Track' | 'Slightly Off' | 'Off Track'
}

class GetProgressSignals {
  ProgressSignals call(TrajectorySummaryView traj) {
    return ProgressSignals(
      momentum: traj.momentum >= 0.7
          ? 'High'
          : traj.momentum >= 0.4
              ? 'Medium'
              : 'Low',
      consistency: '${traj.streak} day streak',
      load: traj.pressureIndex > 60
          ? 'Heavy'
          : traj.pressureIndex > 30
              ? 'Balanced'
              : 'Light',
      direction: traj.behaviorDivergence > 40
          ? 'Off Track'
          : traj.behaviorDivergence > 20
              ? 'Slightly Off'
              : 'On Track',
    );
  }
}
