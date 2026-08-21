import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smartPlannerQueryControllerProvider =
    Provider<SmartPlannerQueryController>((Ref ref) {
      return SmartPlannerQueryController(ref);
    });

class SmartPlannerResult {
  factory SmartPlannerResult({
    required String prompt,
    required String message,
    required String? savedNotes,
    AIProcessingMode processingMode = AIProcessingMode.onDevice,
    List<String> evidence = const <String>[],
    DateTime? generatedAt,
    PlannerV2Response? plannerResponse,
  }) {
    final DateTime created = (generatedAt ?? DateTime.now()).toUtc();
    final AssistantRequestEnvelope request = createAssistantRequestEnvelope(
      accountScopeId: 'account.compatibility',
      conversation: AssistantConversationScope.primarySmartPlanner,
      kind: AssistantRequestKind.planningGuidance,
      input: prompt,
      now: created,
    );
    final PlannerV2Response resolvedResponse =
        plannerResponse ??
        _compatibilityPlannerResponse(
          prompt: prompt,
          message: message,
          evidence: evidence,
          processingMode: processingMode,
        );
    final AIRecommendation recommendation =
        AIRecommendation(
          message: message,
          processingMode: processingMode,
        ).withValidatedContract(
          request: request,
          evidence: createAssistantEvidenceItems(
            request: request,
            summaries: evidence.isEmpty
                ? resolvedResponse.verifiedEvidence
                : evidence,
            sourceId: 'compatibility_result',
            kind: AssistantEvidenceKind.fallback,
            observedAt: created,
          ),
          generatedAt: created,
          status: processingMode == AIProcessingMode.onDeviceFallback
              ? AssistantResponseStatus.fallback
              : AssistantResponseStatus.completed,
        );
    final AssistantSafetyReceipt safetyReceipt = _requirePublishableSafety(
      const AssistantSafetyPipeline().evaluate(
        AssistantSafetyReview(
          requestId: request.requestId,
          accountScopeId: request.accountScopeId,
          surface: AssistantSafetySurface.smartPlanner,
          responseText: recommendation.contract!.message,
          evidenceIds: recommendation.contract!.evidence.items.map(
            (AssistantEvidenceItem item) => item.evidenceId,
          ),
          authority: AssistantActionAuthority.proposalOnly,
          risk: AssistantSafetyRisk.routine,
        ),
      ),
    );
    return SmartPlannerResult.fromContracts(
      request: request,
      response: recommendation.contract!,
      evidenceManifest: recommendation.evidenceManifest!,
      safetyReceipt: safetyReceipt,
      savedNotes: savedNotes,
      plannerResponse: resolvedResponse,
    );
  }

  SmartPlannerResult.fromContracts({
    required this.request,
    required this.response,
    required this.evidenceManifest,
    required this.safetyReceipt,
    required this.savedNotes,
    required this.plannerResponse,
  }) {
    response.validateAgainst(request);
    evidenceManifest.validateAgainstRequest(request);
    evidenceManifest.validateAgainstResponse(response);
    if (safetyReceipt.requestId != request.requestId ||
        safetyReceipt.accountScopeId != request.accountScopeId ||
        safetyReceipt.surface != AssistantSafetySurface.smartPlanner ||
        safetyReceipt.disposition == AssistantSafetyDisposition.withheld ||
        safetyReceipt.disposition == AssistantSafetyDisposition.crisisRoute) {
      throw StateError('Smart Planner response failed its safety boundary.');
    }
  }

  final AssistantRequestEnvelope request;
  final AssistantResponseEnvelope response;
  final AssistantEvidenceManifest evidenceManifest;
  final AssistantSafetyReceipt safetyReceipt;
  final String? savedNotes;
  final PlannerV2Response plannerResponse;

  String get prompt => request.input;
  String get message => response.message;
  AIProcessingMode get processingMode => switch (response.processingMode) {
    AssistantContractProcessingMode.unknown => AIProcessingMode.unknown,
    AssistantContractProcessingMode.onDevice => AIProcessingMode.onDevice,
    AssistantContractProcessingMode.external => AIProcessingMode.external,
    AssistantContractProcessingMode.onDeviceFallback =>
      AIProcessingMode.onDeviceFallback,
  };
  List<String> get evidence => response.evidence.items
      .map((AssistantEvidenceItem item) => item.summary)
      .toList(growable: false);
  DateTime get generatedAt => response.generatedAt;
}

class SmartPlannerQueryController
    implements SmartPlannerInterface<SmartPlannerResult> {
  const SmartPlannerQueryController(this._ref);

  final Ref _ref;

  String get _accountScopeId {
    final AccountStorageScope scope = _ref.read(accountStorageScopeProvider);
    return assistantAccountScopeId(
      authenticatedNamespace: scope.v2Namespace,
      isSignedOut: scope.state == AccountStorageScopeState.signedOut,
    );
  }

  bool detectsCrisis(String text) => CrisisDetectionPolicy.detects(text);

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    final String prompt = notes.trim().isEmpty
        ? 'Give me a practical planning check-in for my current energy and emotional state.'
        : notes.trim();
    _requireNonCrisisRoute(prompt);
    final AssistantRequestEnvelope request = _requestContract(
      kind: AssistantRequestKind.planningGuidance,
      input: prompt,
      history: history,
      energy: energy,
      emotion: emotion,
    );
    final PlannerV2Response response = buildPlannerResponse(
      input: prompt,
      energy: energy,
      emotion: emotion,
      contextWasProvided: notes.trim().isNotEmpty,
    );
    return _resultFromResponse(
      request: request,
      response: response,
      sourceId: 'planner_v2_deterministic',
    );
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    return (await requestFollowUpResult(
      input: input,
      energy: energy,
      emotion: emotion,
      reflection: reflection,
      history: history,
    )).message;
  }

  Future<SmartPlannerResult> requestFollowUpResult({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    final String prompt = input.trim();
    _requireNonCrisisRoute(prompt);
    final AssistantRequestEnvelope request = _requestContract(
      kind: AssistantRequestKind.followUp,
      input: prompt,
      history: history,
      energy: energy,
      emotion: emotion,
    );
    final PlannerV2Response response = buildPlannerResponse(
      input: prompt,
      energy: energy,
      emotion: emotion,
      contextWasProvided: true,
    );
    return _resultFromResponse(
      request: request,
      response: response,
      sourceId: 'planner_v2_follow_up_deterministic',
    );
  }

  SmartPlannerResult localFallbackResult({
    required String input,
    required String message,
    required double energy,
    required EmotionalState emotion,
    required List<Map<String, String>> history,
    required String reason,
    AssistantRequestKind kind = AssistantRequestKind.planningGuidance,
  }) {
    _requireNonCrisisRoute(input);
    final AssistantRequestEnvelope request = _requestContract(
      kind: kind,
      input: input,
      history: history,
      energy: energy,
      emotion: emotion,
      context: <String, Object?>{'fallbackReason': reason},
    );
    final PlannerV2Response base = buildPlannerResponse(
      input: input,
      energy: energy,
      emotion: emotion,
      contextWasProvided: input.trim().isNotEmpty,
    );
    final PlannerV2Response response = base.copyWith(
      mattersMost: message,
      recommendationReason: 'The normal Planner V2 request did not complete.',
      verifiedEvidence: <String>[
        ...base.verifiedEvidence,
        'Fallback reason: $reason',
      ],
    );
    return _resultFromResponse(
      request: request,
      response: response,
      sourceId: 'planner_v2_local_fallback',
      status: AssistantResponseStatus.fallback,
    );
  }

  PlannerV2Response buildPlannerResponse({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required bool contextWasProvided,
  }) {
    final double boundedEnergy = energy.clamp(0.0, 1.0);
    final String normalized = input.trim();
    final _PlannerTopic topic = _detectTopic(normalized);
    final _PlannerStrategy strategy = _strategyFor(topic);
    final _EffortProfile effort = _effortFor(boundedEnergy);
    final PlannerOptionKind recommendation = _recommendedKind(
      energy: boundedEnergy,
      emotion: emotion,
    );
    final String subject = contextWasProvided
        ? _condense(normalized, maxLength: 72)
        : 'finding one useful next move';

    final List<PlannerOption> options = <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: strategy.minimumTitle,
        description: strategy.minimumAction(subject),
        estimatedMinutes: effort.minimumMinutes,
        tradeoff:
            'Lowest activation cost; it creates traction but limited depth.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: strategy.bestFitTitle,
        description: strategy.bestFitAction(subject),
        estimatedMinutes: effort.bestFitMinutes,
        tradeoff:
            'Balances meaningful progress with the capacity you reported.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: strategy.stretchTitle,
        description: strategy.stretchAction(subject),
        estimatedMinutes: effort.stretchMinutes,
        tradeoff:
            'Creates more progress now, with a higher energy and attention cost.',
      ),
    ];
    final PlannerOption selected = options.singleWhere(
      (PlannerOption option) => option.kind == recommendation,
    );
    final List<String> adaptations = <String>[
      _energyAdaptation(boundedEnergy, effort),
      _emotionAdaptation(emotion),
      'Used only your selected emotion; no emotion was inferred from your text.',
      'Kept every option reversible and left saving to an explicit Creator confirmation.',
    ];
    final String receiptLabel = _emotionLabel(emotion);

    return PlannerV2Response(
      whatIHeard: contextWasProvided
          ? 'You want a workable way forward on: $subject.'
          : 'You want a practical check-in that fits your current capacity.',
      mattersMost: strategy.mattersMost,
      verifiedEvidence: <String>[
        'Current check-in energy set by you: ${(boundedEnergy * 100).round()}%.',
        'Current check-in emotional state selected by you: $receiptLabel.',
        contextWasProvided
            ? 'Planning context was supplied for this check-in; it was not saved as a reflection or memory.'
            : 'No planning context was supplied, so no stored context was assumed.',
        'No Timeline, memory, SI-state, XP, task, goal, or habit record was changed.',
      ],
      options: options,
      recommendedKind: recommendation,
      recommendationReason: _recommendationReason(
        recommendation,
        boundedEnergy,
        emotion,
      ),
      nextStep: selected.description,
      usefulQuestion: strategy.question,
      adaptationReceipt: PlannerAdaptationReceipt(
        userSetEnergy: boundedEnergy,
        userSelectedEmotion: emotion,
        adjustments: adaptations,
      ),
      origin: PlannerResponseOrigin.deterministic,
    );
  }

  AssistantRequestEnvelope _requestContract({
    required AssistantRequestKind kind,
    required String input,
    required List<Map<String, String>> history,
    required double energy,
    required EmotionalState emotion,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return createAssistantRequestEnvelope(
      accountScopeId: _accountScopeId,
      conversation: AssistantConversationScope.primarySmartPlanner,
      kind: kind,
      input: input,
      history: history,
      context: <String, Object?>{
        'energy': energy,
        'emotion': emotion.name,
        'responseContract': 'planner_v2',
        'persistenceMode': 'ephemeral_read_only',
        ...context,
      },
    );
  }

  SmartPlannerResult _resultFromResponse({
    required AssistantRequestEnvelope request,
    required PlannerV2Response response,
    required String sourceId,
    AssistantResponseStatus status = AssistantResponseStatus.completed,
  }) {
    final List<String> evidence = <String>[
      ...response.verifiedEvidence,
      'Origin: deterministic on-device Planner V2; not AI-generated.',
    ];
    final AIRecommendation recommendation =
        AIRecommendation(
          message: response.toAccessibleText(),
          reasoning: 'planner_v2_read_only_contract',
          processingMode: status == AssistantResponseStatus.fallback
              ? AIProcessingMode.onDeviceFallback
              : AIProcessingMode.onDevice,
        ).withValidatedContract(
          request: request,
          evidence: createAssistantEvidenceItems(
            request: request,
            summaries: evidence,
            sourceId: sourceId,
            kind: status == AssistantResponseStatus.fallback
                ? AssistantEvidenceKind.fallback
                : AssistantEvidenceKind.policy,
          ),
          status: status,
        );
    recommendation.validateContractAgainst(request);
    final _PlannerTopic topic = _detectTopic(request.input);
    final AssistantSafetyRisk risk =
        topic == _PlannerTopic.health || topic == _PlannerTopic.wellbeing
        ? AssistantSafetyRisk.highImpact
        : AssistantSafetyRisk.routine;
    final AssistantSafetyReceipt safetyReceipt = _requirePublishableSafety(
      const AssistantSafetyPipeline().evaluate(
        AssistantSafetyReview(
          requestId: request.requestId,
          accountScopeId: request.accountScopeId,
          surface: AssistantSafetySurface.smartPlanner,
          responseText: recommendation.contract!.message,
          evidenceIds: recommendation.contract!.evidence.items.map(
            (AssistantEvidenceItem item) => item.evidenceId,
          ),
          authority: AssistantActionAuthority.proposalOnly,
          risk: risk,
        ),
      ),
    );
    return SmartPlannerResult.fromContracts(
      request: request,
      response: recommendation.contract!,
      evidenceManifest: recommendation.evidenceManifest!,
      safetyReceipt: safetyReceipt,
      savedNotes: null,
      plannerResponse: response,
    );
  }

  void _requireNonCrisisRoute(String input) {
    if (detectsCrisis(input)) {
      throw const AssistantSafetyRouteException(
        'crisis_route_required',
        'Smart Planner must show the dedicated crisis support route.',
      );
    }
  }

  static PlannerOptionKind _recommendedKind({
    required double energy,
    required EmotionalState emotion,
  }) {
    if (energy < 0.42 ||
        emotion == EmotionalState.fatigued ||
        emotion == EmotionalState.anxious ||
        emotion == EmotionalState.scattered ||
        emotion == EmotionalState.negative) {
      return PlannerOptionKind.minimum;
    }
    if (energy >= 0.82 &&
        (emotion == EmotionalState.energized ||
            emotion == EmotionalState.engaged)) {
      return PlannerOptionKind.stretch;
    }
    return PlannerOptionKind.bestFit;
  }

  static String _recommendationReason(
    PlannerOptionKind kind,
    double energy,
    EmotionalState emotion,
  ) => switch (kind) {
    PlannerOptionKind.minimum =>
      'Your ${(energy * 100).round()}% energy and selected ${_emotionLabel(emotion)} state favor a low-friction start that preserves capacity.',
    PlannerOptionKind.bestFit =>
      'Your reported capacity supports meaningful progress without committing to the highest-cost option.',
    PlannerOptionKind.stretch =>
      'Your ${(energy * 100).round()}% energy and selected ${_emotionLabel(emotion)} state can support a deeper work cycle, while the smaller options remain available.',
  };

  static _EffortProfile _effortFor(double energy) {
    if (energy < 0.42) {
      return const _EffortProfile(3, 10, 20);
    }
    if (energy < 0.75) {
      return const _EffortProfile(5, 20, 40);
    }
    return const _EffortProfile(5, 30, 60);
  }

  static String _energyAdaptation(double energy, _EffortProfile effort) {
    return 'Scaled the spectrum to ${(energy * 100).round()}% energy: '
        '${effort.minimumMinutes}, ${effort.bestFitMinutes}, and '
        '${effort.stretchMinutes} minute options.';
  }

  static String _emotionAdaptation(EmotionalState emotion) => switch (emotion) {
    EmotionalState.fatigued =>
      'Reduced activation cost because you selected fatigued.',
    EmotionalState.anxious =>
      'Favored a bounded first move because you selected anxious.',
    EmotionalState.scattered =>
      'Reduced choice load because you selected scattered.',
    EmotionalState.negative =>
      'Kept the recommendation small and reversible because you selected negative.',
    EmotionalState.energized =>
      'Made a deeper option available because you selected energized.',
    EmotionalState.engaged =>
      'Allowed a longer focus cycle because you selected engaged.',
    EmotionalState.calm => 'Preserved a steady pace because you selected calm.',
    EmotionalState.positive =>
      'Kept momentum available without assuming extra capacity because you selected positive.',
    EmotionalState.neutral =>
      'Used a balanced default because you selected neutral.',
  };

  static String _emotionLabel(EmotionalState emotion) => emotion.name;

  static _PlannerTopic _detectTopic(String input) {
    final String value = input.toLowerCase();
    bool hasAny(List<String> terms) => terms.any(value.contains);
    if (hasAny(<String>['overwhelm', 'overloaded', 'too much', 'burnout'])) {
      return _PlannerTopic.overwhelm;
    }
    if (hasAny(<String>['habit', 'routine', 'consistent', 'discipline'])) {
      return _PlannerTopic.habit;
    }
    if (hasAny(<String>['sleep', 'tired', 'fatigue', 'recover', 'rest'])) {
      return _PlannerTopic.recovery;
    }
    if (hasAny(<String>['stress', 'anxious', 'emotion', 'worry'])) {
      return _PlannerTopic.wellbeing;
    }
    if (hasAny(<String>['goal', 'milestone', 'outcome', 'future'])) {
      return _PlannerTopic.goal;
    }
    if (hasAny(<String>['focus', 'procrast', 'deadline', 'work', 'task'])) {
      return _PlannerTopic.focus;
    }
    if (hasAny(<String>[
      'health',
      'weight',
      'exercise',
      'nutrition',
      'water',
    ])) {
      return _PlannerTopic.health;
    }
    return _PlannerTopic.general;
  }

  static _PlannerStrategy _strategyFor(_PlannerTopic topic) => switch (topic) {
    _PlannerTopic.overwhelm => _PlannerStrategy(
      minimumTitle: 'Shrink the active field',
      bestFitTitle: 'Triage then move',
      stretchTitle: 'Reset the whole workload',
      mattersMost: 'Reducing active demands before adding more effort.',
      minimumAction: (String subject) =>
          'Write down the single result that would make $subject feel lighter, then stop.',
      bestFitAction: (String subject) =>
          'List the active demands in $subject, defer two, and spend one bounded block on the remaining priority.',
      stretchAction: (String subject) =>
          'Map every active demand in $subject, assign defer, delegate, or do, then complete the first do item.',
      question: 'Which demand has the largest consequence if it waits?',
    ),
    _PlannerTopic.habit => _PlannerStrategy(
      minimumTitle: 'Prove the smallest repeat',
      bestFitTitle: 'Run one complete repetition',
      stretchTitle: 'Design the repeatable system',
      mattersMost:
          'Making the behavior easy enough to repeat, not impressive once.',
      minimumAction: (String subject) =>
          'Do the two-minute version of $subject and mark the stopping point.',
      bestFitAction: (String subject) =>
          'Complete one realistic repetition of $subject and identify the cue that started it.',
      stretchAction: (String subject) =>
          'Complete $subject, then define its cue, minimum version, and recovery rule for a missed day.',
      question: 'What existing moment could reliably cue this behavior?',
    ),
    _PlannerTopic.recovery => _PlannerStrategy(
      minimumTitle: 'Lower the load',
      bestFitTitle: 'Protect one recovery block',
      stretchTitle: 'Rebuild the day around recovery',
      mattersMost: 'Protecting capacity before demanding performance.',
      minimumAction: (String subject) =>
          'Remove one nonessential demand from $subject and take a brief quiet pause.',
      bestFitAction: (String subject) =>
          'Create one protected recovery block, then reassess what part of $subject is still realistic.',
      stretchAction: (String subject) =>
          'Re-plan the remaining day around recovery, essential commitments, food, hydration, and sleep opportunity.',
      question: 'What commitment can be reduced without creating real harm?',
    ),
    _PlannerTopic.wellbeing => _PlannerStrategy(
      minimumTitle: 'Create one stable edge',
      bestFitTitle: 'Name, bound, and act',
      stretchTitle: 'Build a support plan',
      mattersMost:
          'Creating safety and clarity without treating planning as diagnosis or care.',
      minimumAction: (String subject) =>
          'Name the immediate concern in $subject and choose one action fully within your control.',
      bestFitAction: (String subject) =>
          'Separate facts, fears, and controllable actions in $subject, then complete the smallest controllable action.',
      stretchAction: (String subject) =>
          'Map controllable actions, support people, and professional help if needed, then take the first support step.',
      question:
          'What is true right now, separate from what you fear might happen?',
    ),
    _PlannerTopic.goal => _PlannerStrategy(
      minimumTitle: 'Define the next visible proof',
      bestFitTitle: 'Advance one milestone',
      stretchTitle: 'Map the milestone chain',
      mattersMost: 'Turning the desired outcome into observable progress.',
      minimumAction: (String subject) =>
          'Write one visible result that would prove $subject moved forward.',
      bestFitAction: (String subject) =>
          'Choose the nearest milestone for $subject and complete its first concrete action.',
      stretchAction: (String subject) =>
          'Map the next three milestones for $subject, identify dependencies, and start milestone one.',
      question: 'What result would count as real progress by the end of today?',
    ),
    _PlannerTopic.focus => _PlannerStrategy(
      minimumTitle: 'Expose the first move',
      bestFitTitle: 'Run one protected focus block',
      stretchTitle: 'Complete a full work cycle',
      mattersMost:
          'Removing ambiguity from the first action and protecting attention.',
      minimumAction: (String subject) =>
          'Open the material for $subject and write the first concrete action.',
      bestFitAction: (String subject) =>
          'Silence interruptions and complete one bounded focus block on $subject.',
      stretchAction: (String subject) =>
          'Complete a focus block on $subject, review the result, and finish the next linked action.',
      question: 'What exact artifact should exist when this work block ends?',
    ),
    _PlannerTopic.health => _PlannerStrategy(
      minimumTitle: 'Choose one low-risk behavior',
      bestFitTitle: 'Run one observable health action',
      stretchTitle: 'Prepare a sustainable health plan',
      mattersMost:
          'Choosing a safe, observable behavior without making a diagnosis.',
      minimumAction: (String subject) =>
          'Choose one low-risk action related to $subject that fits known medical guidance for you.',
      bestFitAction: (String subject) =>
          'Complete one measurable action for $subject and note the result for your own review.',
      stretchAction: (String subject) =>
          'Define a repeatable action for $subject and list any medical questions to verify with a qualified professional.',
      question:
          'Are there medical restrictions or professional instructions this plan must respect?',
    ),
    _PlannerTopic.general => _PlannerStrategy(
      minimumTitle: 'Name the next move',
      bestFitTitle: 'Complete one useful cycle',
      stretchTitle: 'Build momentum with review',
      mattersMost: 'Converting uncertainty into a specific, reversible action.',
      minimumAction: (String subject) =>
          'Write the smallest visible action for $subject and prepare what it needs.',
      bestFitAction: (String subject) =>
          'Complete one bounded action cycle for $subject, then stop and review.',
      stretchAction: (String subject) =>
          'Complete two linked action cycles for $subject and capture the next decision.',
      question: 'What outcome matters most right now?',
    ),
  };

  static String _condense(String value, {required int maxLength}) {
    final String singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) {
      return singleLine;
    }
    return '${singleLine.substring(0, maxLength - 1).trimRight()}…';
  }
}

AssistantSafetyReceipt _requirePublishableSafety(
  AssistantSafetyOutcome outcome,
) {
  if (!outcome.mayPublish) {
    throw const AssistantSafetyRouteException(
      'assistant_response_withheld',
      'The response did not pass the assistant safety boundary.',
    );
  }
  return outcome.receipt;
}

enum _PlannerTopic {
  overwhelm,
  habit,
  recovery,
  wellbeing,
  goal,
  focus,
  health,
  general,
}

final class _EffortProfile {
  const _EffortProfile(
    this.minimumMinutes,
    this.bestFitMinutes,
    this.stretchMinutes,
  );

  final int minimumMinutes;
  final int bestFitMinutes;
  final int stretchMinutes;
}

final class _PlannerStrategy {
  const _PlannerStrategy({
    required this.minimumTitle,
    required this.bestFitTitle,
    required this.stretchTitle,
    required this.mattersMost,
    required this.minimumAction,
    required this.bestFitAction,
    required this.stretchAction,
    required this.question,
  });

  final String minimumTitle;
  final String bestFitTitle;
  final String stretchTitle;
  final String mattersMost;
  final String Function(String subject) minimumAction;
  final String Function(String subject) bestFitAction;
  final String Function(String subject) stretchAction;
  final String question;
}

PlannerV2Response _compatibilityPlannerResponse({
  required String prompt,
  required String message,
  required List<String> evidence,
  required AIProcessingMode processingMode,
}) {
  final String safeMessage = message.trim().isEmpty
      ? 'Choose one concrete next action.'
      : message.trim();
  return PlannerV2Response(
    whatIHeard: prompt.trim().isEmpty ? 'You want planning guidance.' : prompt,
    mattersMost: 'A clear next action.',
    verifiedEvidence: evidence.isEmpty
        ? const <String>['Compatibility response; no stored evidence used.']
        : evidence,
    options: <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: 'Small start',
        description: safeMessage,
        estimatedMinutes: 5,
        tradeoff: 'Lowest effort.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Practical step',
        description: safeMessage,
        estimatedMinutes: 20,
        tradeoff: 'Balanced effort.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: 'Deeper pass',
        description: safeMessage,
        estimatedMinutes: 40,
        tradeoff: 'Higher effort.',
      ),
    ],
    recommendedKind: PlannerOptionKind.bestFit,
    recommendationReason: 'Compatibility response supplied by the caller.',
    nextStep: safeMessage,
    adaptationReceipt: PlannerAdaptationReceipt(
      userSetEnergy: 0.5,
      userSelectedEmotion: EmotionalState.neutral,
      adjustments: const <String>[
        'Compatibility mode did not infer emotional state.',
      ],
    ),
    origin: processingMode == AIProcessingMode.external
        ? PlannerResponseOrigin.externalModel
        : PlannerResponseOrigin.deterministic,
  );
}
