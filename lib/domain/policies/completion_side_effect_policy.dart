/// CHRONOSPARK-CLASS: SHIPPING | Feature: Task completion
enum CompletionMutationOutcome { applied, idempotent, conflict, blocked }

enum CompletionSideEffect {
  reward,
  learning,
  analytics,
  log,
  timeline,
  guidance,
  notification,
  event,
}

class CompletionSideEffectDecision {
  const CompletionSideEffectDecision({
    required this.outcome,
    required this.enabledEffects,
  });

  final CompletionMutationOutcome outcome;
  final Set<CompletionSideEffect> enabledEffects;

  bool get shouldInvalidateReadModels => true;
  bool get shouldRunReward =>
      enabledEffects.contains(CompletionSideEffect.reward);
  bool get shouldRunLearning =>
      enabledEffects.contains(CompletionSideEffect.learning);
  bool get shouldRunAnalytics =>
      enabledEffects.contains(CompletionSideEffect.analytics);
  bool get shouldRunLog => enabledEffects.contains(CompletionSideEffect.log);
  bool get shouldRunTimeline =>
      enabledEffects.contains(CompletionSideEffect.timeline);
  bool get shouldRunGuidance =>
      enabledEffects.contains(CompletionSideEffect.guidance);
  bool get shouldRunNotification =>
      enabledEffects.contains(CompletionSideEffect.notification);
  bool get shouldRunEvent =>
      enabledEffects.contains(CompletionSideEffect.event);
}

/// Single policy for post-completion side effects.
///
/// Applied means this device created the durable outcome and may emit the
/// one-time reward/learning/analytics/log/timeline/guidance/notification/event
/// side effects. Idempotent and conflict results are convergence outcomes:
/// read models may refresh, but side effects must not run again.
class CompletionSideEffectPolicy {
  const CompletionSideEffectPolicy._();

  static const Set<CompletionSideEffect> _allOneTimeEffects =
      <CompletionSideEffect>{
        CompletionSideEffect.reward,
        CompletionSideEffect.learning,
        CompletionSideEffect.analytics,
        CompletionSideEffect.log,
        CompletionSideEffect.timeline,
        CompletionSideEffect.guidance,
        CompletionSideEffect.notification,
        CompletionSideEffect.event,
      };

  static CompletionSideEffectDecision decide(
    CompletionMutationOutcome outcome,
  ) {
    return CompletionSideEffectDecision(
      outcome: outcome,
      enabledEffects: outcome == CompletionMutationOutcome.applied
          ? _allOneTimeEffects
          : const <CompletionSideEffect>{},
    );
  }
}
