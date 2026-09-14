import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guidance requires exactly the five calm action controls', () {
    final PlannerV2Response response = _guidance();

    expect(response.isClarification, isFalse);
    expect(response.controls, <PlannerActionControl>[
      PlannerActionControl.useThisPlan,
      PlannerActionControl.makeSmaller,
      PlannerActionControl.differentApproach,
      PlannerActionControl.whyThis,
      PlannerActionControl.evidence,
    ]);
  });

  test('clarification contains one question and no actionable plan', () {
    final PlannerV2Response response = PlannerV2Response.clarification(
      whatIHeard: 'You want help with something different.',
      mattersMost: 'Connecting the request to the right evidence.',
      verifiedEvidence: const <String>[
        'Saved evidence was checked and not attached.',
      ],
      question: 'Which saved task or goal should this plan support?',
      adaptationReceipt: _receipt(),
      origin: PlannerResponseOrigin.deterministic,
    );

    expect(response.isClarification, isTrue);
    expect(response.options, isEmpty);
    expect(response.controls, isEmpty);
    expect('?'.allMatches(response.toAccessibleText()).length, 1);
    expect(
      () => response.recommend(PlannerOptionKind.minimum, why: 'Not allowed.'),
      throwsStateError,
    );
  });

  test('clarification rejects more than one question', () {
    expect(
      () => PlannerV2Response.clarification(
        whatIHeard: 'The target is unclear.',
        mattersMost: 'Clarify first.',
        verifiedEvidence: const <String>['No evidence was attached.'],
        question: 'Is this about a task? Or a goal?',
        adaptationReceipt: _receipt(),
        origin: PlannerResponseOrigin.deterministic,
      ),
      throwsArgumentError,
    );
  });

  test(
    'conversation answers with the current action without the option report',
    () {
      final PlannerV2Response response = _guidance().copyWith(
        usefulQuestion: 'Which claim needs checking first?',
      );
      final String conversation = response.toConversationText();

      expect(conversation, startsWith(response.whatIHeard));
      expect(conversation, contains('Verify one release claim.'));
      expect(conversation, contains('Allow up to 20 minutes.'));
      expect(conversation, contains(response.recommendationReason));
      expect(conversation, endsWith('Which claim needs checking first?'));
      expect(conversation, isNot(contains('Open the release note.')));
      expect(
        conversation,
        isNot(contains('Verify and document two release claims.')),
      );
      expect(
        'Verify one release claim.'.allMatches(conversation),
        hasLength(1),
      );
    },
  );

  test(
    'spoken summary follows the selected action and includes its current duration',
    () {
      final PlannerV2Response response = _guidance().recommend(
        PlannerOptionKind.minimum,
        why: 'This is enough to get started.',
      );
      final String summary = response.toSpokenSummary();

      expect(summary, contains('Open the release note.'));
      expect(summary, contains('Allow up to 5 minutes.'));
      expect(summary, contains('This is enough to get started.'));
      expect(summary, isNot(contains('Verify one release claim.')));
      expect(summary, isNot(contains('What I heard')));
      expect(summary.length, lessThan(response.toAccessibleText().length));
    },
  );

  test(
    'full accessible response retains each option duration and tradeoff',
    () {
      final PlannerV2Response response = _guidance();
      final String full = response.toAccessibleText();

      for (final PlannerOption option in response.options) {
        expect(full, contains(option.description));
        expect(full, contains('${option.estimatedMinutes} minutes'));
        expect(full, contains(option.tradeoff));
      }
      expect(full, contains(response.verifiedEvidence.single));
    },
  );

  test(
    'Spanish response serializers preserve localized framing after selection',
    () {
      final PlannerV2Response response = _guidance().copyWith(
        languageCode: 'es-MX',
        whatIHeard: 'Necesitas preparar tu uniforme antes de salir.',
        nextStep: 'Pon el uniforme en tu bolsa.',
        recommendationReason: 'Así estará listo cuando tengas que salir.',
      );

      expect(
        response.toConversationText(),
        contains('Dedica como máximo 20 minutos.'),
      );
      expect(
        response.toSpokenSummary(),
        startsWith('Pon el uniforme en tu bolsa.'),
      );
      expect(response.toSpokenSummary(), isNot(contains('Allow up to')));
      expect(response.toAccessibleText(), contains('Lo que entendí:'));
      expect(response.toAccessibleText(), contains('Lo que implica:'));
      expect(response.toAccessibleText(), isNot(contains('What I heard:')));
      expect(
        response
            .recommend(PlannerOptionKind.minimum, why: 'Un primer paso.')
            .languageCode,
        'es-MX',
      );
    },
  );

  test(
    'resolved question can be explicitly removed without losing the plan',
    () {
      final PlannerV2Response response = _guidance().copyWith(
        usefulQuestion: 'What needs to change?',
      );

      expect(response.copyWith().usefulQuestion, 'What needs to change?');
      final PlannerV2Response resolved = response.copyWith(
        clearUsefulQuestion: true,
      );
      expect(resolved.usefulQuestion, isNull);
      expect(
        resolved.toConversationText(),
        isNot(contains('What needs to change?')),
      );
      expect(resolved.nextStep, response.nextStep);
    },
  );

  test(
    'clarification conversation and speech ask once without an actionable plan',
    () {
      final PlannerV2Response response = PlannerV2Response.clarification(
        whatIHeard: 'Necesitas llegar a tiempo.',
        mattersMost: 'Aclarar la hora de salida.',
        verifiedEvidence: const <String>['La hora de salida no está indicada.'],
        question: '¿A qué hora necesitas salir?',
        adaptationReceipt: _receipt(),
        origin: PlannerResponseOrigin.deterministic,
        languageCode: 'es',
      );

      expect(
        response.toConversationText(),
        'Necesitas llegar a tiempo.\n\n¿A qué hora necesitas salir?',
      );
      expect(response.toSpokenSummary(), response.toConversationText());
      expect(response.toAccessibleText(), contains('Para aclararlo:'));
    },
  );

  test(
    'adjustment snapshot preserves user objective and copies adjustment events',
    () {
      final List<PlannerAdjustment> events = <PlannerAdjustment>[
        const PlannerAdjustment(
          kind: PlannerAdjustmentKind.smaller,
          description: 'The user selected Make smaller.',
          previousMinutes: 20,
          currentMinutes: 5,
        ),
      ];
      final PlannerV2Response response = _guidance();
      final PlannerConversationSnapshot snapshot = PlannerConversationSnapshot(
        originalObjective: 'Help me check the release evidence.',
        currentPlan: response,
        adjustments: events,
      );
      events.clear();

      expect(snapshot.originalObjective, 'Help me check the release evidence.');
      expect(snapshot.currentPlan, same(response));
      expect(snapshot.adjustments.single.kind, PlannerAdjustmentKind.smaller);
      expect(() => snapshot.adjustments.clear(), throwsUnsupportedError);
    },
  );
  test(
    'user facts survive recommendation edits without retaining generated text',
    () {
      final List<String> corrections = <String>[
        'I only have two minutes.',
        'Do not use saved tasks.',
      ];
      final PlannerUserContext facts = PlannerUserContext(
        objective: 'Pack my uniform instead of folding a shirt.',
        corrections: corrections,
        savedContextDeclined: true,
        timeLimitMinutes: 2,
      );
      final PlannerV2Response response = _guidance().copyWith(
        userContext: facts,
      );
      final PlannerV2Response adjusted = response.recommend(
        PlannerOptionKind.minimum,
        why: 'The user selected Make smaller.',
      );
      final PlannerConversationSnapshot snapshot = PlannerConversationSnapshot(
        originalObjective: 'Fold a shirt.',
        currentPlan: adjusted,
        userContext: adjusted.userContext,
      );
      corrections.clear();

      expect(adjusted.userContext, same(facts));
      expect(
        snapshot.userContext?.objective,
        'Pack my uniform instead of folding a shirt.',
      );
      expect(snapshot.userContext?.timeLimitMinutes, 2);
      expect(snapshot.userContext?.savedContextDeclined, isTrue);
      expect(snapshot.userContext?.corrections, <String>[
        'I only have two minutes.',
        'Do not use saved tasks.',
      ]);
      expect(() => facts.corrections.clear(), throwsUnsupportedError);
      expect(facts.corrections, isNot(contains(adjusted.recommendationReason)));
    },
  );
}

PlannerV2Response _guidance() => PlannerV2Response(
  whatIHeard: 'You want to prepare release evidence.',
  mattersMost: 'A bounded, verified next step.',
  verifiedEvidence: const <String>['Release evidence matched the request.'],
  options: const <PlannerOption>[
    PlannerOption(
      kind: PlannerOptionKind.minimum,
      title: 'Small start',
      description: 'Open the release note.',
      estimatedMinutes: 5,
      tradeoff: 'Narrow progress.',
    ),
    PlannerOption(
      kind: PlannerOptionKind.bestFit,
      title: 'Focused pass',
      description: 'Verify one release claim.',
      estimatedMinutes: 20,
      tradeoff: 'Balanced effort.',
    ),
    PlannerOption(
      kind: PlannerOptionKind.stretch,
      title: 'Deep pass',
      description: 'Verify and document two release claims.',
      estimatedMinutes: 40,
      tradeoff: 'Higher attention cost.',
    ),
  ],
  recommendedKind: PlannerOptionKind.bestFit,
  recommendationReason: 'The evidence and capacity support one focused pass.',
  nextStep: 'Verify one release claim.',
  adaptationReceipt: _receipt(),
  origin: PlannerResponseOrigin.deterministic,
);

PlannerAdaptationReceipt _receipt() => PlannerAdaptationReceipt(
  userSetEnergy: 0.6,
  userSelectedEmotion: EmotionalState.calm,
  adjustments: const <String>['Used only explicit check-in inputs.'],
);
