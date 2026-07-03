class CoherenceReport {
  const CoherenceReport({
    required this.coherent,
    required this.axes,
    required this.corrections,
  });

  final bool coherent;
  final Map<String, double> axes;
  final List<String> corrections;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coherent': coherent,
      'axes': axes,
      'corrections': corrections,
    };
  }
}

class CognitiveCoherenceValidator {
  const CognitiveCoherenceValidator();

  CoherenceReport validate({
    required double memory,
    required double persona,
    required double emotional,
    required double reasoning,
    required double goals,
    required double multiverse,
  }) {
    final Map<String, double> axes = <String, double>{
      'memory': memory,
      'persona': persona,
      'emotional': emotional,
      'reasoning': reasoning,
      'goals': goals,
      'multiverse': multiverse,
    };
    final List<String> low = axes.entries
        .where((MapEntry<String, double> e) => e.value < 0.5)
        .map((MapEntry<String, double> e) => e.key)
        .toList();
    return CoherenceReport(
      coherent: low.isEmpty,
      axes: axes,
      corrections: low.map((String a) => 'increase_${a}_alignment').toList(),
    );
  }
}
