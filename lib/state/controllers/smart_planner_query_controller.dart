import 'dart:math' as math;

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_read_health.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
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
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/rhythm_planning_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'smart_planner_query_controller.support.dart';
part 'smart_planner_query_controller.intent.dart';
part 'smart_planner_query_controller.person_context.dart';

const String _defaultPlanningPrompt =
    'Give me a practical planning check-in for my current energy and emotional state.';

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

  /// The UI must assess the same bounded user conversation as the controller
  /// when obtaining consent and localized supportive copy for a follow-up.
  String followUpSafetyText({
    required String input,
    required String reflection,
    required List<Map<String, String>> history,
  }) => _PlannerConversationContext.resolve(
    input: input,
    history: history,
    reflection: reflection,
    isFollowUp: true,
  ).searchText;

  EmotionalSafetyAssessment assessEmotionalSafety(String text) =>
      EmotionalSafetyPolicy.assess(text);

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
    String? supportivePauseReason,
    String? supportiveQuestion,
    String? languageCode,
  }) async {
    final String prompt = notes.trim().isEmpty
        ? _defaultPlanningPrompt
        : notes.trim();
    _requireNonCrisisRoute(prompt);
    final EmotionalSafetyAssessment emotionalSafety = assessEmotionalSafety(
      prompt,
    );
    await _requireReleaseCapabilities();
    var authorized = _authorizedCheckIn(energy: energy, emotion: emotion);
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
        supportivePauseReason: supportivePauseReason,
        supportiveQuestion: supportiveQuestion,
        languageCode: languageCode,
      );
    }
    final _PlannerEvidence evidence = await _loadPlannerEvidence(
      searchText: conversation.evidenceSearchText,
    );
    authorized = _authorizedCheckIn(energy: energy, emotion: emotion);
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
      languageCode: languageCode,
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
    String? supportivePauseReason,
    String? supportiveQuestion,
  }) async {
    return (await requestFollowUpResult(
      input: input,
      energy: energy,
      emotion: emotion,
      reflection: reflection,
      history: history,
      supportivePauseReason: supportivePauseReason,
      supportiveQuestion: supportiveQuestion,
    )).message;
  }

  Future<SmartPlannerResult> requestFollowUpResult({
    required String input,
    required double? energy,
    required EmotionalState? emotion,
    required String reflection,
    required List<Map<String, String>> history,
    String? supportivePauseReason,
    String? supportiveQuestion,
    String? languageCode,
    PlannerConversationSnapshot? currentPlan,
  }) async {
    final String prompt = input.trim();
    _requireNonCrisisRoute(prompt);
    await _requireReleaseCapabilities();
    final _PlannerConversationContext conversation =
        _PlannerConversationContext.resolve(
          input: prompt,
          history: history,
          reflection: currentPlan?.originalObjective ?? reflection,
          currentUserContext:
              currentPlan?.userContext ?? currentPlan?.currentPlan.userContext,
          respondingToPlanQuestion:
              currentPlan?.adjustments.lastOrNull?.kind ==
                  PlannerAdjustmentKind.rejectedApproach ||
              currentPlan?.currentPlan.isClarification == true ||
              (currentPlan?.currentPlan.usefulQuestion?.trim().isNotEmpty ??
                  false),
          isFollowUp: true,
        );
    _requireNonCrisisRoute(conversation.searchText);
    final EmotionalSafetyAssessment emotionalSafety = assessEmotionalSafety(
      conversation.searchText,
    );
    var authorized = _authorizedCheckIn(energy: energy, emotion: emotion);
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
        supportivePauseReason: supportivePauseReason,
        supportiveQuestion: supportiveQuestion,
        languageCode: languageCode,
      );
    }
    final _PlannerEvidence evidence = await _loadPlannerEvidence(
      searchText: conversation.evidenceSearchText,
      savedContextDeclined: conversation.savedContextDeclined,
    );
    authorized = _authorizedCheckIn(energy: energy, emotion: emotion);
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
      languageCode: languageCode,
      currentPlan: currentPlan,
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
    String? supportivePauseReason,
    String? supportiveQuestion,
    String? languageCode,
  }) {
    _requireNonCrisisRoute(input);
    var authorized = _authorizedCheckIn(energy: energy, emotion: emotion);
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
      supportivePauseReason: supportivePauseReason,
      supportiveQuestion: supportiveQuestion,
      languageCode: languageCode,
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
            recommendationReason: base.languageCode == 'es'
                ? 'La petición habitual de Planner V2 no se completó.'
                : 'The normal Planner V2 request did not complete.',
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
    String? supportivePauseReason,
    String? supportiveQuestion,
    String? languageCode,
    PlannerConversationSnapshot? currentPlan,
  }) {
    var authorized = _authorizedCheckIn(energy: energy, emotion: emotion);
    return _buildPlannerResponse(
      input: input,
      energy: authorized.energy,
      emotion: authorized.emotion,
      contextWasProvided: contextWasProvided,
      conversation: _PlannerConversationContext.resolve(
        input: input,
        history: history,
        reflection: currentPlan?.originalObjective ?? reflection,
        currentUserContext:
            currentPlan?.userContext ?? currentPlan?.currentPlan.userContext,
        respondingToPlanQuestion:
            currentPlan?.adjustments.lastOrNull?.kind ==
                PlannerAdjustmentKind.rejectedApproach ||
            currentPlan?.currentPlan.isClarification == true ||
            (currentPlan?.currentPlan.usefulQuestion?.trim().isNotEmpty ??
                false),
        isFollowUp: isFollowUp,
      ),
      evidence: const _PlannerEvidence.empty(),
      currentPlan: currentPlan,
      supportivePauseReason: supportivePauseReason,
      supportiveQuestion: supportiveQuestion,
      languageCode: languageCode,
    );
  }

  PlannerV2Response _buildPlannerResponse({
    required String input,
    required double? energy,
    required EmotionalState? emotion,
    required bool contextWasProvided,
    required _PlannerConversationContext conversation,
    required _PlannerEvidence evidence,
    String? supportivePauseReason,
    String? supportiveQuestion,
    String? languageCode,
    PlannerConversationSnapshot? currentPlan,
  }) {
    final double? boundedEnergy = energy?.clamp(0.0, 1.0).toDouble();
    final double planningEnergy = boundedEnergy ?? 0.5;
    final intent = _PlannerIntent.resolve(
      conversation: conversation,
      evidence: evidence,
      zeroEnergy: boundedEnergy == 0,
      languageCode: languageCode,
    );
    String copy(String english, String spanish) =>
        intent.spanish ? spanish : english;
    String minutes(int count) => intent.spanish
        ? '$count ${count == 1 ? 'minuto' : 'minutos'}'
        : _plannerMinutes(count);
    final bool recoveryOnly = intent.recovery;
    final _EffortProfile energyEffort = _effortFor(planningEnergy);
    final int? capacityLimitMinutes =
        evidence.personContext.capacityLimitMinutes;
    final int? requestTimeLimitMinutes = conversation.explicitTimeLimitMinutes;
    final List<int> limits = <int>[
      ?capacityLimitMinutes,
      ?requestTimeLimitMinutes,
      ?evidence.noteTimeLimitMinutes,
      if (intent.deadlineNeedsDeparture) 1,
      if (currentPlan != null &&
          conversation.continuesPriorSubject &&
          _explicitPlanningTimeLimit(conversation.input) == null &&
          !currentPlan.currentPlan.isClarification)
        currentPlan.currentPlan.recommendedOption.estimatedMinutes,
    ];
    final _EffortProfile effort = limits.isEmpty
        ? energyEffort
        : energyEffort.cappedAt(limits.reduce(math.min));
    final DateTime observedAt = _ref.read(smartPlannerClockProvider)().toUtc();
    final EmotionalSafetyAssessment emotionalSafety =
        EmotionalSafetyPolicy.assess(conversation.searchText);
    final bool supportivePause = emotionalSafety.requiresSupportivePause;
    final List<String> adaptations = <String>[
      if (recoveryOnly)
        copy(
          'Prioritized your recovery request or reported zero energy; saved commitments do not require a work block now.',
          'Se priorizó tu petición de recuperación o el nivel de energía cero indicado; los compromisos guardados no exigen trabajar ahora.',
        ),
      if (boundedEnergy != null)
        copy(
          _energyAdaptation(boundedEnergy, energyEffort),
          'Se adaptaron las opciones al ${(boundedEnergy * 100).round()}% de energía indicado: ${energyEffort.minimumMinutes}, ${energyEffort.bestFitMinutes} y ${energyEffort.stretchMinutes} minutos antes de aplicar límites.',
        )
      else
        copy(
          'No current energy check-in was provided; option sizes use a neutral planning fallback.',
          'No se indicó la energía actual; se utilizó una base de duración neutra.',
        ),
      if (emotion != null)
        copy(
          _emotionAdaptation(emotion),
          'Se adaptaron las opciones al estado que seleccionaste: ${_plannerEmotionText(emotion, isSpanish: true)}.',
        )
      else
        copy(
          'Emotional state was not used because consent is off or no state was selected.',
          'No se usó un estado emocional porque no hay consentimiento o no se seleccionó uno.',
        ),
      if (emotion != null)
        copy(
          'Used only your selected emotion; no emotion was inferred from your text.',
          'Solo se usó el estado seleccionado; no se dedujo ninguna emoción de tu texto.',
        ),
      evidence.domainAdaptationSummaryFor(languageCode: intent.languageCode),
      ...evidence.supplementaryEvidenceFor(languageCode: intent.languageCode),
      if (!evidence.savedContextDeclined)
        evidence.operatingReceipt.adaptationSummaryFor(
          languageCode: intent.languageCode,
        ),
      evidence.plannerMemory.adaptationSummaryFor(
        languageCode: intent.languageCode,
      ),
      evidence.personContext.adaptationSummaryFor(
        languageCode: intent.languageCode,
      ),
      if (capacityLimitMinutes != null)
        copy(
          'Applied your reported capacity limit of ${_plannerMinutes(capacityLimitMinutes)}: no option exceeds it.',
          'Se aplicó el límite de capacidad que indicaste: ${minutes(capacityLimitMinutes)}. Ninguna opción lo supera.',
        ),
      if (requestTimeLimitMinutes != null)
        copy(
          'Applied your requested time limit of ${_plannerMinutes(requestTimeLimitMinutes)}: no option exceeds it. This limit was not saved.',
          'Se aplicó el límite solicitado de ${minutes(requestTimeLimitMinutes)}. Ninguna opción lo supera y no se guardó este límite.',
        ),
      if (conversation.historyTurnsUsed > 0)
        copy(
          'Used ${conversation.historyTurnsUsed} recent conversation turn(s) to keep this response connected to your earlier request.',
          'Se usaron ${conversation.historyTurnsUsed} intervenciones anteriores para mantener el contexto de tu petición.',
        ),
      copy(
        'Kept every option reversible and left saving to an explicit Creator confirmation.',
        'Las opciones siguen siendo reversibles; guardar requiere una confirmación explícita en Creator.',
      ),
    ];

    if (supportivePause ||
        (!recoveryOnly && evidence.resolvedRhythm != null) ||
        intent.needsClarification) {
      return PlannerV2Response.clarification(
        whatIHeard: intent.acknowledgement(
          savedSubject: evidence.focusSubjectFor(
            languageCode: intent.languageCode,
          ),
        ),
        mattersMost: supportivePause
            ? _requiredSupportiveCopy(
                supportivePauseReason,
                'supportivePauseReason',
              )
            : evidence.resolvedRhythm != null
            ? copy(
                'This Daily Rhythm is ${evidence.resolvedRhythm!.status.name} for its current period; no repeat work was proposed.',
                'Este ritmo diario ya tiene un resultado registrado en el periodo actual; no se propuso repetir el trabajo.',
              )
            : evidence.personContext.planningFocus?.kind ==
                  PersonContextKind.boundary
            ? evidence.personContext.planningFocus!.mattersMostFor(
                languageCode: intent.languageCode,
              )
            : intent.spanish
            ? 'Falta un dato concreto para proponerte una acción útil.'
            : 'One concrete detail is missing before I can suggest a useful action.',
        verifiedEvidence: <String>[
          if (boundedEnergy != null)
            copy(
              'Current check-in energy set by you: ${(boundedEnergy * 100).round()}%.',
              'Energía actual indicada por ti: ${(boundedEnergy * 100).round()}%.',
            )
          else
            copy(
              'Current check-in energy was not provided.',
              'No se indicó la energía actual.',
            ),
          if (emotion != null)
            copy(
              'Current check-in emotional state selected by you: ${_emotionLabel(emotion)}.',
              'Estado emocional actual seleccionado por ti: ${_plannerEmotionText(emotion, isSpanish: true)}.',
            )
          else
            copy(
              'Current emotional state was not used.',
              'No se usó el estado emocional actual.',
            ),
          if (evidence.hasPositiveGrounding)
            ...evidence.verifiedEvidence(
              observedAt,
              languageCode: intent.languageCode,
            )
          else
            ...evidence.clarificationEvidence(
              observedAt,
              languageCode: intent.languageCode,
            ),
          conversation.evidenceSummary(
            contextWasProvided: contextWasProvided,
            languageCode: intent.languageCode,
          ),
          if (!evidence.hasPositiveGrounding)
            copy(
              'No saved task, goal, saved planning recommendation, or Creator draft was attached.',
              'No se vinculó ninguna tarea, objetivo, recomendación ni borrador de Creator guardado.',
            ),
          copy(
            'No Timeline, memory, SI-state, XP, task, goal, or habit record was changed.',
            'No se modificaron registros de cronología, memoria, estado SI, XP, tareas, objetivos ni hábitos.',
          ),
        ],
        question: supportivePause
            ? _requiredSupportiveCopy(supportiveQuestion, 'supportiveQuestion')
            : evidence.resolvedRhythm != null
            ? copy(
                'Which different commitment would you like to plan?',
                '¿Qué otro compromiso quieres planificar?',
              )
            : evidence.requiresClarification && conversation.subject.isEmpty
            ? intent.spanish
                  ? _savedContextQuestionEs
                  : _savedContextQuestion
            : intent.question,
        adaptationReceipt: PlannerAdaptationReceipt(
          userSetEnergy: boundedEnergy,
          userSelectedEmotion: emotion,
          adjustments: <String>[
            ...adaptations,
            copy(
              'Paused before proposing actions so unrelated saved evidence could not steer the response.',
              'Se pidió una aclaración para impedir que datos guardados sin relación dirigieran la respuesta.',
            ),
            if (supportivePause)
              copy(
                'Used a privacy-safe supportive-distress route. Raw distress text was not added to the receipt.',
                'Se usó la respuesta de apoyo con protección de privacidad. El texto de malestar no se añadió al registro de adaptación.',
              ),
          ],
        ),
        origin: PlannerResponseOrigin.deterministic,
        languageCode: intent.languageCode,
        userContext: conversation.userContext,
      );
    }

    if (currentPlan != null &&
        !currentPlan.currentPlan.isClarification &&
        RegExp(
          r'^(?:why(?: this(?: one| plan)?)?|por qu[eé](?: este(?: plan)?)?)[?!. ]*$',
          caseSensitive: false,
        ).hasMatch(input.trim())) {
      return currentPlan.currentPlan.copyWith(clearUsefulQuestion: true);
    }

    if (currentPlan?.adjustments.lastOrNull?.kind ==
            PlannerAdjustmentKind.rejectedApproach &&
        conversation.continuesPriorSubject &&
        (!intent.interruptible ||
            intent.options(effort).first.description ==
                currentPlan!.currentPlan.nextStep)) {
      final obstacle = input.trim();
      final bagObstacle =
          RegExp(
            r'\b(bag|mochila|bolsa|locked|bloquead[oa])\b',
            caseSensitive: false,
          ).hasMatch(obstacle) &&
          RegExp(
            r'\b(uniform|uniforme)\b',
            caseSensitive: false,
          ).hasMatch(conversation.subject);
      return PlannerV2Response.clarification(
        whatIHeard:
            '${intent.acknowledgement()} ${intent.spanish ? 'Ese método no te sirve:' : 'That method does not fit:'} "$obstacle".',
        mattersMost: intent.spanish
            ? 'Mantener el objetivo y buscar un método que respete el obstáculo que has indicado.'
            : 'Keep your objective and find a method that respects the obstacle you described.',
        question: bagObstacle
            ? intent.spanish
                  ? '¿Tienes otra bolsa disponible o puedes dejar el uniforme junto sin guardarlo todavía?'
                  : 'Is another bag available, or can you gather the uniform without packing it yet?'
            : intent.spanish
            ? '¿Qué recurso o ayuda sí tienes disponible para este paso?'
            : 'What resource or help is available for this step?',
        verifiedEvidence: [
          ...evidence.verifiedEvidence(
            observedAt,
            languageCode: intent.languageCode,
          ),
          intent.spanish
              ? 'Has rechazado el método mostrado. La propuesta anterior no se repite como una acción nueva.'
              : 'You rejected the displayed method. The previous proposal is not repeated as a new action.',
          intent.spanish
              ? 'No se modificaron registros ni se guardó un plan.'
              : 'No records were changed and no plan was saved.',
        ],
        adaptationReceipt: PlannerAdaptationReceipt(
          userSetEnergy: boundedEnergy,
          userSelectedEmotion: emotion,
          adjustments: adaptations,
        ),
        origin: PlannerResponseOrigin.deterministic,
        languageCode: intent.languageCode,
        userContext: conversation.userContext,
      );
    }

    final PlannerOptionKind recommendation = _evidenceAwareRecommendation(
      base: _recommendedKind(energy: boundedEnergy, emotion: emotion),
      energy: planningEnergy,
      evidence: evidence,
    );
    final List<PlannerOption> options = intent.options(effort);
    final PlannerOption selected = options.singleWhere(
      (PlannerOption option) => option.kind == recommendation,
    );
    return PlannerV2Response(
      whatIHeard: intent.acknowledgement(),
      mattersMost:
          evidence.personContext.planningFocus?.kind ==
              PersonContextKind.boundary
          ? evidence.personContext.planningFocus!.mattersMostFor(
              languageCode: intent.languageCode,
            )
          : intent.reason(requestTimeLimitMinutes),
      verifiedEvidence: <String>[
        if (boundedEnergy != null)
          copy(
            'Current check-in energy set by you: ${(boundedEnergy * 100).round()}%.',
            'Energía actual indicada por ti: ${(boundedEnergy * 100).round()}%.',
          )
        else
          copy(
            'Current check-in energy was not provided.',
            'No se indicó la energía actual.',
          ),
        if (emotion != null)
          copy(
            'Current check-in emotional state selected by you: ${_emotionLabel(emotion)}.',
            'Estado emocional actual seleccionado por ti: ${_plannerEmotionText(emotion, isSpanish: true)}.',
          )
        else
          copy(
            'Current emotional state was not used.',
            'No se usó el estado emocional actual.',
          ),
        ...evidence.verifiedEvidence(
          observedAt,
          languageCode: intent.languageCode,
        ),
        ...intent.appliedEvidence,
        conversation.evidenceSummary(
          contextWasProvided: contextWasProvided,
          languageCode: intent.languageCode,
        ),
        copy(
          'No Timeline, memory, SI-state, XP, task, goal, or habit record was changed.',
          'No se modificaron registros de cronología, memoria, estado SI, XP, tareas, objetivos ni hábitos.',
        ),
      ],
      options: options,
      recommendedKind: recommendation,
      recommendationReason: boundedEnergy == 0
          ? '${intent.spanish ? 'Has indicado un 0% de energía.' : 'You reported 0% energy.'} ${intent.reason(requestTimeLimitMinutes)}'
          : recommendation == PlannerOptionKind.minimum &&
                (boundedEnergy != null || emotion != null)
          ? '${intent.spanish ? 'Tu estado actual favorece un primer paso más pequeño.' : 'Your current check-in favors a smaller reversible start.'} ${intent.reason(requestTimeLimitMinutes)}'
          : intent.reason(requestTimeLimitMinutes),
      nextStep: selected.description,
      usefulQuestion:
          intent.usefulQuestion ??
          (evidence.focusRhythm != null && !recoveryOnly
              ? intent.spanish
                    ? '¿Cuántas repeticiones quedan realmente en este periodo? No se han registrado por separado.'
                    : 'How many repetitions actually remain in this period? Individual repetitions have not been recorded.'
              : null),
      adaptationReceipt: PlannerAdaptationReceipt(
        userSetEnergy: boundedEnergy,
        userSelectedEmotion: emotion,
        adjustments: adaptations,
      ),
      origin: PlannerResponseOrigin.deterministic,
      languageCode: intent.languageCode,
      userContext: conversation.userContext,
    );
  }

  Future<_PlannerEvidence> _loadPlannerEvidence({
    required String searchText,
    bool savedContextDeclined = false,
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
    List<RhythmPlanningEntry> rhythms = const [];
    bool rhythmReadSucceeded = true;
    NoteEntity? selectedNote;
    bool noteReadSucceeded = true;
    if (!savedContextDeclined) {
      try {
        rhythms = await _ref
            .read(rhythmPlanningProvider.future)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        rhythmReadSucceeded = false;
      }
      if (!_ref.mounted) throw StateError('Planner request was disposed.');
      try {
        selectedNote = await _ref
            .read(selectedPlanningNoteProvider.future)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        noteReadSucceeded = false;
      }
    }
    if (!_ref.mounted) throw StateError('Planner request was disposed.');
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
      goals = readAvailableGoals(_ref.read(domainGoalRepositoryProvider));
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
      savedContextDeclined: savedContextDeclined,
      rhythms: rhythms,
      rhythmReadSucceeded: rhythmReadSucceeded,
      selectedNote: selectedNote,
      noteReadSucceeded: noteReadSucceeded,
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
    // Urgency changes which commitment we discuss, never the user's capacity.
    // Preserve a smaller start selected for low energy or emotional load.
    return base;
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
      response.languageCode == 'es'
          ? 'Origen: Planner V2 determinista en el dispositivo.'
          : 'Origin: deterministic on-device Planner V2.',
    ];
    final AIRecommendation recommendation =
        AIRecommendation(
          message: response.toConversationText(),
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
    required String? supportivePauseReason,
    required String? supportiveQuestion,
    String? languageCode,
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
      supportivePauseReason: supportivePauseReason,
      supportiveQuestion: supportiveQuestion,
      languageCode: languageCode,
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

  static String _requiredSupportiveCopy(String? value, String field) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        field,
        'Localized supportive safety copy is required for this route.',
      );
    }
    return normalized;
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

  static _EffortProfile _effortFor(double energy) {
    if (energy < 0.42) return const _EffortProfile(3, 10, 20);
    if (energy < 0.75) return const _EffortProfile(5, 20, 40);
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
      'Recommended the smallest option because you selected scattered.',
    EmotionalState.negative =>
      'Kept the recommendation small and reversible because you selected negative.',
    EmotionalState.energized =>
      'Considered energized alongside your reported energy when choosing an option.',
    EmotionalState.engaged =>
      'Considered engaged alongside your reported energy when choosing an option.',
    EmotionalState.calm => 'Preserved a steady pace because you selected calm.',
    EmotionalState.positive =>
      'Kept momentum available without assuming extra capacity because you selected positive.',
    EmotionalState.neutral =>
      'Used a balanced default because you selected neutral.',
  };

  static String _emotionLabel(EmotionalState emotion) => emotion.name;

  static _PlannerTopic _detectTopic(String input) {
    final String value = input
        .split(RegExp(r'[.!?;\n]+|\bbut\b|\bpero\b', caseSensitive: false))
        .where((clause) => !_negatedPlannerClause(clause))
        .join(' ')
        .toLowerCase();
    bool hasAny(List<String> terms) => terms.any(
      (term) => RegExp(
        '\\b${RegExp.escape(term)}(?:ed|ing|s)?\\b',
        caseSensitive: false,
      ).hasMatch(value),
    );
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

  static String _condense(String value, {required int maxLength}) {
    final String singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) {
      return singleLine;
    }
    return '${singleLine.substring(0, maxLength - 1).trimRight()}…';
  }
}
