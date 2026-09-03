import 'dart:math' as math;

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'smart_planner_query_controller.support.dart';

final smartPlannerQueryControllerProvider =
    Provider<SmartPlannerQueryController>((Ref ref) {
      return SmartPlannerQueryController(ref);
    });

final smartPlannerClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

final smartPlannerOperatingReceiptProvider =
    Provider<OperatingDecisionReceipt?>((Ref ref) {
      return ref.watch(operatingDecisionReceiptProvider).asData?.value;
    });

final PersonContextAccessRequest _smartPlannerPersonContextRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.smartPlanner,
      purposes: operationalPersonContextPurposes,
    );

/// Privacy-safe revision of the Person Context inputs that are legally allowed
/// to affect a Smart Planner response. Rejected context is deliberately absent,
/// so an irrelevant change does not invalidate an otherwise current response.
final smartPlannerPersonContextBehaviorRevisionForDecisionProvider =
    Provider.family<String, String>((Ref ref, String decisionText) {
      final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
      final String accountScopeId = assistantAccountScopeId(
        authenticatedNamespace: scope.v2Namespace,
        isSignedOut: scope.state == AccountStorageScopeState.signedOut,
      );
      final PersonContextView? view = ref.watch(
        personContextForSurfaceProvider(_smartPlannerPersonContextRequest),
      );
      return _PlannerPersonContextEvidence.resolve(
        view,
        now: ref.read(smartPlannerClockProvider)().toUtc(),
        accountScopeId: accountScopeId,
        decisionText: decisionText,
      ).behaviorRevision;
    });

final smartPlannerPersonContextBehaviorRevisionProvider = Provider<String>((
  Ref ref,
) {
  return ref.watch(
    smartPlannerPersonContextBehaviorRevisionForDecisionProvider(''),
  );
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
    OperatingDecisionReceipt? operatingReceipt,
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
      operatingReceipt: operatingReceipt,
    );
  }

  SmartPlannerResult.fromContracts({
    required this.request,
    required this.response,
    required this.evidenceManifest,
    required this.safetyReceipt,
    required this.savedNotes,
    required this.plannerResponse,
    this.operatingReceipt,
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
  final OperatingDecisionReceipt? operatingReceipt;

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

  EmotionalSafetyAssessment assessEmotionalSafety(String text) =>
      EmotionalSafetyPolicy.assess(text);

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    final String prompt = notes.trim().isEmpty
        ? 'Give me a practical planning check-in for my current energy and emotional state.'
        : notes.trim();
    _requireNonCrisisRoute(prompt);
    final EmotionalSafetyAssessment emotionalSafety = assessEmotionalSafety(
      prompt,
    );
    final ({double? energy, EmotionalState? emotion}) authorized =
        _authorizedCheckIn(energy: energy, emotion: emotion);
    await _requireReleaseCapabilities();
    final _PlannerConversationContext conversation =
        _PlannerConversationContext.resolve(
          input: prompt,
          history: history,
          isFollowUp: false,
        );
    if (emotionalSafety.requiresSupportivePause) {
      return _supportivePauseResult(
        kind: AssistantRequestKind.planningGuidance,
        input: prompt,
        history: history,
        energy: authorized.energy,
        emotion: authorized.emotion,
        contextWasProvided: notes.trim().isNotEmpty,
        conversation: conversation,
        assessment: emotionalSafety,
      );
    }
    final _PlannerEvidence evidence = await _loadPlannerEvidence(
      searchText: conversation.searchText,
    );
    final AssistantRequestEnvelope request = _requestContract(
      kind: AssistantRequestKind.planningGuidance,
      input: prompt,
      history: history,
      energy: authorized.energy,
      emotion: authorized.emotion,
      context: <String, Object?>{
        ...evidence.requestContext,
        'conversationTurnsUsed': conversation.historyTurnsUsed,
      },
    );
    final PlannerV2Response response = _buildPlannerResponse(
      input: prompt,
      energy: authorized.energy,
      emotion: authorized.emotion,
      contextWasProvided: notes.trim().isNotEmpty,
      conversation: conversation,
      evidence: evidence,
    );
    return _resultFromResponse(
      request: request,
      response: response,
      sourceId: 'planner_v2_deterministic',
      operatingReceipt: evidence.operatingReceipt.focus,
    );
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double? energy,
    required EmotionalState? emotion,
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
    required double? energy,
    required EmotionalState? emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    final String prompt = input.trim();
    _requireNonCrisisRoute(prompt);
    await _requireReleaseCapabilities();
    final _PlannerConversationContext conversation =
        _PlannerConversationContext.resolve(
          input: prompt,
          history: history,
          reflection: reflection,
          isFollowUp: true,
        );
    _requireNonCrisisRoute(conversation.searchText);
    final EmotionalSafetyAssessment emotionalSafety = assessEmotionalSafety(
      conversation.searchText,
    );
    final ({double? energy, EmotionalState? emotion}) authorized =
        _authorizedCheckIn(energy: energy, emotion: emotion);
    if (emotionalSafety.requiresSupportivePause) {
      return _supportivePauseResult(
        kind: AssistantRequestKind.followUp,
        input: prompt,
        history: history,
        energy: authorized.energy,
        emotion: authorized.emotion,
        contextWasProvided: true,
        conversation: conversation,
        assessment: emotionalSafety,
      );
    }
    final _PlannerEvidence evidence = await _loadPlannerEvidence(
      searchText: conversation.searchText,
    );
    final AssistantRequestEnvelope request = _requestContract(
      kind: AssistantRequestKind.followUp,
      input: prompt,
      history: history,
      energy: authorized.energy,
      emotion: authorized.emotion,
      context: <String, Object?>{
        ...evidence.requestContext,
        'conversationTurnsUsed': conversation.historyTurnsUsed,
      },
    );
    final PlannerV2Response response = _buildPlannerResponse(
      input: prompt,
      energy: authorized.energy,
      emotion: authorized.emotion,
      contextWasProvided: true,
      conversation: conversation,
      evidence: evidence,
    );
    return _resultFromResponse(
      request: request,
      response: response,
      sourceId: 'planner_v2_follow_up_deterministic',
      operatingReceipt: evidence.operatingReceipt.focus,
    );
  }

  SmartPlannerResult localFallbackResult({
    required String input,
    required String message,
    required double? energy,
    required EmotionalState? emotion,
    required List<Map<String, String>> history,
    required String reason,
    AssistantRequestKind kind = AssistantRequestKind.planningGuidance,
  }) {
    _requireNonCrisisRoute(input);
    final ({double? energy, EmotionalState? emotion}) authorized =
        _authorizedCheckIn(energy: energy, emotion: emotion);
    final AssistantRequestEnvelope request = _requestContract(
      kind: kind,
      input: input,
      history: history,
      energy: authorized.energy,
      emotion: authorized.emotion,
      context: <String, Object?>{'fallbackReason': reason},
    );
    final PlannerV2Response base = buildPlannerResponse(
      input: input,
      energy: energy,
      emotion: emotion,
      contextWasProvided: input.trim().isNotEmpty,
      history: history,
      isFollowUp: kind == AssistantRequestKind.followUp,
    );
    final PlannerV2Response response = base.isClarification
        ? base.copyWith(
            mattersMost: message,
            verifiedEvidence: <String>[
              ...base.verifiedEvidence,
              'Fallback reason: $reason',
            ],
          )
        : base.copyWith(
            mattersMost: message,
            recommendationReason:
                'The normal Planner V2 request did not complete.',
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
    required double? energy,
    required EmotionalState? emotion,
    required bool contextWasProvided,
    List<Map<String, String>> history = const <Map<String, String>>[],
    String? reflection,
    bool isFollowUp = false,
  }) {
    final ({double? energy, EmotionalState? emotion}) authorized =
        _authorizedCheckIn(energy: energy, emotion: emotion);
    return _buildPlannerResponse(
      input: input,
      energy: authorized.energy,
      emotion: authorized.emotion,
      contextWasProvided: contextWasProvided,
      conversation: _PlannerConversationContext.resolve(
        input: input,
        history: history,
        reflection: reflection,
        isFollowUp: isFollowUp,
      ),
      evidence: const _PlannerEvidence.empty(),
    );
  }

  PlannerV2Response _buildPlannerResponse({
    required String input,
    required double? energy,
    required EmotionalState? emotion,
    required bool contextWasProvided,
    required _PlannerConversationContext conversation,
    required _PlannerEvidence evidence,
  }) {
    final double? boundedEnergy = energy?.clamp(0.0, 1.0).toDouble();
    final double planningEnergy = boundedEnergy ?? 0.5;
    final _PlannerTopic topic = _detectTopic(conversation.searchText);
    final _PlannerStrategy strategy = _strategyFor(topic);
    final _EffortProfile effort = _effortFor(planningEnergy);
    final DateTime observedAt = _ref.read(smartPlannerClockProvider)().toUtc();
    final EmotionalSafetyAssessment emotionalSafety =
        EmotionalSafetyPolicy.assess(conversation.searchText);
    final bool supportivePause = emotionalSafety.requiresSupportivePause;
    final List<String> adaptations = <String>[
      if (boundedEnergy != null)
        _energyAdaptation(boundedEnergy, effort)
      else
        'No current energy check-in was provided; option sizes use a neutral planning fallback.',
      if (emotion != null)
        _emotionAdaptation(emotion)
      else
        'Emotional state was not used because consent is off or no state was selected.',
      if (emotion != null)
        'Used only your selected emotion; no emotion was inferred from your text.',
      evidence.domainAdaptationSummary,
      evidence.operatingReceipt.adaptationSummary,
      evidence.plannerMemory.adaptationSummary,
      evidence.personContext.adaptationSummary,
      if (conversation.historyTurnsUsed > 0)
        'Used ${conversation.historyTurnsUsed} recent conversation turn(s) to keep this response connected to your earlier request.',
      'Kept every option reversible and left saving to an explicit Creator confirmation.',
    ];

    if (supportivePause || evidence.requiresClarification) {
      return PlannerV2Response.clarification(
        whatIHeard: conversation.clarificationSummary(
          contextWasProvided: contextWasProvided,
        ),
        mattersMost: supportivePause
            ? EmotionalSafetyPolicy.planningPauseReason(emotionalSafety)
            : 'Connecting your request to the right evidence before proposing a plan.',
        verifiedEvidence: <String>[
          if (boundedEnergy != null)
            'Current check-in energy set by you: ${(boundedEnergy * 100).round()}%.'
          else
            'Current check-in energy was not provided.',
          if (emotion != null)
            'Current check-in emotional state selected by you: ${_emotionLabel(emotion)}.'
          else
            'Current emotional state was not used.',
          ...evidence.clarificationEvidence(observedAt),
          conversation.evidenceSummary(contextWasProvided: contextWasProvided),
          'No saved task, goal, saved planning recommendation, or Creator draft was attached.',
          'No Timeline, memory, SI-state, XP, task, goal, or habit record was changed.',
        ],
        question: supportivePause
            ? EmotionalSafetyPolicy.supportiveQuestion(emotionalSafety)
            : 'Which saved task or goal, if any, should this plan support?',
        adaptationReceipt: PlannerAdaptationReceipt(
          userSetEnergy: boundedEnergy,
          userSelectedEmotion: emotion,
          adjustments: <String>[
            ...adaptations,
            'Paused before proposing actions so unrelated saved evidence could not steer the response.',
            if (supportivePause)
              'Used a privacy-safe supportive-distress route. Raw distress text was not added to the receipt.',
          ],
        ),
        origin: PlannerResponseOrigin.deterministic,
      );
    }

    final PlannerOptionKind recommendation = _evidenceAwareRecommendation(
      base: _recommendedKind(energy: boundedEnergy, emotion: emotion),
      energy: planningEnergy,
      evidence: evidence,
    );
    final String subject = evidence.focusSubject ?? conversation.subject;
    final List<PlannerOption> options = _buildEvidenceAwareOptions(
      topic: topic,
      strategy: strategy,
      effort: effort,
      subject: subject,
      evidence: evidence,
    );
    final PlannerOption selected = options.singleWhere(
      (PlannerOption option) => option.kind == recommendation,
    );
    return PlannerV2Response(
      whatIHeard: conversation.whatIHeard(
        contextWasProvided: contextWasProvided,
        evidence: evidence,
      ),
      mattersMost: evidence.mattersMost ?? strategy.mattersMost,
      verifiedEvidence: <String>[
        if (boundedEnergy != null)
          'Current check-in energy set by you: ${(boundedEnergy * 100).round()}%.'
        else
          'Current check-in energy was not provided.',
        if (emotion != null)
          'Current check-in emotional state selected by you: ${_emotionLabel(emotion)}.'
        else
          'Current emotional state was not used.',
        ...evidence.verifiedEvidence(observedAt),
        conversation.evidenceSummary(contextWasProvided: contextWasProvided),
        'No Timeline, memory, SI-state, XP, task, goal, or habit record was changed.',
      ],
      options: options,
      recommendedKind: recommendation,
      recommendationReason: _groundedRecommendationReason(
        recommendation,
        boundedEnergy,
        emotion,
        evidence,
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

  Future<_PlannerEvidence> _loadPlannerEvidence({
    required String searchText,
  }) async {
    final String accountScopeIdBefore = _accountScopeId;
    final int boundaryGenerationBefore = _ref
        .read(authSessionBoundaryProvider)
        .generation;
    List<TaskEntity> tasks = const <TaskEntity>[];
    List<GoalEntity> goals = const <GoalEntity>[];
    bool taskReadSucceeded = true;
    bool goalReadSucceeded = true;
    PersonContextView? personContext;
    OperatingDecisionReceipt? operatingReceipt;
    List<MemoryEntity> plannerMemories = const <MemoryEntity>[];
    try {
      operatingReceipt = _ref.read(smartPlannerOperatingReceiptProvider);
    } on Object {
      operatingReceipt = null;
    }
    try {
      plannerMemories = _ref.read(
        memoryRecallProvider(MemorySurface.smartPlanner),
      );
    } on Object {
      plannerMemories = const <MemoryEntity>[];
    }
    try {
      tasks = await _ref.read(domainTaskRepositoryProvider).getAllTasks();
    } on Object {
      taskReadSucceeded = false;
    }
    try {
      goals = _ref.read(domainGoalRepositoryProvider).getGoals();
    } on Object {
      goalReadSucceeded = false;
    }
    final String accountScopeIdAfter = _accountScopeId;
    final int boundaryGenerationAfter = _ref
        .read(authSessionBoundaryProvider)
        .generation;
    if (accountScopeIdAfter != accountScopeIdBefore ||
        boundaryGenerationAfter != boundaryGenerationBefore) {
      throw StateError(
        'Smart Planner account scope changed while loading evidence.',
      );
    }
    try {
      personContext = _ref.read(
        personContextForSurfaceProvider(_smartPlannerPersonContextRequest),
      );
    } on Object {
      personContext = null;
    }
    return _PlannerEvidence.resolve(
      tasks: tasks,
      goals: goals,
      searchText: searchText,
      now: _ref.read(smartPlannerClockProvider)().toUtc(),
      taskReadSucceeded: taskReadSucceeded,
      goalReadSucceeded: goalReadSucceeded,
      personContext: personContext,
      accountScopeId: accountScopeIdBefore,
      operatingReceipt: operatingReceipt,
      plannerMemories: plannerMemories,
    );
  }

  static PlannerOptionKind _evidenceAwareRecommendation({
    required PlannerOptionKind base,
    required double energy,
    required _PlannerEvidence evidence,
  }) {
    final TaskEntity? task = evidence.focusTask;
    if (task == null) return base;
    if (task.energyRequired >= 4 && energy < 0.68) {
      return PlannerOptionKind.minimum;
    }
    if (evidence.focusTaskIsUrgent && base == PlannerOptionKind.minimum) {
      return energy >= 0.45
          ? PlannerOptionKind.bestFit
          : PlannerOptionKind.minimum;
    }
    return base;
  }

  static List<PlannerOption> _buildEvidenceAwareOptions({
    required _PlannerTopic topic,
    required _PlannerStrategy strategy,
    required _EffortProfile effort,
    required String subject,
    required _PlannerEvidence evidence,
  }) {
    final TaskEntity? task = evidence.focusTask;
    if (task != null) {
      return _taskOptions(
        task: task,
        topic: topic,
        effort: effort,
        activeTaskCount: evidence.activeTasks.length,
      );
    }
    final GoalEntity? goal = evidence.focusGoal;
    if (goal != null) {
      return _goalOptions(goal: goal, effort: effort);
    }
    return <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: strategy.minimumTitle,
        description: strategy.minimumAction(subject),
        estimatedMinutes: effort.minimumMinutes,
        tradeoff: topic == _PlannerTopic.recovery
            ? 'This may delay one low-priority task, but it protects your energy right now.'
            : 'Lowest activation cost; it creates traction but limited depth.',
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
  }

  static List<PlannerOption> _taskOptions({
    required TaskEntity task,
    required _PlannerTopic topic,
    required _EffortProfile effort,
    required int activeTaskCount,
  }) {
    final String title = _safeEvidenceTitle(task.title);
    final int estimate = task.estimateOrDefault.inMinutes.clamp(5, 180);
    final int minimumMinutes = math.min(effort.minimumMinutes, estimate);
    final int bestFitMinutes = math.min(effort.bestFitMinutes, estimate);
    final int stretchMinutes = math.min(
      math.max(effort.stretchMinutes, bestFitMinutes),
      math.max(estimate, bestFitMinutes),
    );
    if (topic == _PlannerTopic.recovery) {
      return <PlannerOption>[
        PlannerOption(
          kind: PlannerOptionKind.minimum,
          title: 'Reduce the saved task',
          description:
              'Reduce "$title" to one $minimumMinutes-minute setup step, then take a five-minute quiet break.',
          estimatedMinutes: minimumMinutes,
          tradeoff:
              'Protects capacity, but the saved task will need another work block.',
        ),
        PlannerOption(
          kind: PlannerOptionKind.bestFit,
          title: 'Recover, then reassess',
          description:
              'Protect a $bestFitMinutes-minute recovery block, then decide what part of "$title" is still realistic today.',
          estimatedMinutes: bestFitMinutes,
          tradeoff:
              'Preserves energy while keeping the saved commitment visible.',
        ),
        PlannerOption(
          kind: PlannerOptionKind.stretch,
          title: 'Reset today’s workload',
          description:
              'Review the $activeTaskCount active saved task(s), defer one that can safely wait, and reserve the next $stretchMinutes minutes for recovery and "$title".',
          estimatedMinutes: stretchMinutes,
          tradeoff:
              'Creates a clearer day, but requires more planning attention now.',
        ),
      ];
    }
    return <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: 'Start the saved task',
        description:
            'Open "$title" and complete its smallest visible step for $minimumMinutes minutes. Stop when the timer ends.',
        estimatedMinutes: minimumMinutes,
        tradeoff: 'Creates verified movement without finishing the whole task.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Run one focused block',
        description:
            'Work only on "$title" for $bestFitMinutes minutes, then record the next unfinished step before stopping.',
        estimatedMinutes: bestFitMinutes,
        tradeoff:
            'Balances progress on the saved task with the capacity you reported.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: 'Push toward completion',
        description:
            'Give "$title" a $stretchMinutes-minute work cycle and finish it if the remaining work fits its saved estimate.',
        estimatedMinutes: stretchMinutes,
        tradeoff:
            'May complete more of the saved task, with a higher energy cost.',
      ),
    ];
  }

  static List<PlannerOption> _goalOptions({
    required GoalEntity goal,
    required _EffortProfile effort,
  }) {
    final String title = _safeEvidenceTitle(goal.title);
    return <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: 'Name the next proof',
        description:
            'Write one visible result that would move saved goal "$title" forward, then choose its first action.',
        estimatedMinutes: effort.minimumMinutes,
        tradeoff: 'Clarifies progress without completing a full milestone.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Advance one goal step',
        description:
            'Choose one concrete action for saved goal "$title" and work on it for ${effort.bestFitMinutes} minutes.',
        estimatedMinutes: effort.bestFitMinutes,
        tradeoff: 'Moves the saved goal while keeping today’s scope bounded.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: 'Map the milestone chain',
        description:
            'Map the next three visible milestones for saved goal "$title", then begin milestone one.',
        estimatedMinutes: effort.stretchMinutes,
        tradeoff: 'Creates more structure now, with a higher attention cost.',
      ),
    ];
  }

  static String _groundedRecommendationReason(
    PlannerOptionKind kind,
    double? energy,
    EmotionalState? emotion,
    _PlannerEvidence evidence,
  ) {
    final String base = _recommendationReason(kind, energy, emotion);
    final TaskEntity? task = evidence.focusTask;
    if (task != null) {
      return '$base It is grounded in saved task "${_safeEvidenceTitle(task.title)}" at priority ${task.priority}/5.';
    }
    final GoalEntity? goal = evidence.focusGoal;
    if (goal != null) {
      return '$base It is grounded in saved goal "${_safeEvidenceTitle(goal.title)}".';
    }
    final OperatingDecisionReceipt? receipt = evidence.operatingReceipt.focus;
    if (receipt != null) {
      return '$base It is grounded in the latest saved planning recommendation: ${_condense(receipt.rationale, maxLength: 140)}';
    }
    final _PlannerPersonContextSignal? personFocus =
        evidence.personContext.planningFocus;
    if (personFocus != null) {
      return '$base It is grounded in a consented, fresh ${personFocus.label} you provided for Smart Planner; it is not an inferred trait or identity.';
    }
    return '$base No active saved task or goal matched this check-in.';
  }

  static String _safeEvidenceTitle(String value) {
    return _condense(value.replaceAll('"', "'"), maxLength: 64);
  }

  AssistantRequestEnvelope _requestContract({
    required AssistantRequestKind kind,
    required String input,
    required List<Map<String, String>> history,
    required double? energy,
    required EmotionalState? emotion,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return createAssistantRequestEnvelope(
      accountScopeId: _accountScopeId,
      conversation: AssistantConversationScope.primarySmartPlanner,
      kind: kind,
      input: input,
      history: history,
      context: <String, Object?>{
        'energy': ?energy,
        'emotion': ?emotion?.name,
        'energyEvidence': energy == null ? 'unavailable' : 'user_reported',
        'emotionEvidence': emotion == null ? 'unavailable' : 'user_reported',
        'responseContract': 'planner_v2',
        'persistenceMode': 'ephemeral_read_only',
        ...context,
      },
    );
  }

  ({double? energy, EmotionalState? emotion}) _authorizedCheckIn({
    required double? energy,
    required EmotionalState? emotion,
  }) {
    final ConsentedHumanContext context = _ref.read(
      consentedHumanContextProvider,
    );
    return (
      energy: context.authorizeReportedEnergy(energy),
      emotion: context.authorizeReportedEmotion(emotion),
    );
  }

  SmartPlannerResult _resultFromResponse({
    required AssistantRequestEnvelope request,
    required PlannerV2Response response,
    required String sourceId,
    AssistantResponseStatus status = AssistantResponseStatus.completed,
    OperatingDecisionReceipt? operatingReceipt,
  }) {
    final List<String> evidence = <String>[
      ...response.verifiedEvidence,
      'Origin: deterministic on-device Planner V2.',
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
                : request.context['storedEvidenceUsed'] == true
                ? AssistantEvidenceKind.domainFact
                : AssistantEvidenceKind.policy,
          ),
          status: status,
        );
    recommendation.validateContractAgainst(request);
    final String safetyContext = <String>[
      ...request.history
          .where(
            (AssistantHistoryTurn turn) =>
                turn.role == AssistantHistoryRole.user,
          )
          .map((AssistantHistoryTurn turn) => turn.content),
      request.input,
    ].join(' ');
    final _PlannerTopic topic = _detectTopic(safetyContext);
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
      operatingReceipt: operatingReceipt,
    );
  }

  SmartPlannerResult _supportivePauseResult({
    required AssistantRequestKind kind,
    required String input,
    required List<Map<String, String>> history,
    required double? energy,
    required EmotionalState? emotion,
    required bool contextWasProvided,
    required _PlannerConversationContext conversation,
    required EmotionalSafetyAssessment assessment,
  }) {
    final AssistantRequestEnvelope request = _requestContract(
      kind: kind,
      input: input,
      history: history,
      energy: energy,
      emotion: emotion,
      context: <String, Object?>{
        'emotionalSafetyRoute': 'supportive_distress',
        'safetyFindingCodes': assessment.findingCodes,
        'storedEvidenceUsed': false,
      },
    );
    final PlannerV2Response response = _buildPlannerResponse(
      input: input,
      energy: energy,
      emotion: emotion,
      contextWasProvided: contextWasProvided,
      conversation: conversation,
      evidence: const _PlannerEvidence.empty(),
    );
    return _resultFromResponse(
      request: request,
      response: response,
      sourceId: 'planner_v2_supportive_pause',
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

  Future<void> _requireReleaseCapabilities() async {
    await requireAssistantReleaseCapability(
      _ref,
      AssistantReleaseCapability.smartPlannerV2,
    );
    await requireAssistantReleaseCapability(
      _ref,
      AssistantReleaseCapability.safetyCritic,
    );
  }

  static PlannerOptionKind _recommendedKind({
    required double? energy,
    required EmotionalState? emotion,
  }) {
    if ((energy != null && energy < 0.42) ||
        emotion == EmotionalState.fatigued ||
        emotion == EmotionalState.anxious ||
        emotion == EmotionalState.scattered ||
        emotion == EmotionalState.negative) {
      return PlannerOptionKind.minimum;
    }
    if (energy != null &&
        energy >= 0.82 &&
        (emotion == EmotionalState.energized ||
            emotion == EmotionalState.engaged)) {
      return PlannerOptionKind.stretch;
    }
    return PlannerOptionKind.bestFit;
  }

  static String _recommendationReason(
    PlannerOptionKind kind,
    double? energy,
    EmotionalState? emotion,
  ) {
    if (energy == null && emotion == null) {
      return 'No current capacity or emotional check-in was used, so the balanced option remains primary.';
    }
    final String energyCopy = energy == null
        ? 'No current energy was provided'
        : '${(energy * 100).round()}% energy was reported';
    final String emotionCopy = emotion == null
        ? 'no emotional state was used'
        : '${_emotionLabel(emotion)} was selected';
    return switch (kind) {
      PlannerOptionKind.minimum =>
        '$energyCopy and $emotionCopy, favoring a smaller reversible start.',
      PlannerOptionKind.bestFit =>
        '$energyCopy and $emotionCopy. The balanced option avoids assuming extra capacity.',
      PlannerOptionKind.stretch =>
        '$energyCopy and $emotionCopy, supporting a deeper option while smaller options remain available.',
    };
  }

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
      minimumTitle: 'Protect your energy',
      bestFitTitle: 'Protect one recovery block',
      stretchTitle: 'Rebuild the day around recovery',
      mattersMost: 'Protecting capacity before demanding performance.',
      minimumAction: (String _) =>
          'Choose one nonessential task to postpone. Then take a five-minute quiet break.',
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
