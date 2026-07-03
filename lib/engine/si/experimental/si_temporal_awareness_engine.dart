class TemporalAwareness {
  const TemporalAwareness({
    required this.period,
    required this.routineHint,
    required this.trigger,
    required this.futurePrediction,
    required this.decayFactor,
    required this.pattern,
  });

  final String period;
  final String routineHint;
  final String trigger;
  final String futurePrediction;
  final double decayFactor;
  final String pattern;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'period': period,
      'routine_hint': routineHint,
      'trigger': trigger,
      'future_prediction': futurePrediction,
      'decay_factor': decayFactor,
      'pattern': pattern,
    };
  }
}

class TemporalAwarenessEngine {
  const TemporalAwarenessEngine();

  TemporalAwareness evaluate({
    required DateTime now,
    required List<String> history,
    required String intent,
  }) {
    final int hour = now.hour;
    final String period = hour < 5
        ? 'late_night'
        : hour < 12
        ? 'morning'
        : hour < 17
        ? 'afternoon'
        : 'evening';

    final int focusMentions = history
        .where((String h) => h.toLowerCase().contains('focus'))
        .length;
    final String pattern = focusMentions >= 3
        ? 'You frequently return to focused work patterns.'
        : 'Your activity pattern is still emerging.';

    final String routineHint = switch (period) {
      'morning' => 'You usually build momentum well right now.',
      'afternoon' => 'This is a good time for execution-heavy tasks.',
      'evening' => 'You tend to do best with review and synthesis now.',
      _ => 'Creative exploration often appears in this time window.',
    };

    final String trigger = intent == 'reflect'
        ? 'reflection_window'
        : intent == 'start_focus'
        ? 'focus_window'
        : 'general_window';

    final String prediction = intent == 'start_focus'
        ? 'Likely to complete at least one deep work block next.'
        : 'Likely to request planning or clarification next.';

    final double decay = (1 - ((hour / 24) * 0.35)).clamp(0.6, 1.0);

    return TemporalAwareness(
      period: period,
      routineHint: routineHint,
      trigger: trigger,
      futurePrediction: prediction,
      decayFactor: decay,
      pattern: pattern,
    );
  }
}
