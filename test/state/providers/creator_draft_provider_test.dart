import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted guidance stages an ephemeral Creator preview', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final CreatorDraftPreview preview = CreatorDraftPreview.fromPlannerResponse(
      _response(),
      createdAt: DateTime.utc(2026, 8, 30, 12),
    );
    container.read(creatorDraftPreviewProvider.notifier).stage(preview);

    final CreatorDraftPreview? staged = container.read(
      creatorDraftPreviewProvider,
    );
    expect(staged, isNotNull);
    expect(staged!.id, 'planner-draft-1788091200000000');
    expect(staged.title, 'Focused pass');
    expect(staged.description, contains('Verify one release claim.'));
    expect(staged.description, contains('Why this plan:'));
    expect(staged.description, contains('Evidence reviewed:'));
    expect(staged.sourceOption, PlannerOptionKind.bestFit);
  });

  test('clarification cannot be staged as a Creator draft', () {
    final PlannerV2Response clarification = PlannerV2Response.clarification(
      whatIHeard: 'The planning target is unclear.',
      mattersMost: 'Clarify before acting.',
      verifiedEvidence: const <String>['No saved item was attached.'],
      question: 'Which saved task or goal should this plan support?',
      adaptationReceipt: _receipt(),
      origin: PlannerResponseOrigin.deterministic,
    );

    expect(
      () => CreatorDraftPreview.fromPlannerResponse(clarification),
      throwsStateError,
    );
  });

  test('draft provider has no persistence dependency or save hook', () {
    final String source = File(
      'lib/state/providers/creator_draft_provider.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('saveTask')));
    expect(source, isNot(contains('saveGoal')));
    expect(source, isNot(contains('Supabase')));
    expect(source, isNot(contains('Firebase')));
  });
}

PlannerV2Response _response() => PlannerV2Response(
  whatIHeard: 'You want to prepare release evidence.',
  mattersMost: 'A bounded release decision.',
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
      description: 'Verify two release claims.',
      estimatedMinutes: 40,
      tradeoff: 'Higher attention cost.',
    ),
  ],
  recommendedKind: PlannerOptionKind.bestFit,
  recommendationReason: 'The evidence supports one focused pass.',
  nextStep: 'Verify one release claim.',
  adaptationReceipt: _receipt(),
  origin: PlannerResponseOrigin.deterministic,
);

PlannerAdaptationReceipt _receipt() => PlannerAdaptationReceipt(
  userSetEnergy: 0.6,
  userSelectedEmotion: EmotionalState.calm,
  adjustments: const <String>['Used only explicit check-in inputs.'],
);
