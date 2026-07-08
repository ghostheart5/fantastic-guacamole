class SessionScore {
  final int xp;
  final double quality;
  final String feedback;
  final double confidenceDelta;

  const SessionScore({
    required this.xp,
    required this.quality,
    required this.feedback,
    this.confidenceDelta = 0.0,
  });
}
