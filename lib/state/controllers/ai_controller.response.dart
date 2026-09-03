part of 'ai_controller.dart';

bool shouldReserveExternalModelCredits({
  required bool externalAiAllowed,
  required AgentKind? preferredAgent,
}) =>
    externalAiAllowed &&
    (preferredAgent == null || preferredAgent == AgentKind.chat);

bool shouldRetainExternalModelCredits(AgentResult result) => result.modelBacked;

PaywallPrompt? serverAiCreditPrompt(AgentResult result) {
  final int? remaining = (result.payload['remainingCredits'] as num?)?.toInt();
  if (result.payload['billingRejected'] == true) {
    return PaywallPrompt(
      title: 'AI credits exhausted',
      message:
          'External assistant credits are exhausted. ChronoSpark will continue with on-device guidance.',
      trigger: 'ai_credit_limit',
      remainingCredits: remaining ?? 0,
    );
  }
  if (remaining != null && remaining <= 5) {
    return PaywallPrompt(
      title: 'AI credits running low',
      message: 'You have $remaining external assistant credits remaining.',
      trigger: 'ai_credit_low',
      remainingCredits: remaining,
    );
  }
  return null;
}

final siEngineStateProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final siEngineService = ref.read(siEngineServiceProvider);
  return siEngineService.loadState(
    conversation: AssistantConversationScope.primarySiConsole,
  );
});

final smartPlannerEngineStateProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final siEngineService = ref.read(siEngineServiceProvider);
  return siEngineService.loadState(
    conversation: AssistantConversationScope.primarySmartPlanner,
  );
});

final aiDecisionProvider = FutureProvider<Decision?>((ref) async {
  final List<Task> tasks = await ref.watch(tasksProvider.future);
  final si = ref.watch(siStateProvider);
  final learning = ref.watch(learningProvider);

  final SICore core = SICore(si: si, learning: learning);
  final Decision? decision = core.decide(tasks);

  if (decision != null) {
    await ref
        .read(notificationActionsProvider)
        .pushMirroredDecision(decision.task.title);
  }

  return decision;
});

final aiResponseProvider =
    AsyncNotifierProvider<AIResponseController, AIRecommendation?>(
      AIResponseController.new,
    );

final smartPlannerAiResponseProvider =
    AsyncNotifierProvider<AIResponseController, AIRecommendation?>(
      () =>
          AIResponseController(AssistantConversationScope.primarySmartPlanner),
    );

class AIResponseController extends AsyncNotifier<AIRecommendation?>
    implements SIConsoleInterface<AIRecommendation> {
  AIResponseController([
    this.conversation = AssistantConversationScope.primarySiConsole,
  ]);

  static int _requestCounter = 0;
  String? _activeRequestId;
  final AssistantConversationScope conversation;

  @override
  Future<AIRecommendation?> build() async {
    return null;
  }

  Future<AIRecommendation?> executeSmartPlannerQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) {
    _requireSurface(AssistantSurface.smartPlanner);
    return execute(
      inputOverride: input,
      personalityOverride: AIPersonality.planner,
      preferredAgent: AgentKind.chat,
      history: history,
      context: context,
    );
  }

  @override
  Future<AIRecommendation?> sendMessage(String text) {
    return executeConsoleQuery(input: text);
  }

  @override
  Future<AIRecommendation?> executeConsoleQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) {
    _requireSurface(AssistantSurface.siConsole);
    return execute(
      inputOverride: input,
      personalityOverride: AIPersonality.strategist,
      preferredAgent: AgentKind.chat,
      history: history,
      context: context,
    );
  }

  void _requireSurface(AssistantSurface requiredSurface) {
    if (conversation.surface != requiredSurface) {
      throw StateError(
        'Assistant runtime ${conversation.surface.storageId} cannot execute '
        '${requiredSurface.storageId} requests.',
      );
    }
  }

  Future<AIRecommendation?> execute({
    String? inputOverride,
    AIPersonality? personalityOverride,
    AgentKind? preferredAgent,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
    AgentRequest? requestOverride,
  }) async {
    final int seq = ++_requestCounter;
    final String accountNamespace = _assistantAccountScopeId(ref);
    final String conversationNamespace = base64UrlEncode(
      utf8.encode(conversation.conversationId),
    );
    final String generatedRequestId =
        'ai-$accountNamespace-${conversation.surface.storageId}-$conversationNamespace-${DateTime.now().millisecondsSinceEpoch}-$seq';
    final String contractInput =
        (inputOverride ??
                ref.read(_inputProviderFor(conversation.surface)) ??
                '')
            .trim();
    final Object? embeddedContract = context['assistantRequestContract'];
    final AssistantRequestEnvelope typedRequest =
        embeddedContract is Map<Object?, Object?>
        ? AssistantRequestEnvelope.fromJson(
            Map<String, Object?>.from(embeddedContract),
          )
        : createAssistantRequestEnvelope(
            accountScopeId: accountNamespace,
            conversation: conversation,
            kind: conversation.surface == AssistantSurface.smartPlanner
                ? AssistantRequestKind.planningGuidance
                : AssistantRequestKind.consoleQuery,
            input: contractInput,
            history: history,
            context: Map<String, Object?>.from(context),
            requestId: generatedRequestId,
          );
    typedRequest.validate();
    if (typedRequest.conversation != conversation ||
        typedRequest.accountScopeId != accountNamespace) {
      throw const AssistantContractException(
        'Assistant request identity does not match the active runtime.',
      );
    }
    final String requestId = typedRequest.requestId;
    final Stopwatch stopwatch = Stopwatch()..start();
    _activeRequestId = requestId;

    state = const AsyncLoading<AIRecommendation?>();
    ref
        .read(_executionStatusProviderFor(conversation.surface).notifier)
        .set(
          AIExecutionStatus(
            phase: 'running',
            requestId: requestId,
            durationMs: null,
            error: null,
          ),
        );
    RuntimeDiagnostics.record('AI[$requestId] started');

    // Assigned once credits have actually been debited, so both the
    // supersede path and the failure handler below can return them.
    Future<void> Function()? refundCredits;

    try {
      final List<Task> tasks = await ref.read(tasksProvider.future);
      final siEngineService = ref.read(siEngineServiceProvider);
      final agentOrchestrator = ref.read(agentOrchestratorProvider);
      final bool hasPremiumAccess = ref
          .read(appAccessProvider)
          .hasPremiumAccess;
      final CreditService creditService = ref.read(creditServiceProvider);

      final si = ref.read(siStateProvider);
      final learning = ref.read(learningProvider);
      final intelligence = ref.read(intelligenceStateProvider);
      final AIPersonality personality =
          personalityOverride ??
          ref.read(aiPersonalityProvider) ??
          AIPersonality.planner;
      final input =
          inputOverride ?? ref.read(_inputProviderFor(conversation.surface));

      final int creditCost = _aiCreditCost(
        input: input,
        personality: personality,
      );
      final bool externalModelRequested = shouldReserveExternalModelCredits(
        externalAiAllowed:
            LaunchContainment.externalAiEnabled &&
            context['externalAiAllowed'] == true,
        preferredAgent: preferredAgent,
      );
      bool externalModelAuthorized = externalModelRequested;
      if (externalModelRequested && !intelligence.environment.isProduction) {
        final AiCreditSpendResult spend = await creditService.spend(
          premium: hasPremiumAccess,
          amount: creditCost,
        );
        ref.invalidate(aiCreditWalletProvider);
        externalModelAuthorized = spend.allowed;
        if (spend.allowed) {
          // Reserve only for a possible external-model call. A local or
          // failed result releases the reservation below.
          refundCredits = () async {
            try {
              await creditService.refund(
                premium: hasPremiumAccess,
                amount: creditCost,
              );
              ref.invalidate(aiCreditWalletProvider);
            } on Object catch (error) {
              RuntimeDiagnostics.record(
                'AI[$requestId] credit refund failed: $error',
              );
            }
          };
        } else {
          externalModelAuthorized = false;
        }

        if (!spend.allowed) {
          ref
              .read(paywallPromptProvider.notifier)
              .set(
                PaywallPrompt(
                  title: 'AI credits exhausted',
                  message:
                      'External assistant credits are exhausted. ChronoSpark will continue with on-device guidance.',
                  trigger: 'ai_credit_limit',
                  remainingCredits: spend.wallet.balance,
                ),
              );
        } else {
          ref.read(paywallPromptProvider.notifier).set(null);
        }
      } else {
        ref.read(paywallPromptProvider.notifier).set(null);
      }

      final Map<String, dynamic>? previousState = await siEngineService
          .loadState(conversation: conversation);
      final List<Map<String, String>> conversationHistory = history.isNotEmpty
          ? List<Map<String, String>>.from(history)
          : typedRequest.history
                .map(
                  (AssistantHistoryTurn turn) => <String, String>{
                    'role': turn.role.name,
                    'content': turn.content,
                  },
                )
                .toList(growable: true);
      final String previousMessage =
          previousState?['message']?.toString().trim() ?? '';
      final bool alreadyContainsPrevious = conversationHistory.any(
        (Map<String, String> item) =>
            item['role'] == 'assistant' &&
            item['content']?.trim() == previousMessage,
      );
      if (previousMessage.isNotEmpty && !alreadyContainsPrevious) {
        conversationHistory.add(<String, String>{
          'role': 'assistant',
          'content': previousMessage,
        });
      }
      final List<AssistantMemorySnapshot> recentSnapshots = ref
          .read(
            conversation.surface == AssistantSurface.smartPlanner
                ? smartPlannerMemoryProvider
                : siMemoryProvider,
          )
          .entries
          .take(20)
          .toList(growable: false);
      final SIIntent intent = classifySIIntent(input ?? '');
      final List<String> selectedMemorySummaries =
          selectRelevantMemorySummaries(
            query: input ?? '',
            intent: intent,
            recentSnapshots: recentSnapshots,
            previousState: previousState,
          );
      final SIInputContext siInputContext = SIInputContext(
        query: input ?? '',
        availableTaskIds: tasks.map((Task t) => t.id).toSet(),
        runtimeFlags: <String, dynamic>{
          'mockMode': intelligence.flags.mockMode,
          'paywallDisabled': intelligence.flags.paywallDisabled,
          'isProduction': intelligence.environment.isProduction,
          'allowMutationClaims': false,
        },
        memorySummaries: selectedMemorySummaries,
      );
      final Map<String, dynamic> conversationContext = <String, dynamic>{
        'mode': 'planner',
        'previousMessage': previousMessage,
        'intent': intent.label,
        'grounded': <String, dynamic>{
          'taskCount': tasks.length,
          'taskIds': tasks.map((Task t) => t.id).toList(growable: false),
          'memoryCount': siInputContext.memorySummaries.length,
          'memorySummaries': siInputContext.memorySummaries,
          'allowMutationClaims': false,
        },
        'runtime': <String, dynamic>{
          'appFlavor': intelligence.environment.appFlavor,
          'mockMode': intelligence.flags.mockMode,
          'mockLoginEnabled': intelligence.flags.mockLoginEnabled,
          'paywallDisabled': intelligence.flags.paywallDisabled,
        },
        ...Map<String, dynamic>.from(typedRequest.context),
        ...context,
        'requestId': requestId,
        'surfaceId': conversation.surface.storageId,
        'conversationId': conversation.conversationId,
        'accountNamespace': accountNamespace,
        'externalAiAllowed': externalModelAuthorized,
      };

      final AgentRequest request =
          (requestOverride ??
                  AgentRequest(
                    prompt: input ?? '',
                    context: conversationContext,
                    history: conversationHistory,
                    tasks: tasks,
                    si: si,
                    learning: learning,
                    personality: personality,
                  ))
              .mergeRuntimeContext(
                runtimeContext: conversationContext,
                resolvedHistory: conversationHistory,
              );

      final AgentResult agentResult = await agentOrchestrator.execute(
        prompt: input ?? '',
        context: conversationContext,
        preferredAgent: preferredAgent,
        request: request,
      );
      if (externalModelRequested && intelligence.environment.isProduction) {
        ref.invalidate(aiCreditWalletProvider);
        ref
            .read(paywallPromptProvider.notifier)
            .set(serverAiCreditPrompt(agentResult));
      }
      if (!shouldRetainExternalModelCredits(agentResult) &&
          refundCredits != null) {
        await refundCredits();
        refundCredits = null;
      }
      if (_activeRequestId != requestId) {
        // Superseded by a newer request: this one delivers nothing, so it must
        // not keep the credits it took.
        await refundCredits?.call();
        return null;
      }
      ref
          .read(_traceProviderFor(conversation.surface).notifier)
          .set(agentResult);

      final AIResponse response = _responseFromAgentResult(
        result: agentResult,
        tasks: tasks,
        personality: personality,
      );
      Task? responseTask;
      final dynamic rawResponseTask = response.metadata['task'];
      if (rawResponseTask is Map<dynamic, dynamic>) {
        responseTask = Task.fromJson(rawResponseTask.cast<String, dynamic>());
      }
      final AIRecommendation baseRecommendation = AIRecommendation(
        task: responseTask == null ? null : TaskView.fromTask(responseTask),
        message: response.message,
        reasoning: response.metadata['reasoning']?.toString(),
        emotion: response.emotion,
        confidence: response.confidence,
        processingMode: aiProcessingModeFromMetadata(response.metadata),
      );
      final double baseConfidenceSeed = (baseRecommendation.confidence ?? 0.55)
          .clamp(0.0, 1.0);
      final double calibratedBaseConfidence = agentResult.usedDefaults
          ? (baseConfidenceSeed - 0.18).clamp(0.25, 1.0)
          : baseConfidenceSeed;

      final List<String> recentHashes = recentSnapshots
          .map((AssistantMemorySnapshot s) => s.responseHash)
          .whereType<String>()
          .where((String v) => v.isNotEmpty)
          .toList(growable: false);
      final List<String> recentSummaries = recentResponseSummaries(
        recentSnapshots: recentSnapshots,
        previousState: previousState,
      );
      final String? previousTaskId = recentSnapshots.isEmpty
          ? null
          : recentSnapshots.first.taskId;
      final bool userRecentlySkipping = _recentSkipPressure(
        ref.read(learningHistoryProvider),
      );

      final List<SIResponseCandidate> candidates = <SIResponseCandidate>[
        SIResponseCandidate(
          message: baseRecommendation.message,
          reasoning: agentResult.usedDefaults
              ? '${baseRecommendation.reasoning ?? ''} | orchestrator_defaults:${agentResult.defaultedFields.join('|')}'
              : (baseRecommendation.reasoning ?? ''),
          emotion: baseRecommendation.emotion ?? 'balanced',
          confidence: calibratedBaseConfidence,
          taskId: baseRecommendation.task?.id,
        ),
        ..._alternativeCandidates(base: baseRecommendation, tasks: tasks),
      ];

      final SIResponseSelection selection = selectResponseCandidate(
        candidates: candidates,
        recentResponseHashes: recentHashes,
        recentResponseSummaries: recentSummaries,
        previousTaskId: previousTaskId,
        userRecentlySkipping: userRecentlySkipping,
        previousSnapshot: previousState ?? const <String, dynamic>{},
      );

      final int selectedIndex = selection.index
          .clamp(0, candidates.length - 1)
          .toInt();
      final SIResponseCandidate selected = candidates[selectedIndex];
      final SIValidatedDecision validatedDecision = validateSIResponseDecision(
        inputContext: siInputContext,
        intent: intent,
        candidate: selected,
      );
      Task? selectedTask;
      if (validatedDecision.taskId != null &&
          validatedDecision.taskId!.isNotEmpty) {
        for (final Task t in tasks) {
          if (t.id == validatedDecision.taskId) {
            selectedTask = t;
            break;
          }
        }
      }

      AIRecommendation recommendation = AIRecommendation(
        task: selectedTask == null ? null : TaskView.fromTask(selectedTask),
        message: validatedDecision.message,
        reasoning: validatedDecision.violations.isEmpty
            ? selected.reasoning
            : '${selected.reasoning} | grounded_fallback:${validatedDecision.violations.join(',')}',
        emotion: selected.emotion,
        confidence: selected.confidence,
        processingMode: baseRecommendation.processingMode,
      );

      final SlidingWindowRateLimiter suggestionLimiter = ref.read(
        _suggestionRateLimiterProviderFor(conversation.surface),
      );
      if (selection.repeatedTask && !suggestionLimiter.tryAcquire()) {
        recommendation = AIRecommendation(
          task: null,
          message:
              'I am holding repeated nudges for a moment. Tell me if you want an alternative action and I will switch strategies.',
          reasoning: 'task_cooldown',
          emotion: 'balanced',
          confidence: 0.64,
          processingMode: baseRecommendation.processingMode,
        );
      }

      if (!isPolicyAcceptableResponse(recommendation.message)) {
        recommendation = AIRecommendation(
          task: recommendation.task,
          message:
              'I cannot produce a grounded answer yet. Rephrase with a specific task, status, or energy question.',
          reasoning:
              '${recommendation.reasoning ?? 'policy'} | policy_fallback',
          emotion: recommendation.emotion ?? 'balanced',
          confidence: (recommendation.confidence ?? 0.6).clamp(0.0, 1.0),
          processingMode: recommendation.processingMode,
        );
      }

      bool usedFinalDedupFallback = false;
      bool finalRepeated = isSubstantiallyRepeatedResponse(
        message: recommendation.message,
        recentResponseHashes: recentHashes,
        recentResponseSummaries: recentSummaries,
      );
      if (finalRepeated) {
        recommendation = AIRecommendation(
          task: null,
          message: _leastRepeatedSafeFallback(
            intent: intent,
            tasks: tasks,
            recentResponseHashes: recentHashes,
            recentResponseSummaries: recentSummaries,
          ),
          reasoning:
              '${recommendation.reasoning ?? 'response'} | final_dedup_fallback',
          emotion: recommendation.emotion ?? 'balanced',
          confidence: recommendation.confidence,
          processingMode: recommendation.processingMode,
        );
        usedFinalDedupFallback = true;
        finalRepeated = isSubstantiallyRepeatedResponse(
          message: recommendation.message,
          recentResponseHashes: recentHashes,
          recentResponseSummaries: recentSummaries,
        );
      }

      final bool usedGroundingFallback =
          validatedDecision.violations.isNotEmpty;
      final bool emittedPolicyAccepted = isPolicyAcceptableResponse(
        recommendation.message,
      );
      final bool emittedGrounded =
          validatedDecision.grounded || usedGroundingFallback;
      final bool facadeValidated = siEngineService.validateOutput(
        conversation: conversation,
        message: recommendation.message,
        confidence: (recommendation.confidence ?? 0.0),
        coherent: selection.coherent || usedGroundingFallback,
        deduped: !finalRepeated || usedFinalDedupFallback,
        policyAccepted: emittedPolicyAccepted,
        grounded: emittedGrounded,
      );
      if (!facadeValidated) {
        recommendation = AIRecommendation(
          task: recommendation.task,
          message:
              'I could not validate that output against current state. Ask again with clearer task, plan, or status context.',
          reasoning:
              '${recommendation.reasoning ?? 'validation'} | facade_validation_fallback',
          emotion: recommendation.emotion ?? 'balanced',
          confidence: (recommendation.confidence ?? 0.5).clamp(0.0, 1.0),
          processingMode: recommendation.processingMode,
        );
      }

      final bool facadeFallback =
          recommendation.reasoning?.contains('facade_validation_fallback') ==
          true;
      final bool repeatedAfterValidation = isSubstantiallyRepeatedResponse(
        message: recommendation.message,
        recentResponseHashes: recentHashes,
        recentResponseSummaries: recentSummaries,
      );
      if (repeatedAfterValidation && !usedFinalDedupFallback) {
        recommendation = AIRecommendation(
          task: null,
          message: _leastRepeatedSafeFallback(
            intent: intent,
            tasks: tasks,
            recentResponseHashes: recentHashes,
            recentResponseSummaries: recentSummaries,
          ),
          reasoning:
              '${recommendation.reasoning ?? 'response'} | final_dedup_fallback',
          emotion: recommendation.emotion ?? 'balanced',
          confidence: recommendation.confidence,
          processingMode: recommendation.processingMode,
        );
        usedFinalDedupFallback = true;
      }

      final double finalNovelty = responseNoveltyScore(
        message: recommendation.message,
        recentResponseHashes: recentHashes,
        recentResponseSummaries: recentSummaries,
      );
      final double calibratedConfidence = calibrateSIConfidence(
        agentConfidence: calibratedBaseConfidence,
        intentConfidence: intent.confidence,
        grounded: emittedGrounded,
        coherent: selection.coherent || usedGroundingFallback,
        noveltyScore: finalNovelty,
        memoryUsed: selectedMemorySummaries.isNotEmpty,
        usedDefaults: agentResult.usedDefaults,
        usedFallback:
            usedGroundingFallback || usedFinalDedupFallback || facadeFallback,
      );
      recommendation = AIRecommendation(
        task: recommendation.task,
        message: recommendation.message,
        reasoning: recommendation.reasoning,
        emotion: recommendation.emotion,
        confidence: calibratedConfidence,
        processingMode: recommendation.processingMode,
      );
      recommendation = recommendation.withValidatedContract(
        request: typedRequest,
        evidence: createAssistantEvidenceItems(
          request: typedRequest,
          summaries: <String>[
            'Request kind: ${typedRequest.kind.name}',
            'Grounded task signals available: ${tasks.length}',
            if (selectedMemorySummaries.isNotEmpty)
              'Surface-local memory signals used: ${selectedMemorySummaries.length}',
            'Deterministic output validators completed',
          ],
          sourceId: 'assistant_runtime',
        ),
        status:
            recommendation.processingMode == AIProcessingMode.onDeviceFallback
            ? AssistantResponseStatus.fallback
            : AssistantResponseStatus.completed,
      );
      recommendation.validateContractAgainst(typedRequest);

      stopwatch.stop();

      final Map<String, dynamic> generatedResponse = await siEngineService
          .generateResponse(
            conversation: conversation,
            input: input ?? '',
            message: recommendation.message,
            emotion: recommendation.emotion ?? 'balanced',
            confidence: recommendation.confidence ?? 0.5,
            taskId: recommendation.task?.id,
            context: <String, dynamic>{
              'reasoning': recommendation.reasoning ?? '',
            },
          );
      final String responseHash =
          generatedResponse['responseHash']?.toString() ?? '';
      final String responseSummary =
          generatedResponse['responseSummary']?.toString() ?? '';
      final String actionKey = recommendation.task?.id ?? responseHash;
      final bool persistFullHistory =
          conversationContext['persistFullHistory'] == true;
      final String memoryType = _classifyMemoryType(
        intent: intent,
        recommendation: recommendation,
      );
      final Map<String, dynamic> memoryEvent = <String, dynamic>{
        'timestampUtc': DateTime.now().toUtc().toIso8601String(),
        'type': memoryType,
        'intent': intent.label,
        'summary': _summarizeInteraction(
          input: input ?? '',
          output: recommendation.message,
        ),
        'taskId': recommendation.task?.id,
        'responseHash': responseHash,
      };
      final List<Map<String, dynamic>> memoryEvents = _appendMemoryEvent(
        previousState: previousState,
        memoryEvent: memoryEvent,
      );
      final Map<String, dynamic> memoryState = siEngineService.updateMemory(
        conversation: conversation,
        currentState: previousState,
        memoryEvent: memoryEvent,
      );
      final Map<String, dynamic> communicationContract =
          buildSICommunicationContract(
            inputContext: siInputContext,
            intent: intent,
            candidateActions: candidates,
            decision: validatedDecision,
          );

      await siEngineService.saveState(<String, dynamic>{
        'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'requestId': requestId,
        'surfaceId': conversation.surface.storageId,
        'conversationId': conversation.conversationId,
        'accountNamespace': accountNamespace,
        'durationMs': stopwatch.elapsedMilliseconds,
        'personality': personality.name,
        'input': input,
        'message': recommendation.message,
        'emotion': recommendation.emotion,
        'confidence': recommendation.confidence,
        'taskId': recommendation.task?.id,
        'taskTitle': recommendation.task?.title,
        'previousMessage': previousMessage,
        'history': persistFullHistory ? conversationHistory : null,
        'historySummary': _summarizeHistory(conversationHistory),
        'memoryEvent': memoryEvent,
        'memoryEvents': memoryState['memoryEvents'] ?? memoryEvents,
        'noveltyScore': selection.noveltyScore,
        'selfConsistent': selection.selfConsistent,
        'coherent': selection.coherent,
        'responseHash': responseHash,
        'actionKey': actionKey,
        'grounded': validatedDecision.grounded,
        'validationViolations': validatedDecision.violations,
        'intent': <String, dynamic>{
          'label': intent.label,
          'confidence': intent.confidence,
        },
        'communicationContract': communicationContract,
        'requestContract': typedRequest.toJson(),
        'responseContract': recommendation.contract!.toJson(),
        'evidenceManifest': recommendation.evidenceManifest!.toJson(),
        'assistantEvidenceExchange': AssistantEvidenceExchange(
          request: typedRequest,
          response: recommendation.contract!,
          manifest: recommendation.evidenceManifest!,
        ).toJson(),
      }, conversation: conversation);
      ref.invalidate(
        conversation.surface == AssistantSurface.smartPlanner
            ? smartPlannerEngineStateProvider
            : siEngineStateProvider,
      );

      ref
          .read(
            (conversation.surface == AssistantSurface.smartPlanner
                    ? smartPlannerMemoryProvider
                    : siMemoryProvider)
                .notifier,
          )
          .capture(
            AssistantMemorySnapshot(
              timestamp: DateTime.now(),
              energy: si.energy,
              fatigue: si.fatigue,
              completed: learning.completed,
              skipped: learning.skipped,
              taskId: recommendation.task?.id,
              reasoning: recommendation.reasoning,
              responseHash: responseHash,
              responseSummary: responseSummary,
              actionKey: actionKey,
            ),
          );

      state = AsyncData<AIRecommendation?>(recommendation);
      ref
          .read(_executionStatusProviderFor(conversation.surface).notifier)
          .set(
            AIExecutionStatus(
              phase: 'completed',
              requestId: requestId,
              durationMs: stopwatch.elapsedMilliseconds,
              error: null,
            ),
          );
      RuntimeDiagnostics.record(
        'AI[$requestId] completed in ${stopwatch.elapsedMilliseconds}ms',
      );
      return recommendation;
    } on Object catch (error, stackTrace) {
      // `on Object`, not `on Exception`: a Dart Error (a bad cast in response
      // parsing, for example) previously escaped this handler, leaving `state`
      // stuck in AsyncLoading forever and the execution status stuck on
      // 'running'. Anything watching aiResponseProvider spun indefinitely.
      stopwatch.stop();
      // The request produced no response, so the credits it took go back
      // regardless of whether it was superseded.
      await refundCredits?.call();
      if (_activeRequestId != requestId) {
        return null;
      }
      state = AsyncError<AIRecommendation?>(error, stackTrace);
      ref
          .read(_executionStatusProviderFor(conversation.surface).notifier)
          .set(
            AIExecutionStatus(
              phase: 'failed',
              requestId: requestId,
              durationMs: stopwatch.elapsedMilliseconds,
              error: error.toString(),
            ),
          );
      RuntimeDiagnostics.record('AI[$requestId] failed: $error');
      return null;
    }
  }
}
