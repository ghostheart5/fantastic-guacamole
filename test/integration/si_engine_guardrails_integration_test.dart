import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SI engine guardrails', () {
    test('selectResponseCandidate penalizes repeated wording using summaries', () {
      final SIResponseSelection selection = selectResponseCandidate(
        candidates: const <SIResponseCandidate>[
          SIResponseCandidate(
            message: 'Focus on task alpha by completing the first draft today.',
            reasoning: 'candidate_a',
            emotion: 'balanced',
            confidence: 0.9,
            taskId: 'alpha',
          ),
          SIResponseCandidate(
            message: 'Take five minutes to plan the next action for task beta.',
            reasoning: 'candidate_b',
            emotion: 'balanced',
            confidence: 0.55,
            taskId: 'beta',
          ),
        ],
        recentResponseHashes: const <String>[],
        recentResponseSummaries: const <String>['focus on task alpha by completing first draft'],
        previousTaskId: null,
        userRecentlySkipping: false,
        previousSnapshot: const <String, dynamic>{},
      );

      expect(selection.index, 1);
      expect(selection.noveltyScore, greaterThan(0));
    });

    test('validateSIResponseDecision blocks ungrounded external-data/task-complete claims', () {
      const SIInputContext context = SIInputContext(
        query: 'status check',
        availableTaskIds: <String>{'task-1'},
        runtimeFlags: <String, dynamic>{'mockMode': false},
        memorySummaries: <String>[],
      );
      const SIIntent intent = SIIntent(label: 'status', confidence: 0.8);
      const SIResponseCandidate candidate = SIResponseCandidate(
        message: 'I performed an internet search and all tasks complete, so you are done.',
        reasoning: 'ungrounded_claims',
        emotion: 'balanced',
        confidence: 0.8,
        taskId: 'task-1',
      );

      final SIValidatedDecision decision = validateSIResponseDecision(
        inputContext: context,
        intent: intent,
        candidate: candidate,
      );

      expect(decision.grounded, isFalse);
      expect(decision.violations, contains('external_data_claim_not_grounded'));
      expect(decision.violations, contains('task_completion_claim_not_grounded'));
      expect(decision.message, contains('grounded'));
    });

    test('policy gate rejects unsupported AI-meta phrasing', () {
      final bool accepted = isPolicyAcceptableResponse('As an AI language model I cannot do that.');

      expect(accepted, isFalse);
    });

    test('blocks mutation claims when the response did not execute a use case', () {
      const SIInputContext context = SIInputContext(
        query: 'remind me tomorrow',
        availableTaskIds: <String>{},
        runtimeFlags: <String, dynamic>{'mockMode': false, 'allowMutationClaims': false},
        memorySummaries: <String>[],
      );

      final SIValidatedDecision decision = validateSIResponseDecision(
        inputContext: context,
        intent: const SIIntent(label: 'reminder', confidence: 0.8),
        candidate: const SIResponseCandidate(
          message: 'Your reminder was queued for tomorrow morning.',
          reasoning: 'claimed_side_effect',
          emotion: 'balanced',
          confidence: 0.8,
        ),
      );

      expect(decision.grounded, isFalse);
      expect(decision.violations, contains('mutation_claim_not_grounded'));
    });

    test('final response repetition and confidence use system evidence', () {
      final String repeated = 'Focus on task alpha by completing the first draft today.';
      final bool isRepeated = isSubstantiallyRepeatedResponse(
        message: repeated,
        recentResponseHashes: <String>[responseHashFor(repeated)],
        recentResponseSummaries: const <String>[],
      );
      final double strong = calibrateSIConfidence(
        agentConfidence: 0.9,
        intentConfidence: 0.85,
        grounded: true,
        coherent: true,
        noveltyScore: 1,
        memoryUsed: true,
        usedDefaults: false,
        usedFallback: false,
      );
      final double weak = calibrateSIConfidence(
        agentConfidence: 0.9,
        intentConfidence: 0.85,
        grounded: false,
        coherent: false,
        noveltyScore: 0,
        memoryUsed: false,
        usedDefaults: true,
        usedFallback: true,
      );

      expect(isRepeated, isTrue);
      expect(strong, greaterThan(weak));
      expect(strong, inInclusiveRange(0, 1));
      expect(weak, inInclusiveRange(0, 1));
    });
  });
}
