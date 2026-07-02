class TemporalLoopState {
  const TemporalLoopState({
    required this.cycles,
    required this.negativeLoops,
    required this.positiveLoops,
    required this.breakAction,
    required this.reinforceAction,
  });

  final List<String> cycles;
  final List<String> negativeLoops;
  final List<String> positiveLoops;
  final String breakAction;
  final String reinforceAction;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cycles': cycles,
      'negative_loops': negativeLoops,
      'positive_loops': positiveLoops,
      'break_action': breakAction,
      'reinforce_action': reinforceAction,
    };
  }
}

class SyntheticTemporalLoopEngine {
  const SyntheticTemporalLoopEngine();

  TemporalLoopState evaluate({
    required List<String> history,
    required String mood,
  }) {
    final bool repeatedStress =
        history
            .where((String h) => h.toLowerCase().contains('stressed'))
            .length >=
        2;
    final bool repeatedFocus =
        history.where((String h) => h.toLowerCase().contains('focus')).length >=
        2;

    return TemporalLoopState(
      cycles: <String>[
        if (repeatedStress) 'stress_cycle',
        if (repeatedFocus) 'focus_cycle',
      ],
      negativeLoops: <String>[
        if (repeatedStress || mood == 'stressed') 'overload_loop',
      ],
      positiveLoops: <String>[if (repeatedFocus) 'momentum_loop'],
      breakAction: 'Insert reset and reduce scope when overload loop appears.',
      reinforceAction: 'Reward and repeat successful focus loop signals.',
    );
  }
}
