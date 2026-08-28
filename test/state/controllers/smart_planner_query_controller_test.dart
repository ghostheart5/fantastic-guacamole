import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer plannerContainer() => ProviderContainer(
    overrides: [
      assistantReleaseConfigProvider.overrideWith(
        (Ref ref) async => AssistantReleaseConfig(
          stage: AssistantReleaseStage.general,
          canaryBasisPoints: 0,
          shadowEvaluationEnabled: false,
          internalAccountDigests: const <String>{},
          rollbackCapabilities: const <AssistantReleaseCapability>{},
        ),
      ),
    ],
  );

  test('Planner V2 returns the complete typed response contract', () async {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final SmartPlannerResult result = await controller.requestPlanningGuidance(
      energy: 0.61,
      emotion: EmotionalState.calm,
      notes: 'I need to focus on the launch checklist',
      history: const <Map<String, String>>[],
      previousSavedNotes: 'must not be reused or changed',
    );

    final PlannerV2Response response = result.plannerResponse;
    expect(response.whatIHeard, contains('launch checklist'));
    expect(response.mattersMost, isNotEmpty);
    expect(response.verifiedEvidence, hasLength(4));
    expect(
      response.options.map((PlannerOption option) => option.kind),
      containsAllInOrder(PlannerOptionKind.values),
    );
    expect(response.recommendedOption.kind, PlannerOptionKind.bestFit);
    expect(response.recommendationReason, isNotEmpty);
    expect(response.nextStep, isNotEmpty);
    expect(response.usefulQuestion, isNotEmpty);
    expect(response.adaptationReceipt.energyPercent, 61);
    expect(response.adaptationReceipt.userSelectedEmotion, EmotionalState.calm);
    expect(response.controls, containsAll(PlannerActionControl.values));
    expect(response.origin, PlannerResponseOrigin.deterministic);
    expect(result.savedNotes, isNull);
    expect(result.processingMode, AIProcessingMode.onDevice);
    expect(result.evidence, contains(contains('not AI-generated')));
    result.request.validate();
    result.response.validateAgainst(result.request);
    result.evidenceManifest.validateAgainstResponse(result.response);
    expect(
      result.safetyReceipt.disposition,
      AssistantSafetyDisposition.approved,
    );
  });

  test(
    'low energy and anxious self-report recommend Minimum without inference',
    () async {
      final ProviderContainer container = plannerContainer();
      addTearDown(container.dispose);
      final SmartPlannerQueryController controller = container.read(
        smartPlannerQueryControllerProvider,
      );

      final SmartPlannerResult result = await controller
          .requestPlanningGuidance(
            energy: 0.31,
            emotion: EmotionalState.anxious,
            notes: 'My work deadline feels overloaded',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(result.plannerResponse.recommendedKind, PlannerOptionKind.minimum);
      expect(
        result.plannerResponse.adaptationReceipt.adjustments,
        contains(
          'Used only your selected emotion; no emotion was inferred from your text.',
        ),
      );
      expect(result.message, contains('Minimum:'));
      expect(result.message, contains('Best-fit:'));
      expect(result.message, contains('Stretch:'));
    },
  );

  test('fatigued recovery guidance uses clear actionable language', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final PlannerV2Response response = controller.buildPlannerResponse(
      input: 'im tired',
      energy: 0.3,
      emotion: EmotionalState.fatigued,
      contextWasProvided: true,
    );

    expect(response.recommendedKind, PlannerOptionKind.minimum);
    expect(response.recommendedOption.title, 'Protect your energy');
    expect(
      response.recommendedOption.tradeoff,
      'This may delay one low-priority task, but it protects your energy right now.',
    );
    expect(
      response.nextStep,
      'Choose one nonessential task to postpone. Then take a five-minute quiet break.',
    );
    expect(response.nextStep, isNot(contains('im tired')));
  });

  test('high energy and engaged self-report can recommend Stretch', () async {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final PlannerV2Response response =
        (await controller.requestPlanningGuidance(
          energy: 0.9,
          emotion: EmotionalState.engaged,
          notes: 'Advance the next goal milestone',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        )).plannerResponse;

    expect(response.recommendedKind, PlannerOptionKind.stretch);
    expect(response.recommendedOption.estimatedMinutes, 60);
  });

  test('follow-up uses the same read-only typed contract', () async {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final SmartPlannerResult result = await controller.requestFollowUpResult(
      input: 'Can you make the habit easier to repeat?',
      energy: 0.45,
      emotion: EmotionalState.neutral,
      reflection: 'private reflection that must not be persisted',
      history: const <Map<String, String>>[],
    );

    expect(result.request.kind, AssistantRequestKind.followUp);
    expect(result.savedNotes, isNull);
    expect(result.plannerResponse.options, hasLength(3));
    expect(result.plannerResponse.origin, PlannerResponseOrigin.deterministic);
  });

  test('local timeout result stays explicit and typed', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final SmartPlannerResult result = controller.localFallbackResult(
      input: 'Plan this task',
      message: 'The request timed out.',
      energy: 0.5,
      emotion: EmotionalState.neutral,
      history: const <Map<String, String>>[],
      reason: 'request_timeout',
    );

    expect(result.processingMode, AIProcessingMode.onDeviceFallback);
    expect(result.plannerResponse.mattersMost, 'The request timed out.');
    expect(result.evidence, contains(contains('request_timeout')));
  });

  test('Planner request path has no hidden write or stateful model hooks', () {
    final String source = File(
      'lib/state/controllers/smart_planner_query_controller.dart',
    ).readAsStringSync();
    const List<String> forbidden = <String>[
      'appendSiReflection',
      'saveMirroredMemory',
      'replaceState(',
      'emotionProvider.notifier',
      '_persistConversationTurn',
      'savePlannerMessageUseCaseProvider',
      'smartPlannerAiResponseProvider',
      'smartPlannerAiInputProvider',
      'planProposalProvider',
      'timelineActionsProvider',
      'awardXp',
    ];
    for (final String token in forbidden) {
      expect(source, isNot(contains(token)), reason: 'Forbidden hook: $token');
    }
    expect(source, contains("'persistenceMode': 'ephemeral_read_only'"));
  });

  test('Planner screen has no hidden persistence, analytics, or apply hooks', () {
    final String source = File(
      'lib/features/home/ui/smart_planner_screen.dart',
    ).readAsStringSync();
    const List<String> forbidden = <String>[
      'planProposalProvider',
      'Apply to Timeline',
      'appendSiReflection',
      'adaptiveGuidanceProvider',
      'AppAnalytics.track',
      'extendedDomainBootstrapProvider',
      'memoriesActionsProvider',
      'timelineActionsProvider',
    ];
    for (final String token in forbidden) {
      expect(source, isNot(contains(token)), reason: 'Forbidden hook: $token');
    }
    expect(
      source,
      contains(
        'Used only for this check-in. Nothing is saved unless you explicitly remember a preference.',
      ),
    );
  });

  test('crisis detection remains active before planning', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    expect(controller.detectsCrisis('I want to kill myself tonight'), isTrue);
    expect(controller.detectsCrisis('I had a difficult day'), isFalse);
  });

  test('direct crisis request cannot enter ordinary planning', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    await expectLater(
      controller.requestPlanningGuidance(
        energy: 0.7,
        emotion: EmotionalState.anxious,
        notes: 'I want to kill myself tonight',
        history: const <Map<String, String>>[],
        previousSavedNotes: null,
      ),
      throwsA(
        isA<AssistantSafetyRouteException>().having(
          (AssistantSafetyRouteException error) => error.code,
          'code',
          'crisis_route_required',
        ),
      ),
    );
  });
}
