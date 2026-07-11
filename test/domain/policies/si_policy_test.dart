import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiPolicy', () {
    test('shouldSuggestBreak triggers on high fatigue or low energy', () {
      final highFatigue = SiStateEntity(energy: 0.8, focus: 0.5, fatigue: 0.71);
      final lowEnergy = SiStateEntity(energy: 0.29, focus: 0.5, fatigue: 0.2);
      final balanced = SiStateEntity(energy: 0.5, focus: 0.5, fatigue: 0.5);

      expect(SiPolicy.shouldSuggestBreak(highFatigue), isTrue);
      expect(SiPolicy.shouldSuggestBreak(lowEnergy), isTrue);
      expect(SiPolicy.shouldSuggestBreak(balanced), isFalse);
    });

    test('shouldPushFocus only when energy/focus high and fatigue low', () {
      final focused = SiStateEntity(energy: 0.7, focus: 0.6, fatigue: 0.4);
      final tired = SiStateEntity(energy: 0.7, focus: 0.6, fatigue: 0.6);

      expect(SiPolicy.shouldPushFocus(focused), isTrue);
      expect(SiPolicy.shouldPushFocus(tired), isFalse);
    });

    test(
      'enforce simplifies action, caps focus minutes, and sets calm tone',
      () {
        const decision = SiDecisionEntity(
          rationale: 'Need simplification',
          action: 'First step. Second step. Third step.',
          shouldSimplify: true,
          recommendedFocusMinutes: 30,
        );

        final enforced = SiPolicy.enforce(decision);

        expect(enforced.action, 'First step. Second step.');
        expect(enforced.tone, 'calm');
        expect(enforced.recommendedFocusMinutes, 15);
      },
    );

    test('enforce leaves decision unchanged when shouldSimplify is false', () {
      const decision = SiDecisionEntity(
        rationale: 'No simplification',
        action: 'Keep it',
        shouldSimplify: false,
        recommendedFocusMinutes: 25,
        tone: 'adaptive',
      );

      final enforced = SiPolicy.enforce(decision);

      expect(enforced.action, 'Keep it');
      expect(enforced.tone, 'adaptive');
      expect(enforced.recommendedFocusMinutes, 25);
    });

    test('enforce keeps empty action empty when simplifying', () {
      const decision = SiDecisionEntity(
        rationale: 'Empty action edge',
        action: '',
        shouldSimplify: true,
      );

      final enforced = SiPolicy.enforce(decision);

      expect(enforced.action, '');
      expect(enforced.tone, 'calm');
    });

    test('enforce keeps short action unchanged when simplifying', () {
      const decision = SiDecisionEntity(
        rationale: 'Short action edge',
        action: 'One step. Two step.',
        shouldSimplify: true,
      );

      final enforced = SiPolicy.enforce(decision);

      expect(enforced.action, 'One step. Two step.');
    });

    test(
      'enforce keeps focus minutes unchanged when already at or below cap',
      () {
        const decision = SiDecisionEntity(
          rationale: 'Focus minute cap false branch',
          action: 'Simple action',
          shouldSimplify: true,
          recommendedFocusMinutes: 10,
        );

        final enforced = SiPolicy.enforce(decision);

        expect(enforced.recommendedFocusMinutes, 10);
      },
    );

    test('blocks unsupported or unsafe claims', () {
      const unsafe = SiDecisionEntity(
        rationale: 'I can diagnose your condition and guarantee results.',
        action: 'Proceed with medical-grade fix.',
      );

      expect(SiPolicy.isSupportedAndSafe(unsafe), isFalse);
    });

    test('rejects output with missing context', () {
      expect(
        SiPolicy.hasRequiredContext(
          hasCurrentContext: true,
          hasSettings: true,
          hasLogs: false,
          withinSubscriptionLimits: true,
        ),
        isFalse,
      );
      expect(
        SiPolicy.hasRequiredContext(
          hasCurrentContext: true,
          hasSettings: true,
          hasLogs: true,
          withinSubscriptionLimits: true,
        ),
        isTrue,
      );
    });

    test('reduces suggestion volume when overloaded', () {
      const decision = SiDecisionEntity(
        rationale: 'Many options',
        action: 'Pick one next step.',
        orderedTaskIds: <String>['t1', 't2', 't3', 't4'],
        recommendedFocusMinutes: 25,
      );

      final throttled = SiPolicy.reduceSuggestionVolume(
        decision,
        overloaded: true,
        maxSuggestionsWhenOverloaded: 2,
      );

      expect(throttled.orderedTaskIds, <String>['t1', 't2']);
      expect(throttled.recommendedFocusMinutes, 10);
      expect(throttled.shouldSimplify, isTrue);
      expect(throttled.tone, 'calm');
    });
  });
}
