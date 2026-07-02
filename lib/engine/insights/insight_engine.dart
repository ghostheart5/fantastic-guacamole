class CompletionInsight {
  final String summary;
  final String observation;
  final String suggestion;

  const CompletionInsight({
    required this.summary,
    required this.observation,
    required this.suggestion,
  });
}

class CompletionInsightEngine {
  CompletionInsight generate({required int seconds, required double energy}) {
    final String summary = "You focused for $seconds seconds.";

    String observation;
    String suggestion;

    if (seconds < 60) {
      observation = "Short session.";
      suggestion = energy < 0.3
          ? "Low energy — rest before your next attempt."
          : "Try stretching your focus time.";
    } else if (seconds < 300) {
      observation = "Good effort.";
      suggestion = energy < 0.3
          ? "Energy is low — consider a short break."
          : "Push a bit further next time.";
    } else {
      observation = "Strong session.";
      suggestion = energy > 0.6
          ? "Energy is high — keep building this rhythm."
          : "Great work — recharge before the next session.";
    }

    return CompletionInsight(
      summary: summary,
      observation: observation,
      suggestion: suggestion,
    );
  }
}
