class CompletionSignal {
  final String summary;
  final String observation;
  final String suggestion;

  const CompletionSignal({
    required this.summary,
    required this.observation,
    required this.suggestion,
  });
}

class CompletionSignalEngine {
  CompletionSignal generate({required int seconds, required double energy}) {
    final String summary = "You worked for $seconds seconds.";

    String observation;
    String suggestion;

    if (seconds < 60) {
      observation = "Short effort.";
      suggestion = energy < 0.3
          ? "Low energy — rest before your next attempt."
          : "Try extending your work interval.";
    } else if (seconds < 300) {
      observation = "Good effort.";
      suggestion = energy < 0.3
          ? "Energy is low — consider a short break."
          : "Push a bit further next time.";
    } else {
      observation = "Strong completion.";
      suggestion = energy > 0.6
          ? "Energy is high — keep building this rhythm."
          : "Great work — recharge before the next effort.";
    }

    return CompletionSignal(
      summary: summary,
      observation: observation,
      suggestion: suggestion,
    );
  }
}
