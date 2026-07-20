part of 'ai_controller.dart';

final siEngineStateProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final siEngineService = ref.read(siEngineServiceProvider);
  return siEngineService.loadState();
});

final aiDecisionProvider = FutureProvider<Decision?>((ref) async {
  final List<Task> tasks = await ref.watch(tasksProvider.future);
  final si = ref.watch(siStateProvider);
  final learning = ref.watch(learningProvider);

  final SICore core = SICore(si: si, learning: learning);
  final Decision? decision = core.decide(tasks);

  if (decision != null) {
    ref
        .read(notificationActionsProvider)
        .pushMirroredDecision(decision.task.title);
  }

  return decision;
});

final aiResponseProvider =
    AsyncNotifierProvider<AIResponseController, AIRecommendation?>(
      AIResponseController.new,
    );

class AIResponseController extends AsyncNotifier<AIRecommendation?>
    implements SIConsoleInterface {
  static int _requestCounter = 0;
  String? _activeRequestId;

  @override
  Future<AIRecommendation?> build() async {
    return null;
  }

  Future<AIRecommendation?> executeCoachQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) {
    return execute(
      inputOverride: input,
      personalityOverride: AIPersonality.coach,
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
    return execute(
      inputOverride: input,
      personalityOverride: AIPersonality.strategist,
      preferredAgent: AgentKind.chat,
      history: history,
      context: context,
    );
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
    final String requestId = 'ai-${DateTime.now().millisecondsSinceEpoch}-$seq';
    final Stopwatch stopwatch = Stopwatch()..start();
    _activeRequestId = requestId;

    state = const AsyncLoading<AIRecommendation?>();
    ref
        .read(aiExecutionStatusProvider.notifier)
        .set(
          AIExecutionStatus(
            phase: 'running',
            requestId: requestId,
            durationMs: null,
            error: null,
          ),
        );
    RuntimeDiagnostics.record('AI[$requestId] started');

    try {
      final List<Task> tasks = await ref.read(tasksProvider.future);
      final siEngineService = ref.read(siEngineServiceProvider);
      final agentOrchestrator = ref.read(agentOrchestratorProvider);

      final si = ref.read(siStateProvider);
      final learning = ref.read(learningProvider);
      final intelligence = ref.read(intelligenceStateProvider);
      final AIPersonality personality =
          personalityOverride ??
          ref.read(aiPersonalityProvider) ??
          AIPersonality.coach;
      final input = inputOverride ?? ref.read(aiInputProvider);
        final int inputLength = safeInputLength(input);
      final int cost = _aiCreditCost(input: input, personality: personality);

      final spend = await consumeCredits(
        ref,
        amount: cost,
        reason: 'ai_query',
        metadata: <String, dynamic>{
          'personality': personality.name,
          'input_length': inputLength,
        },
      );
      ref.invalidate(walletProvider);

      if (!spend.allowed) {
        ref
            .read(paywallPromptProvider.notifier)
            .set(
              PaywallPrompt(
                title: 'AI credits exhausted',
                message:
                    'You have used your available AI credits. Upgrade to continue coaching, memory, and voice flows.',
                trigger: 'ai_credit_limit',
                remainingCredits: spend.wallet.balance,
              ),
            );

        const AIRecommendation denied = AIRecommendation(
          task: null,
          message:
              'Your AI credits are exhausted for this cycle. Upgrade to keep using coaching and memory.',
          reasoning: 'AI credits exhausted',
          emotion: 'cautious',
          confidence: 0.35,
        );

        state = const AsyncData<AIRecommendation?>(denied);
        ref
            .read(aiExecutionStatusProvider.notifier)
            .set(
              AIExecutionStatus(
                phase: 'denied',
                requestId: requestId,
                durationMs: stopwatch.elapsedMilliseconds,
                error: 'credits_exhausted',
              ),
            );
        RuntimeDiagnostics.record('AI[$requestId] denied: credits exhausted');
        return denied;
      }

      ref.read(paywallPromptProvider.notifier).set(null);

      final Map<String, dynamic>? previousState = await siEngineService
          .loadState();
      final List<Map<String, String>> conversationHistory =
          List<Map<String, String>>.from(history);
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
      final List<SISnapshot> recentSnapshots = ref
          .read(siMemoryProvider)
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
        'mode': 'coach',
        'previousMessage': previousMessage,
        'requestId': requestId,
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
        ...context,
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
      if (_activeRequestId != requestId) {
        return null;
      }
      ref.read(aiAgentTraceProvider.notifier).set(agentResult);

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
      );
      final double baseConfidenceSeed = (baseRecommendation.confidence ?? 0.55)
          .clamp(0.0, 1.0);
      final double calibratedBaseConfidence = agentResult.usedDefaults
          ? (baseConfidenceSeed - 0.18).clamp(0.25, 1.0)
          : baseConfidenceSeed;

      final List<String> recentHashes = recentSnapshots
          .map((SISnapshot s) => s.responseHash)
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
      );

      final SlidingWindowRateLimiter suggestionLimiter = ref.read(
        aiSuggestionRateLimiterProvider,
      );
      if (selection.repeatedTask && !suggestionLimiter.tryAcquire()) {
        recommendation = const AIRecommendation(
          task: null,
          message:
              'I am holding repeated nudges for a moment. Tell me if you want an alternative action and I will switch strategies.',
          reasoning: 'task_cooldown',
          emotion: 'balanced',
          confidence: 0.64,
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
      );

      stopwatch.stop();

      final Map<String, dynamic> generatedResponse = await siEngineService
          .generateResponse(
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
      });
      ref.invalidate(siEngineStateProvider);

      ref
          .read(siMemoryProvider.notifier)
          .capture(
            SISnapshot(
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
          .read(aiExecutionStatusProvider.notifier)
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
    } on Exception catch (error, stackTrace) {
      stopwatch.stop();
      if (_activeRequestId != requestId) {
        return null;
      }
      state = AsyncError<AIRecommendation?>(error, stackTrace);
      ref
          .read(aiExecutionStatusProvider.notifier)
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
