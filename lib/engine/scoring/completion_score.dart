class CompletionScore {
  final int xp;
  final double quality;
  final String feedback;
  final double confidenceDelta;

  const CompletionScore({
    required this.xp,
    required this.quality,
    required this.feedback,
    this.confidenceDelta = 0.0,
  });
}
