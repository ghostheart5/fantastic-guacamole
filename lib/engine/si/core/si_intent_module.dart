// Module 3 — Intent
// Pipeline step: SIContext → SIIntent
// Merges: si_intent + si_intent_engine

// ─── Data contracts ───────────────────────────────────────────────────────────

class IntentCandidate {
  const IntentCandidate({
    required this.label,
    required this.score,
    required this.why,
  });

  final String label;
  final double score;
  final String why;
}

class SIIntent {
  const SIIntent({
    required this.primary,
    this.secondary,
    this.hidden,
    required this.predictedNext,
    required this.chain,
  });

  final IntentCandidate primary;
  final IntentCandidate? secondary;
  final IntentCandidate? hidden;
  final String predictedNext;
  final List<String> chain;

  bool get isComplex => secondary != null || hidden != null;

  double get confidence => primary.score;
}

// ─── Module ───────────────────────────────────────────────────────────────────

class SIIntentModule {
  const SIIntentModule();

  SIIntent extract(String text) {
    final String lowered = text.toLowerCase();

    IntentCandidate primary = const IntentCandidate(
      label: 'general_query',
      score: 0.55,
      why: 'Fallback classification',
    );
    IntentCandidate? secondary;
    IntentCandidate? hidden;

    if (lowered.contains('focus')) {
      primary = const IntentCandidate(
        label: 'start_focus',
        score: 0.88,
        why: 'Contains focus keyword',
      );
      secondary = const IntentCandidate(
        label: 'productivity_optimization',
        score: 0.66,
        why: 'Focus implies performance goal',
      );
    } else if (lowered.contains('task') ||
        lowered.contains('what should i do')) {
      primary = const IntentCandidate(
        label: 'get_task',
        score: 0.84,
        why: 'Direct ask for next task',
      );
      hidden = const IntentCandidate(
        label: 'decision_support',
        score: 0.62,
        why: 'Likely seeking confidence boost',
      );
    } else if (lowered.contains('reflect') || lowered.contains('review')) {
      primary = const IntentCandidate(
        label: 'reflect',
        score: 0.81,
        why: 'Reflection/review keywords present',
      );
    } else if (lowered.contains('insight')) {
      primary = const IntentCandidate(
        label: 'insight_request',
        score: 0.79,
        why: 'Insight keyword present',
      );
    }

    final List<String> chain = <String>[
      primary.label,
      if (secondary != null) secondary.label,
    ];
    final String predictedNext =
        primary.label == 'start_focus' ? 'insight_request' : 'start_focus';

    return SIIntent(
      primary: primary,
      secondary: secondary,
      hidden: hidden,
      predictedNext: predictedNext,
      chain: chain,
    );
  }
}
