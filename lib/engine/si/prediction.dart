class Prediction {
  Prediction({
    required this.outcome,
    required this.probability,
    required this.explanation,
  });

  final String outcome;
  final double probability;
  final String explanation;
}
