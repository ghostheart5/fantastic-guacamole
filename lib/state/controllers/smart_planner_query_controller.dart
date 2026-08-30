import 'dart:math' as math;

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smartPlannerQueryControllerProvider =
    Provider<SmartPlannerQueryController>((Ref ref) {
      return SmartPlannerQueryController(ref);
    });

final smartPlannerClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

final PersonContextAccessRequest _smartPlannerPersonContextRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.smartPlanner,
      purposes: operationalPersonContextPurposes,
    );

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
    final ({double? energy, EmotionalState? emotion}) authorized =
        _authorizedCheckIn(energy: energy, emotion: emotion);
    await _requireReleaseCapabilities();
    final _PlannerConversationContext conversation =
        _PlannerConversationContext.resolve(
          input: prompt,
          history: history,
          isFollowUp: false,
        );
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
    final ({double? energy, EmotionalState? emotion}) authorized =
        _authorizedCheckIn(energy: energy, emotion: emotion);
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
      evidence.hasStoredEvidence
          ? 'Grounded the plan in ${evidence.activeTasks.length} active task(s) and ${evidence.activeGoals.length} active goal(s) read from this account.'
          : 'No active saved task or goal was available to ground this check-in.',
      evidence.personContext.adaptationSummary,
      if (conversation.historyTurnsUsed > 0)
        'Used ${conversation.historyTurnsUsed} recent conversation turn(s) to keep this response connected to your earlier request.',
      'Kept every option reversible and left saving to an explicit Creator confirmation.',
    ];
    final DateTime observedAt = _ref.read(smartPlannerClockProvider)().toUtc();

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
    List<TaskEntity> tasks = const <TaskEntity>[];
    List<GoalEntity> goals = const <GoalEntity>[];
    bool taskReadSucceeded = true;
    bool goalReadSucceeded = true;
    PersonContextView? personContext;
    try {
      personContext = _ref.read(
        personContextForSurfaceProvider(_smartPlannerPersonContextRequest),
      );
    } on Object {
      personContext = null;
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
    return _PlannerEvidence.resolve(
      tasks: tasks,
      goals: goals,
      searchText: searchText,
      now: _ref.read(smartPlannerClockProvider)().toUtc(),
      taskReadSucceeded: taskReadSucceeded,
      goalReadSucceeded: goalReadSucceeded,
      personContext: personContext,
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

final class _PlannerConversationContext {
  const _PlannerConversationContext({
    required this.input,
    required this.searchText,
    required this.subject,
    required this.priorSubject,
    required this.historyTurnsUsed,
    required this.isFollowUp,
  });

  factory _PlannerConversationContext.resolve({
    required String input,
    required List<Map<String, String>> history,
    String? reflection,
    required bool isFollowUp,
  }) {
    final String normalizedInput = input.trim();
    final List<String> priorUserTurns = history
        .where((Map<String, String> turn) => turn['role'] == 'user')
        .map((Map<String, String> turn) => turn['content']?.trim() ?? '')
        .where((String content) => content.isNotEmpty)
        .map(
          (String content) =>
              SmartPlannerQueryController._condense(content, maxLength: 180),
        )
        .toList(growable: true);
    final String normalizedReflection = reflection?.trim() ?? '';
    if (normalizedReflection.isNotEmpty &&
        !priorUserTurns.contains(normalizedReflection) &&
        normalizedReflection != normalizedInput) {
      priorUserTurns.insert(
        0,
        SmartPlannerQueryController._condense(
          normalizedReflection,
          maxLength: 180,
        ),
      );
    }
    final List<String> boundedPrior = priorUserTurns.length > 4
        ? priorUserTurns.sublist(priorUserTurns.length - 4)
        : priorUserTurns;
    final String priorSubject = boundedPrior.isEmpty
        ? ''
        : SmartPlannerQueryController._condense(
            boundedPrior.last,
            maxLength: 72,
          );
    final String subject = isFollowUp && priorSubject.isNotEmpty
        ? priorSubject
        : normalizedInput.isEmpty
        ? 'finding one useful next move'
        : SmartPlannerQueryController._condense(normalizedInput, maxLength: 72);
    return _PlannerConversationContext(
      input: normalizedInput,
      searchText: <String>[
        ...boundedPrior,
        normalizedInput,
      ].where((String value) => value.isNotEmpty).join(' '),
      subject: subject,
      priorSubject: priorSubject,
      historyTurnsUsed: boundedPrior.length,
      isFollowUp: isFollowUp,
    );
  }

  final String input;
  final String searchText;
  final String subject;
  final String priorSubject;
  final int historyTurnsUsed;
  final bool isFollowUp;

  String whatIHeard({
    required bool contextWasProvided,
    required _PlannerEvidence evidence,
  }) {
    final String? focus = evidence.focusSubject;
    if (isFollowUp) {
      final String followUp = SmartPlannerQueryController._condense(
        input,
        maxLength: 72,
      );
      final String connectedTo =
          focus ??
          (priorSubject.isEmpty ? 'your earlier plan' : '"$priorSubject"');
      return 'You are following up on $connectedTo: $followUp.';
    }
    if (focus != null) {
      return 'You want a workable next move for $focus.';
    }
    return contextWasProvided
        ? 'You want a workable way forward on: $subject.'
        : 'You want a practical check-in that fits your current capacity.';
  }

  String evidenceSummary({required bool contextWasProvided}) {
    if (historyTurnsUsed > 0) {
      return 'Used $historyTurnsUsed prior user conversation turn(s) for this response only; Planner did not save them.';
    }
    return contextWasProvided
        ? 'Planning context was supplied for this check-in; it was not saved as a reflection or memory.'
        : 'No planning context or prior user turn was supplied.';
  }
}

final class _PlannerEvidence {
  const _PlannerEvidence.empty()
    : activeTasks = const <TaskEntity>[],
      activeGoals = const <GoalEntity>[],
      focusTask = null,
      focusGoal = null,
      taskReadSucceeded = true,
      goalReadSucceeded = true,
      focusTaskIsUrgent = false,
      personContext = const _PlannerPersonContextEvidence.unavailable();

  _PlannerEvidence({
    required List<TaskEntity> activeTasks,
    required List<GoalEntity> activeGoals,
    required this.focusTask,
    required this.focusGoal,
    required this.taskReadSucceeded,
    required this.goalReadSucceeded,
    required this.focusTaskIsUrgent,
    required this.personContext,
  }) : activeTasks = List<TaskEntity>.unmodifiable(activeTasks),
       activeGoals = List<GoalEntity>.unmodifiable(activeGoals);

  factory _PlannerEvidence.resolve({
    required List<TaskEntity> tasks,
    required List<GoalEntity> goals,
    required String searchText,
    required DateTime now,
    required bool taskReadSucceeded,
    required bool goalReadSucceeded,
    required PersonContextView? personContext,
  }) {
    final List<TaskEntity> activeTasks = tasks
        .where((TaskEntity task) => task.isActive)
        .toList(growable: true);
    final List<GoalEntity> activeGoals = goals
        .where((GoalEntity goal) => goal.isActive)
        .toList(growable: true);
    final Set<String> terms = _plannerTerms(searchText);
    activeTasks.sort(
      (TaskEntity left, TaskEntity right) =>
          _compareTasks(left, right, terms: terms, now: now),
    );
    activeGoals.sort(
      (GoalEntity left, GoalEntity right) =>
          _compareGoals(left, right, terms: terms, now: now),
    );

    final TaskEntity? matchedTask = activeTasks.isEmpty
        ? null
        : activeTasks.first;
    final GoalEntity? matchedGoal = activeGoals.isEmpty
        ? null
        : activeGoals.first;
    final int taskMatch = matchedTask == null
        ? 0
        : _taskTextMatch(matchedTask, terms);
    final int goalMatch = matchedGoal == null
        ? 0
        : _goalTextMatch(matchedGoal, terms);

    TaskEntity? focusTask;
    GoalEntity? focusGoal;
    if (goalMatch > taskMatch) {
      focusGoal = matchedGoal;
      final List<TaskEntity> linkedTasks = activeTasks
          .where((TaskEntity task) => task.goalId == focusGoal?.id)
          .toList(growable: false);
      if (linkedTasks.isNotEmpty) {
        focusTask = linkedTasks.first;
      }
    } else if (matchedTask != null) {
      focusTask = matchedTask;
      for (final GoalEntity goal in activeGoals) {
        if (goal.id == focusTask.goalId) {
          focusGoal = goal;
          break;
        }
      }
    } else {
      focusGoal = matchedGoal;
    }

    final DateTime? focusTime = focusTask == null
        ? null
        : focusTask.dueDate ?? focusTask.scheduledFor;
    return _PlannerEvidence(
      activeTasks: activeTasks,
      activeGoals: activeGoals,
      focusTask: focusTask,
      focusGoal: focusGoal,
      taskReadSucceeded: taskReadSucceeded,
      goalReadSucceeded: goalReadSucceeded,
      personContext: _PlannerPersonContextEvidence.resolve(
        personContext,
        now: now,
      ),
      focusTaskIsUrgent:
          focusTime != null &&
          !focusTime.isAfter(now.add(const Duration(days: 1))),
    );
  }

  final List<TaskEntity> activeTasks;
  final List<GoalEntity> activeGoals;
  final TaskEntity? focusTask;
  final GoalEntity? focusGoal;
  final bool taskReadSucceeded;
  final bool goalReadSucceeded;
  final bool focusTaskIsUrgent;
  final _PlannerPersonContextEvidence personContext;

  bool get hasStoredEvidence =>
      activeTasks.isNotEmpty || activeGoals.isNotEmpty;

  String? get focusSubject {
    final TaskEntity? task = focusTask;
    if (task != null) {
      return 'saved task "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"';
    }
    final GoalEntity? goal = focusGoal;
    if (goal != null) {
      return 'saved goal "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"';
    }
    return personContext.planningFocus?.subject;
  }

  String? get mattersMost {
    final TaskEntity? task = focusTask;
    if (task != null) {
      return 'Making a credible next move on saved task "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}" without exceeding your reported capacity.';
    }
    final GoalEntity? goal = focusGoal;
    if (goal != null) {
      return 'Turning saved goal "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}" into observable progress.';
    }
    return personContext.planningFocus?.mattersMost;
  }

  Map<String, Object?> get requestContext => <String, Object?>{
    'storedEvidenceUsed': hasStoredEvidence,
    'activeTaskCount': activeTasks.length,
    'activeGoalCount': activeGoals.length,
    'focusedEvidenceKind': focusTask != null
        ? 'task'
        : focusGoal != null
        ? 'goal'
        : 'none',
    'taskEvidenceReadSucceeded': taskReadSucceeded,
    'goalEvidenceReadSucceeded': goalReadSucceeded,
    ...personContext.requestContext,
  };

  List<String> verifiedEvidence(DateTime observedAt) {
    final List<String> evidence = <String>[];
    if (!taskReadSucceeded || !goalReadSucceeded) {
      evidence.add(
        'Saved planning evidence was only partially available for this check-in.',
      );
    }
    if (!hasStoredEvidence) {
      evidence.add(
        taskReadSucceeded && goalReadSucceeded
            ? 'Saved planning evidence checked: no active tasks or goals were found for this account.'
            : 'No readable active task or goal was available, so guidance used check-in context only.',
      );
    } else {
      evidence.add(
        'Saved planning evidence read at ${observedAt.toIso8601String()}: ${activeTasks.length} active task(s), ${activeGoals.length} active goal(s).',
      );
      final TaskEntity? task = focusTask;
      if (task != null) {
        final DateTime? relevantDate = task.dueDate ?? task.scheduledFor;
        final String timing = relevantDate == null
            ? 'no saved due or scheduled time'
            : '${task.dueDate != null ? 'due' : 'scheduled'} ${_dateLabel(relevantDate)}';
        evidence.add(
          'Focused saved task: "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"; priority ${task.priority}/5; energy ${task.energyRequired}/5; $timing.',
        );
      }
      final GoalEntity? goal = focusGoal;
      if (goal != null) {
        evidence.add(
          'Focused saved goal: "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"; ${goal.targetDate == null ? 'no target date' : 'target ${_dateLabel(goal.targetDate!)}'}.',
        );
      }
    }
    evidence.addAll(personContext.verifiedEvidence());
    return evidence;
  }
}

const int _maxPlannerPersonContextSignals = 3;

enum _PlannerPersonContextStatus { unavailable, knownEmpty, available }

final class _PlannerPersonContextEvidence {
  const _PlannerPersonContextEvidence.unavailable()
    : status = _PlannerPersonContextStatus.unavailable,
      signals = const <_PlannerPersonContextSignal>[],
      availableSignalCount = 0;

  const _PlannerPersonContextEvidence._({
    required this.status,
    required this.signals,
    required this.availableSignalCount,
  });

  factory _PlannerPersonContextEvidence.resolve(
    PersonContextView? view, {
    required DateTime now,
  }) {
    if (view == null ||
        view.surface != PersonContextSurface.smartPlanner ||
        !view.purposes.containsAll(operationalPersonContextPurposes)) {
      return const _PlannerPersonContextEvidence.unavailable();
    }
    final List<PersonContextSignal> available =
        view.signals
            .where(
              (PersonContextSignal signal) =>
                  signal.isAvailableTo(
                    PersonContextSurface.smartPlanner,
                    now,
                  ) &&
                  operationalPersonContextPurposes.contains(signal.purpose),
            )
            .toList(growable: true)
          ..sort(_comparePersonContextSignals);
    if (available.isEmpty) {
      return const _PlannerPersonContextEvidence._(
        status: _PlannerPersonContextStatus.knownEmpty,
        signals: <_PlannerPersonContextSignal>[],
        availableSignalCount: 0,
      );
    }
    return _PlannerPersonContextEvidence._(
      status: _PlannerPersonContextStatus.available,
      signals: List<_PlannerPersonContextSignal>.unmodifiable(
        available
            .take(_maxPlannerPersonContextSignals)
            .map(_PlannerPersonContextSignal.fromSignal),
      ),
      availableSignalCount: available.length,
    );
  }

  final _PlannerPersonContextStatus status;
  final List<_PlannerPersonContextSignal> signals;
  final int availableSignalCount;

  _PlannerPersonContextSignal? get planningFocus {
    for (final _PlannerPersonContextSignal signal in signals) {
      if (signal.canGroundPlanning) return signal;
    }
    return null;
  }

  String get adaptationSummary => switch (status) {
    _PlannerPersonContextStatus.unavailable =>
      'Person context was unavailable and was not used.',
    _PlannerPersonContextStatus.knownEmpty =>
      'Person context was checked and known-empty for Smart Planner.',
    _PlannerPersonContextStatus.available =>
      'Used ${signals.length} consented fresh person-context signal(s), bounded to $_maxPlannerPersonContextSignals; treated them as user-provided evidence, not inferred identity.',
  };

  Map<String, Object?> get requestContext => <String, Object?>{
    'personContextStatus': switch (status) {
      _PlannerPersonContextStatus.unavailable => 'unavailable',
      _PlannerPersonContextStatus.knownEmpty => 'known_empty',
      _PlannerPersonContextStatus.available => 'available',
    },
    'personContextAvailableSignalCount': availableSignalCount,
    'personContextSignalsUsed': signals.length,
    'personContextEvidenceLimit': _maxPlannerPersonContextSignals,
    'personContextEvidenceKinds': signals
        .map((_PlannerPersonContextSignal signal) => signal.kind.name)
        .toList(growable: false),
  };

  List<String> verifiedEvidence() => switch (status) {
    _PlannerPersonContextStatus.unavailable => const <String>[
      'Person context was unavailable for Smart Planner and was not used.',
    ],
    _PlannerPersonContextStatus.knownEmpty => const <String>[
      'Person context checked for Smart Planner: no consented fresh signals were available.',
    ],
    _PlannerPersonContextStatus.available => <String>[
      'Person context checked for Smart Planner: $availableSignalCount consented fresh signal(s) available; ${signals.length} used with a limit of $_maxPlannerPersonContextSignals.',
      ...signals.map((_PlannerPersonContextSignal signal) => signal.evidence),
    ],
  };
}

final class _PlannerPersonContextSignal {
  const _PlannerPersonContextSignal({
    required this.kind,
    required this.value,
    required this.source,
    required this.purpose,
  });

  factory _PlannerPersonContextSignal.fromSignal(PersonContextSignal signal) {
    return _PlannerPersonContextSignal(
      kind: signal.kind,
      value: SmartPlannerQueryController._condense(
        signal.value.replaceAll('"', "'"),
        maxLength: 120,
      ),
      source: signal.source,
      purpose: signal.purpose,
    );
  }

  final PersonContextKind kind;
  final String value;
  final PersonContextSource source;
  final PersonContextPurpose purpose;

  bool get canGroundPlanning => switch (kind) {
    PersonContextKind.currentPriority ||
    PersonContextKind.presentCapacity ||
    PersonContextKind.preferredSupportStyle ||
    PersonContextKind.boundary ||
    PersonContextKind.commitment ||
    PersonContextKind.lifeArea => true,
    _ => false,
  };

  String get label => switch (kind) {
    PersonContextKind.role => 'role',
    PersonContextKind.value => 'value',
    PersonContextKind.currentPriority => 'current priority',
    PersonContextKind.lifeArea => 'life area',
    PersonContextKind.presentCapacity => 'present capacity',
    PersonContextKind.preferredSupportStyle => 'preferred support style',
    PersonContextKind.boundary => 'boundary',
    PersonContextKind.importantRelationship => 'important relationship',
    PersonContextKind.commitment => 'commitment',
    PersonContextKind.outcomeHistory => 'confirmed outcome history',
  };

  String get sourceLabel => switch (source) {
    PersonContextSource.userAuthored => 'user-authored',
    PersonContextSource.confirmedOutcome => 'confirmed outcome',
  };

  String get subject => '$sourceLabel $label "$value"';

  String get mattersMost =>
      'Respecting the $label you explicitly provided: "$value".';

  String get evidence =>
      'Verified person-context evidence: $sourceLabel $label for ${purpose.name}, "$value". This is a consented saved statement, not an inferred trait or identity.';
}

int _comparePersonContextSignals(
  PersonContextSignal left,
  PersonContextSignal right,
) {
  final int kindOrder = _personContextKindRank(
    left.kind,
  ).compareTo(_personContextKindRank(right.kind));
  if (kindOrder != 0) return kindOrder;
  final int recordedOrder = right.recordedAt.toUtc().compareTo(
    left.recordedAt.toUtc(),
  );
  return recordedOrder != 0 ? recordedOrder : left.id.compareTo(right.id);
}

int _personContextKindRank(PersonContextKind kind) => switch (kind) {
  PersonContextKind.currentPriority => 0,
  PersonContextKind.presentCapacity => 1,
  PersonContextKind.boundary => 2,
  PersonContextKind.commitment => 3,
  PersonContextKind.preferredSupportStyle => 4,
  PersonContextKind.lifeArea => 5,
  PersonContextKind.value => 6,
  PersonContextKind.role => 7,
  PersonContextKind.importantRelationship => 8,
  PersonContextKind.outcomeHistory => 9,
};

const Set<String> _plannerStopWords = <String>{
  'about',
  'after',
  'again',
  'could',
  'current',
  'give',
  'have',
  'help',
  'make',
  'need',
  'plan',
  'planner',
  'planning',
  'practical',
  'should',
  'that',
  'this',
  'today',
  'want',
  'what',
  'with',
  'would',
};

Set<String> _plannerTerms(String input) => RegExp(r'[a-z0-9]+')
    .allMatches(input.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where(
      (String term) => term.length >= 3 && !_plannerStopWords.contains(term),
    )
    .toSet();

int _taskTextMatch(TaskEntity task, Set<String> terms) {
  if (terms.isEmpty) return 0;
  final Set<String> titleTerms = _plannerTerms(task.title);
  final Set<String> descriptionTerms = _plannerTerms(task.description ?? '');
  return terms.where(titleTerms.contains).length * 4 +
      terms.where(descriptionTerms.contains).length;
}

int _goalTextMatch(GoalEntity goal, Set<String> terms) {
  if (terms.isEmpty) return 0;
  final Set<String> titleTerms = _plannerTerms(goal.title);
  final Set<String> descriptionTerms = _plannerTerms(goal.description ?? '');
  return terms.where(titleTerms.contains).length * 4 +
      terms.where(descriptionTerms.contains).length;
}

int _compareTasks(
  TaskEntity left,
  TaskEntity right, {
  required Set<String> terms,
  required DateTime now,
}) {
  final int leftScore =
      _taskTextMatch(left, terms) * 1000 + _taskPriorityScore(left, now);
  final int rightScore =
      _taskTextMatch(right, terms) * 1000 + _taskPriorityScore(right, now);
  final int scoreOrder = rightScore.compareTo(leftScore);
  return scoreOrder != 0 ? scoreOrder : left.title.compareTo(right.title);
}

int _taskPriorityScore(TaskEntity task, DateTime now) {
  int score = task.priority.clamp(1, 5) * 20;
  final DateTime? relevant = task.dueDate ?? task.scheduledFor;
  if (relevant == null) return score;
  if (!relevant.isAfter(now)) return score + 300;
  if (!relevant.isAfter(now.add(const Duration(days: 1)))) return score + 220;
  if (!relevant.isAfter(now.add(const Duration(days: 7)))) return score + 100;
  return score + 20;
}

int _compareGoals(
  GoalEntity left,
  GoalEntity right, {
  required Set<String> terms,
  required DateTime now,
}) {
  final int leftScore =
      _goalTextMatch(left, terms) * 1000 + _goalUrgencyScore(left, now);
  final int rightScore =
      _goalTextMatch(right, terms) * 1000 + _goalUrgencyScore(right, now);
  final int scoreOrder = rightScore.compareTo(leftScore);
  return scoreOrder != 0 ? scoreOrder : left.title.compareTo(right.title);
}

int _goalUrgencyScore(GoalEntity goal, DateTime now) {
  final DateTime? target = goal.targetDate;
  if (target == null) return 0;
  if (!target.isAfter(now)) return 200;
  if (!target.isAfter(now.add(const Duration(days: 7)))) return 100;
  if (!target.isAfter(now.add(const Duration(days: 30)))) return 40;
  return 10;
}

String _dateLabel(DateTime value) =>
    value.toLocal().toIso8601String().split('T').first;

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
      userSetEnergy: null,
      userSelectedEmotion: null,
      adjustments: const <String>[
        'Compatibility mode did not use energy or infer emotional state.',
      ],
    ),
    origin: processingMode == AIProcessingMode.external
        ? PlannerResponseOrigin.externalModel
        : PlannerResponseOrigin.deterministic,
  );
}
