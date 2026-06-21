enum InsightSeverity { info, warning, critical }

class SIInsight {
  final String message;
  final InsightSeverity severity;

  const SIInsight({required this.message, required this.severity});
}
