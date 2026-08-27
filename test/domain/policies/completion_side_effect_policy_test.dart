import 'package:fantastic_guacamole/domain/policies/completion_side_effect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only applied completions run one-time completion side effects', () {
    for (final CompletionMutationOutcome outcome
        in CompletionMutationOutcome.values) {
      final CompletionSideEffectDecision decision =
          CompletionSideEffectPolicy.decide(outcome);

      if (outcome == CompletionMutationOutcome.applied) {
        expect(
          decision.enabledEffects,
          CompletionSideEffect.values.toSet(),
          reason: 'Applied is the only side-effect producing outcome.',
        );
      } else {
        expect(
          decision.enabledEffects,
          isEmpty,
          reason: '$outcome must converge without duplicate side effects.',
        );
      }
      expect(decision.shouldInvalidateReadModels, isTrue);
      final bool expected = outcome == CompletionMutationOutcome.applied;
      expect(decision.shouldRunReward, expected);
      expect(decision.shouldRunLearning, expected);
      expect(decision.shouldRunAnalytics, expected);
      expect(decision.shouldRunLog, expected);
      expect(decision.shouldRunTimeline, expected);
      expect(decision.shouldRunGuidance, expected);
      expect(decision.shouldRunNotification, expected);
      expect(decision.shouldRunEvent, expected);
    }
  });
}
