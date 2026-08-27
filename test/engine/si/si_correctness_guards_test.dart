import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SI correctness guards', () {
    test('intent classification maps common request types', () {
      expect(
        classifySIIntent('what task should I do next?').label,
        'task_recommendation',
      );
      expect(classifySIIntent('my energy is crashing').label, 'energy_check');
      expect(classifySIIntent('give me a status summary').label, 'status');
    });

    test(
      'grounding validation strips unknown task references and marks ungrounded',
      () {
        final SIValidatedDecision decision = validateSIResponseDecision(
          inputContext: const SIInputContext(
            query: 'what should I do now?',
            availableTaskIds: <String>{'task-1'},
            runtimeFlags: <String, dynamic>{'allowMutationClaims': false},
            memorySummaries: <String>[],
          ),
          intent: classifySIIntent('what should I do now?'),
          candidate: const SIResponseCandidate(
            message: 'Do task-404 next to unblock progress.',
            reasoning: 'candidate_pick',
            emotion: 'balanced',
            confidence: 0.85,
            taskId: 'task-404',
          ),
        );

        expect(decision.taskId, isNull);
        expect(decision.violations, contains('unknown_task_id'));
        expect(decision.grounded, isFalse);
      },
    );

    test('candidate selector penalizes stale responses', () {
      const SIResponseCandidate stale = SIResponseCandidate(
        message: 'Do the same thing again.',
        reasoning: 'repeat',
        emotion: 'steady',
        confidence: 0.91,
        taskId: 'task-1',
      );
      const SIResponseCandidate fresh = SIResponseCandidate(
        message: 'Switch to a smaller win first.',
        reasoning: 'novel',
        emotion: 'balanced',
        confidence: 0.82,
        taskId: 'task-2',
      );

      final SIResponseSelection selection = selectResponseCandidate(
        candidates: const <SIResponseCandidate>[stale, fresh],
        recentResponseHashes: <String>[responseHashFor(stale.message)],
        recentResponseSummaries: <String>[responseSummaryFor(stale.message)],
        previousTaskId: 'task-1',
        userRecentlySkipping: false,
        previousSnapshot: const <String, dynamic>{'message': 'old'},
      );

      expect(selection.index, 1);
      expect(selection.noveltyScore, greaterThan(0));
    });

    test(
      'confidence calibration stays bounded and penalizes fallback paths',
      () {
        final double baseline = calibrateSIConfidence(
          agentConfidence: 0.9,
          intentConfidence: 0.8,
          grounded: true,
          coherent: true,
          noveltyScore: 0.9,
          memoryUsed: true,
          usedDefaults: false,
          usedFallback: false,
        );

        final double degraded = calibrateSIConfidence(
          agentConfidence: 0.9,
          intentConfidence: 0.8,
          grounded: true,
          coherent: true,
          noveltyScore: 0.9,
          memoryUsed: true,
          usedDefaults: true,
          usedFallback: true,
        );

        expect(baseline, inInclusiveRange(0.0, 1.0));
        expect(degraded, inInclusiveRange(0.0, 1.0));
        expect(degraded, lessThan(baseline));
      },
    );
  });
}
