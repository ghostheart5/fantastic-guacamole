import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    "allows object refusal: I cannot diagnose your condition or prescribe medication. Talk to your clinician.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose your condition or prescribe medication. Talk to your clinician.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows object refusal: I cannot diagnose your mental health condition or provide a prescription.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose your mental health condition or provide a prescription.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows object refusal: No puedo diagnosticar tu condicion ni prescribir medicamentos. Consulta con un profesional.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar tu condicion ni prescribir medicamentos. Consulta con un profesional.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows object refusal: No puedo diagnosticar tu salud mental ni proporcionar un diagnostico.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar tu salud mental ni proporcionar un diagnostico.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows object refusal: I cannot guarantee results or provide a diagnosis.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot guarantee results or provide a diagnosis.",
        ),
        isFalse,
      );
    },
  );
  test(
    "blocks new clause after refusal: I cannot diagnose your condition, but I prescribe medication.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose your condition, but I prescribe medication.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks new clause after refusal: I cannot diagnose your condition and I prescribe medication.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose your condition and I prescribe medication.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks new clause after refusal: I cannot diagnose your condition because I prescribe medication.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose your condition because I prescribe medication.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks new clause after refusal: No puedo diagnosticar tu condicion, pero te prescribo medicamentos.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar tu condicion, pero te prescribo medicamentos.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks new clause after refusal: No puedo diagnosticar tu condicion y yo prescribo medicamentos.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar tu condicion y yo prescribo medicamentos.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks new clause after refusal: I cannot diagnose your condition. I guarantee a cure.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose your condition. I guarantee a cure.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks new clause after refusal: No puedo diagnosticar tu condicion aunque esta rutina te curara.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar tu condicion aunque esta rutina te curara.",
        ),
        isTrue,
      );
    },
  );

  test(
    "allows noun refusal: I cannot guarantee a cure. Consult a clinician.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot guarantee a cure. Consult a clinician.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows noun refusal: I cannot provide a diagnosis. Consult a clinician.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot provide a diagnosis. Consult a clinician.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows noun refusal: I cannot give a medical diagnosis or prescribe medication.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot give a medical diagnosis or prescribe medication.",
        ),
        isFalse,
      );
    },
  );
  test("allows noun refusal: I cannot provide a prescription.", () {
    expect(
      SiPolicy.containsUnsupportedClaim("I cannot provide a prescription."),
      isFalse,
    );
  });
  test(
    "allows noun refusal: No puedo garantizar una cura. Consulta con un profesional.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo garantizar una cura. Consulta con un profesional.",
        ),
        isFalse,
      );
    },
  );
  test("allows noun refusal: No puedo proporcionar un diagn\u00f3stico.", () {
    expect(
      SiPolicy.containsUnsupportedClaim(
        "No puedo proporcionar un diagn\u00f3stico.",
      ),
      isFalse,
    );
  });
  test("allows noun refusal: No puedo ofrecer una prescripci\u00f3n.", () {
    expect(
      SiPolicy.containsUnsupportedClaim(
        "No puedo ofrecer una prescripci\u00f3n.",
      ),
      isFalse,
    );
  });
  test(
    "allows noun refusal: No puedo garantizar una cura ni proporcionar un diagn\u00f3stico.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo garantizar una cura ni proporcionar un diagn\u00f3stico.",
        ),
        isFalse,
      );
    },
  );
  test(
    "blocks noun claim after refusal: I cannot guarantee a cure. This will cure your illness.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot guarantee a cure. This will cure your illness.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks noun claim after refusal: I cannot provide a diagnosis, but my diagnosis is depression.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot provide a diagnosis, but my diagnosis is depression.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks noun claim after refusal: No puedo proporcionar un diagn\u00f3stico. Mi diagn\u00f3stico es depresi\u00f3n.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo proporcionar un diagn\u00f3stico. Mi diagn\u00f3stico es depresi\u00f3n.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks noun claim after refusal: No puedo garantizar una cura, pero esta rutina te curar\u00e1.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo garantizar una cura, pero esta rutina te curar\u00e1.",
        ),
        isTrue,
      );
    },
  );

  test(
    "allows explicit refusal: I cannot diagnose or prescribe. Please consult a qualified clinician.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose or prescribe. Please consult a qualified clinician.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows explicit refusal: I can\u2019t guarantee results. You can compare the options.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I can\u2019t guarantee results. You can compare the options.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows explicit refusal: We do not provide legal advice. Please consult a lawyer.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "We do not provide legal advice. Please consult a lawyer.",
        ),
        isFalse,
      );
    },
  );
  test(
    "allows explicit refusal: No puedo diagnosticar ni prescribir. Consulta con un profesional de salud.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar ni prescribir. Consulta con un profesional de salud.",
        ),
        isFalse,
      );
    },
  );
  test("allows explicit refusal: NO PODEMOS GARANTIZAR resultados.", () {
    expect(
      SiPolicy.containsUnsupportedClaim("NO PODEMOS GARANTIZAR resultados."),
      isFalse,
    );
  });
  test(
    "allows explicit refusal: No puedo ofrecer asesor\u00eda legal. Consulta a un abogado.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo ofrecer asesor\u00eda legal. Consulta a un abogado.",
        ),
        isFalse,
      );
    },
  );
  test(
    "blocks claim despite refusal: I cannot diagnose, but I prescribe this medication.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot diagnose, but I prescribe this medication.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks claim despite refusal: I cannot guarantee results. I guarantee a cure.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "I cannot guarantee results. I guarantee a cure.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks claim despite refusal: No puedo diagnosticar, pero te prescribo este medicamento.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar, pero te prescribo este medicamento.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks claim despite refusal: No puedo garantizar resultados. Esta rutina te curar\u00e1.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo garantizar resultados. Esta rutina te curar\u00e1.",
        ),
        isTrue,
      );
    },
  );
  test(
    "blocks claim despite refusal: No puedo diagnosticar. Mi diagn\u00f3stico es depresi\u00f3n.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar. Mi diagn\u00f3stico es depresi\u00f3n.",
        ),
        isTrue,
      );
    },
  );
  test("blocks claim despite refusal: I can diagnose your illness.", () {
    expect(
      SiPolicy.containsUnsupportedClaim("I can diagnose your illness."),
      isTrue,
    );
  });
  test(
    "blocks claim despite refusal: No puedo diagnosticar? Te diagnostico ansiedad.",
    () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          "No puedo diagnosticar? Te diagnostico ansiedad.",
        ),
        isTrue,
      );
    },
  );

  group('SiPolicy', () {
    test('shouldSuggestBreak triggers on high fatigue or low energy', () {
      final highFatigue = SiStateEntity(
        energy: 0.8,
        attention: 0.5,
        fatigue: 0.71,
      );
      final lowEnergy = SiStateEntity(
        energy: 0.29,
        attention: 0.5,
        fatigue: 0.2,
      );
      final balanced = SiStateEntity(energy: 0.5, attention: 0.5, fatigue: 0.5);

      expect(SiPolicy.shouldSuggestBreak(highFatigue), isTrue);
      expect(SiPolicy.shouldSuggestBreak(lowEnergy), isTrue);
      expect(SiPolicy.shouldSuggestBreak(balanced), isFalse);
    });

    test(
      'shouldPushAttention only when energy/attention high and fatigue low',
      () {
        final attentive = SiStateEntity(
          energy: 0.7,
          attention: 0.6,
          fatigue: 0.4,
        );
        final tired = SiStateEntity(energy: 0.7, attention: 0.6, fatigue: 0.6);

        expect(SiPolicy.shouldPushAttention(attentive), isTrue);
        expect(SiPolicy.shouldPushAttention(tired), isFalse);
      },
    );

    test(
      'enforce simplifies action, caps attention minutes, and sets calm tone',
      () {
        const decision = SiDecisionEntity(
          rationale: 'Need simplification',
          action: 'First step. Second step. Third step.',
          shouldSimplify: true,
          recommendedExecutionMinutes: 30,
        );

        final enforced = SiPolicy.enforce(decision);

        expect(enforced.action, 'First step. Second step.');
        expect(enforced.tone, 'calm');
        expect(enforced.recommendedExecutionMinutes, 15);
      },
    );

    test('enforce leaves decision unchanged when shouldSimplify is false', () {
      const decision = SiDecisionEntity(
        rationale: 'No simplification',
        action: 'Keep it',
        shouldSimplify: false,
        recommendedExecutionMinutes: 25,
        tone: 'adaptive',
      );

      final enforced = SiPolicy.enforce(decision);

      expect(enforced.action, 'Keep it');
      expect(enforced.tone, 'adaptive');
      expect(enforced.recommendedExecutionMinutes, 25);
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
      'enforce keeps attention minutes unchanged when already at or below cap',
      () {
        const decision = SiDecisionEntity(
          rationale: 'Attention minute cap false branch',
          action: 'Simple action',
          shouldSimplify: true,
          recommendedExecutionMinutes: 10,
        );

        final enforced = SiPolicy.enforce(decision);

        expect(enforced.recommendedExecutionMinutes, 10);
      },
    );

    test('blocks unsupported or unsafe claims', () {
      const unsafe = SiDecisionEntity(
        rationale: 'I can diagnose your condition and guarantee results.',
        action: 'Proceed with medical-grade fix.',
      );

      expect(SiPolicy.isSupportedAndSafe(unsafe), isFalse);
    });

    test('matches whole claims without blocking safe partial words', () {
      expect(
        SiPolicy.containsUnsupportedClaim('Your account is secure.'),
        isFalse,
      );
      expect(
        SiPolicy.containsUnsupportedClaim('The outcome is guaranteed.'),
        isTrue,
      );
      expect(SiPolicy.containsUnsupportedClaim('This is a diagnosis.'), isTrue);
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
        recommendedExecutionMinutes: 25,
      );

      final throttled = SiPolicy.reduceSuggestionVolume(
        decision,
        overloaded: true,
        maxSuggestionsWhenOverloaded: 2,
      );

      expect(throttled.orderedTaskIds, <String>['t1', 't2']);
      expect(throttled.recommendedExecutionMinutes, 10);
      expect(throttled.shouldSimplify, isTrue);
      expect(throttled.tone, 'calm');
    });

    test('preserves suggestion volume when load is supported', () {
      const decision = SiDecisionEntity(
        rationale: 'Current load supports the options.',
        action: 'Choose the best supported option.',
        orderedTaskIds: <String>['t1', 't2', 't3'],
        recommendedExecutionMinutes: 25,
      );

      expect(
        SiPolicy.reduceSuggestionVolume(decision, overloaded: false),
        same(decision),
      );
    });

    test('overload keeps an already-short execution window', () {
      const decision = SiDecisionEntity(
        rationale: 'Keep the existing short window.',
        action: 'Take one small step.',
        orderedTaskIds: <String>['t1', 't2'],
        recommendedExecutionMinutes: 8,
      );

      final SiDecisionEntity result = SiPolicy.reduceSuggestionVolume(
        decision,
        overloaded: true,
      );

      expect(result.recommendedExecutionMinutes, 8);
      expect(result.orderedTaskIds, <String>['t1', 't2']);
    });
  });
}
