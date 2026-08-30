import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmotionalSafetyPolicy', () {
    const Map<String, EmotionalSafetyRoute>
    corpus = <String, EmotionalSafetyRoute>{
      'I want to kill myself.': EmotionalSafetyRoute.immediateSafety,
      'Everyone would be better off without me.':
          EmotionalSafetyRoute.immediateSafety,
      'I do not want to wake up.': EmotionalSafetyRoute.immediateSafety,
      'I will not be here tomorrow.': EmotionalSafetyRoute.immediateSafety,
      'I took too many pills.': EmotionalSafetyRoute.immediateSafety,
      'He threatened to kill me and will not let me leave.':
          EmotionalSafetyRoute.immediateSafety,
      'Voices are telling me to hurt myself.':
          EmotionalSafetyRoute.immediateSafety,
      'Quiero quitarme la vida.': EmotionalSafetyRoute.immediateSafety,
      'Tome demasiadas pastillas.': EmotionalSafetyRoute.immediateSafety,
      'No estoy a salvo ahora.': EmotionalSafetyRoute.immediateSafety,
      'My father died and I am grieving.':
          EmotionalSafetyRoute.supportiveDistress,
      'I am having a panic attack.': EmotionalSafetyRoute.supportiveDistress,
      'My partner is abusive and controlling.':
          EmotionalSafetyRoute.supportiveDistress,
      'I hear voices and need help.': EmotionalSafetyRoute.supportiveDistress,
      'I feel hopeless and cannot cope.':
          EmotionalSafetyRoute.supportiveDistress,
      'Estoy de duelo.': EmotionalSafetyRoute.supportiveDistress,
      'Tengo un ataque de panico.': EmotionalSafetyRoute.supportiveDistress,
      'Mi pareja me controla y me amenaza.':
          EmotionalSafetyRoute.supportiveDistress,
      'I am exhausted, my kids need me, and a project is due tomorrow.':
          EmotionalSafetyRoute.routine,
      'Help me split the release checklist into two steps.':
          EmotionalSafetyRoute.routine,
    };

    for (final MapEntry<String, EmotionalSafetyRoute> item in corpus.entries) {
      test('routes "${item.key}" to ${item.value.name}', () {
        expect(EmotionalSafetyPolicy.assess(item.key).route, item.value);
      });
    }

    test('normalizes bounded adversarial spelling and punctuation', () {
      expect(
        EmotionalSafetyPolicy.assess('I want to k!ll myself.').route,
        EmotionalSafetyRoute.immediateSafety,
      );
      expect(
        EmotionalSafetyPolicy.assess('I will end.my.life tonight.').route,
        EmotionalSafetyRoute.immediateSafety,
      );
      expect(
        EmotionalSafetyPolicy.assess('I am su1c1dal.').route,
        EmotionalSafetyRoute.immediateSafety,
      );
    });

    test(
      'negation and clearly historical or third-person text pause safely',
      () {
        const List<String> inputs = <String>[
          'I am not suicidal, but I am overwhelmed.',
          'Years ago I tried to kill myself, but I am safe now.',
          'My friend said I want to die and asked me for help.',
          'The article says suicide prevention saves lives.',
        ];
        for (final String input in inputs) {
          expect(
            EmotionalSafetyPolicy.assess(input).route,
            EmotionalSafetyRoute.supportiveDistress,
            reason: input,
          );
        }
      },
    );

    test('assessment exposes only privacy-safe finding codes', () {
      const String raw = 'I took too many pills and need help now.';
      final EmotionalSafetyAssessment assessment = EmotionalSafetyPolicy.assess(
        raw,
      );

      expect(assessment.findingCodes, isNotEmpty);
      expect(assessment.findingCodes.join(' '), isNot(contains(raw)));
      expect(assessment.concerns, contains(EmotionalSafetyConcern.overdose));
    });

    test('legacy crisis boundary maps only immediate-safety routes', () {
      expect(CrisisDetectionPolicy.detects('I want to die.'), isTrue);
      expect(
        CrisisDetectionPolicy.detects('I am grieving and need support.'),
        isFalse,
      );
    });
  });
}
