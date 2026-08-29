/// CHRONOSPARK-CLASS: SHIPPING | Feature: Progression
///
/// Resolved by featureDerivedProviders -> Progression UI.
class ProgressSignals {
  const ProgressSignals({
    required this.momentum,
    required this.consistency,
    required this.load,
    required this.direction,
  });

  final String momentum; // 'Low' | 'Medium' | 'High'
  final String consistency; // 'N day streak'
  final String load; // 'Light' | 'Balanced' | 'Heavy'
  final String direction; // 'On Track' | 'Slightly Off' | 'Off Track'
}

class GetProgressSignals {
  ProgressSignals call({
    required double momentum,
    required int streak,
    required int pressureIndex,
    required int behaviorDivergence,
  }) {
    return ProgressSignals(
      momentum: momentum >= 0.7
          ? 'High'
          : momentum >= 0.4
          ? 'Medium'
          : 'Low',
      consistency: '$streak day streak',
      load: pressureIndex > 60
          ? 'Heavy'
          : pressureIndex > 30
          ? 'Balanced'
          : 'Light',
      direction: behaviorDivergence > 40
          ? 'Off Track'
          : behaviorDivergence > 20
          ? 'Slightly Off'
          : 'On Track',
    );
  }
}
