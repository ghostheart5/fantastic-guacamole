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
