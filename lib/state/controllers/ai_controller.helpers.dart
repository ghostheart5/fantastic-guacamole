part of 'ai_controller.dart';

int safeInputLength(String? input) => input?.length ?? 0;

int _aiCreditCost({
  required String? input,
  required AIPersonality personality,
}) {
  final String text = input?.trim() ?? '';
  final int lengthBonus = text.length > 120 ? 1 : 0;
  final int toneBonus = personality == AIPersonality.strict ? 1 : 0;
  return 1 + lengthBonus + toneBonus;
}

bool _recentSkipPressure(List<LearningHistoryEntry> history) {
  if (history.isEmpty) {
    return false;
  }
  final List<LearningHistoryEntry> recent = history
      .take(6)
      .toList(growable: false);
  final int skipped = recent
      .where((LearningHistoryEntry e) => e.type == LearningEventType.skipped)
      .length;
  return skipped >= 2;
}

List<SIResponseCandidate> _alternativeCandidates({
  required AIRecommendation base,
  required List<Task> tasks,
}) {
  final String? currentTaskId = base.task?.id;
  Task? alternativeTask;
  for (final Task task in tasks) {
    if (task.id != currentTaskId) {
      alternativeTask = task;
      break;
    }
  }
  if (alternativeTask == null) {
    return const <SIResponseCandidate>[];
  }

  return <SIResponseCandidate>[
    SIResponseCandidate(
      message:
          'Alternative move: ${alternativeTask.title}. Switching track to increase novelty while keeping progress aligned.',
      reasoning: base.reasoning ?? 'alternative_candidate',
      emotion: base.emotion ?? 'balanced',
      confidence: ((base.confidence ?? 0.55) - 0.05).clamp(0.0, 1.0),
      taskId: alternativeTask.id,
    ),
  ];
}

String _leastRepeatedSafeFallback({
  required SIIntent intent,
  required List<Task> tasks,
  required List<String> recentResponseHashes,
  required List<String> recentResponseSummaries,
}) {
  final List<String> alternatives = switch (intent.label) {
    'task_recommendation' =>
      tasks.isEmpty
          ? <String>[
              'There is no grounded task recommendation yet. Add a task before asking me to prioritize.',
              'I need at least one current task before I can offer a different next action.',
            ]
          : <String>[
              'I do not have a materially different recommendation yet. Ask me to reprioritize by energy, urgency, or effort.',
              'Your available task evidence has not changed enough for a new recommendation. Choose a different ranking constraint.',
              'Rather than repeat the same nudge, tell me whether urgency, energy, or ease should drive the next choice.',
            ],
    'energy_check' => <String>[
      'I do not have a materially new energy insight yet. Update your check-in or ask for a concrete recovery action.',
      'Your available energy evidence has not changed enough for a different conclusion. Add a fresh check-in for a new assessment.',
      'Rather than repeat the same energy guidance, tell me what changed since the last check-in.',
    ],
    _ => <String>[
      'I do not have a materially new grounded answer yet. Add a new detail or request a different strategy.',
      'The available app evidence has not changed enough for a different answer. Ask from another angle.',
      'Rather than repeat myself, I need one new constraint or piece of context to change the recommendation.',
    ],
  };

  String best = alternatives.first;
  double bestNovelty = -1;
  for (final String alternative in alternatives) {
    final double novelty = responseNoveltyScore(
      message: alternative,
      recentResponseHashes: recentResponseHashes,
      recentResponseSummaries: recentResponseSummaries,
    );
    if (novelty > bestNovelty) {
      best = alternative;
      bestNovelty = novelty;
    }
  }
  return best;
}

String _classifyMemoryType({
  required SIIntent intent,
  required AIRecommendation recommendation,
}) {
  if (recommendation.task != null) {
    return 'task_recommendation';
  }
  if (intent.label == 'energy_check') {
    return 'energy_insight';
  }
  if (intent.label == 'status') {
    return 'status_summary';
  }
  return 'conversation_summary';
}

String _summarizeInteraction({required String input, required String output}) {
  final String inputSummary = responseSummaryFor(input, maxWords: 8);
  final String outputSummary = responseSummaryFor(output, maxWords: 16);
  return 'Q:$inputSummary | A:$outputSummary';
}

List<Map<String, dynamic>> _appendMemoryEvent({
  required Map<String, dynamic>? previousState,
  required Map<String, dynamic> memoryEvent,
}) {
  final dynamic rawEvents = previousState?['memoryEvents'];
  final List<Map<String, dynamic>> existing = rawEvents is List
      ? rawEvents
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
            .toList(growable: true)
      : <Map<String, dynamic>>[];
  existing.add(memoryEvent);
  if (existing.length > 120) {
    return existing.sublist(existing.length - 120);
  }
  return existing;
}

List<Map<String, String>> _summarizeHistory(List<Map<String, String>> history) {
  final Iterable<Map<String, String>> tail = history.length > 20
      ? history.sublist(history.length - 20)
      : history;
  return tail
      .map(
        (Map<String, String> item) => <String, String>{
          'role': item['role'] ?? 'unknown',
          'content': responseSummaryFor(item['content'] ?? '', maxWords: 14),
        },
      )
      .toList(growable: false);
}

List<String> recentResponseSummariesForTesting({
  required List<SISnapshot> recentSnapshots,
  required Map<String, dynamic>? previousState,
}) {
  return recentResponseSummaries(
    recentSnapshots: recentSnapshots,
    previousState: previousState,
  );
}

List<String> selectRelevantMemorySummariesForTesting({
  required String query,
  required SIIntent intent,
  required List<SISnapshot> recentSnapshots,
  required Map<String, dynamic>? previousState,
}) {
  return selectRelevantMemorySummaries(
    query: query,
    intent: intent,
    recentSnapshots: recentSnapshots,
    previousState: previousState,
  );
}

AIResponse _responseFromAgentResult({
  required AgentResult result,
  required List<Task> tasks,
  required AIPersonality personality,
}) {
  final Map<String, dynamic>? taskMap = result.taskMap;
  Task? task;
  if (taskMap != null) {
    final Task parsed = Task.fromJson(taskMap);
    if (tasks.any((Task candidate) => candidate.id == parsed.id)) {
      task = parsed;
    }
  }

  return AIResponse(
    message: result.message,
    emotion: result.emotion,
    confidence: result.confidence,
    personality: _profileFor(personality, mood: result.emotion),
    action: task == null ? 'respond_conversationally' : 'recommend_task',
    safe: true,
    taskTitle: task?.title,
    metadata: <String, dynamic>{
      'reasoning': result.reasoning,
      if (task != null) 'task': task.toJson(),
    },
  );
}

final siOutputBundleProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final String input = ref.watch(aiInputProvider) ?? '';
  final AIPersonality personality = ref.watch(aiPersonalityProvider);
  final si = ref.watch(siStateProvider);
  final learning = ref.watch(learningProvider);
  final AIRecommendation? recommendation = ref
      .watch(aiResponseProvider)
      .asData
      ?.value;
  final AIResponse? response = recommendation == null
      ? null
      : AIResponse(
          message: recommendation.message,
          emotion: recommendation.emotion ?? 'balanced',
          confidence: recommendation.confidence ?? 0.5,
          personality: _profileFor(
            personality,
            mood: recommendation.emotion ?? 'balanced',
          ),
          action: recommendation.task == null
              ? 'respond_conversationally'
              : 'recommend_task',
          safe: true,
          taskTitle: recommendation.task?.title,
          metadata: <String, dynamic>{
            'reasoning': recommendation.reasoning ?? '',
          },
        );
  final List<Task> tasks = await ref.watch(tasksProvider.future);
  final Task? selectedTask =
      recommendation?.task?.toTask() ?? (tasks.isEmpty ? null : tasks.first);
  final Map<String, dynamic>? previousState = await ref.watch(
    siEngineStateProvider.future,
  );
  final String previousMessage =
      previousState?['message']?.toString().trim() ?? '';
  final modular_si.SIPipelineResult coreResult = ref
      .read(modularSiCoreProvider)
      .run(
        input: modular_si.SIInputPacket(
          text: input,
          history: previousMessage.isEmpty
              ? const <String>[]
              : <String>[previousMessage],
          context: const <String, dynamic>{'appState': 'coach'},
          latent: modular_si.SILatentInputs(
            frustration: si.fatigue,
            confusion: input.trim().isEmpty ? 0.5 : 0,
            confidence: response?.confidence ?? 0.5,
            hesitation: si.fatigue,
          ),
        ),
        mood: response?.emotion ?? 'neutral',
        task: selectedTask,
        energy: si.energy,
        fatigue: si.fatigue,
        completed: learning.completed,
        skipped: learning.skipped,
      );
  final AIResponse effectiveResponse =
      response ??
      AIResponse(
        message: coreResult.response.message,
        emotion: coreResult.response.emotion,
        confidence: coreResult.response.confidence,
        personality: _profileFor(
          personality,
          mood: coreResult.response.emotion,
        ),
        action: coreResult.decision.action,
        safe: coreResult.decision.safe,
        taskTitle: coreResult.response.task?.title,
        metadata: <String, dynamic>{'reasoning': coreResult.decision.reasoning},
      );
  final Map<String, dynamic> coreContext = <String, dynamic>{
    'intent': coreResult.intent.primary.label,
    'action': coreResult.decision.action,
    'reasoning': coreResult.cognition.summary,
    'askClarification': coreResult.cognition.meta.askClarification,
    'memoryCount': coreResult.memoryUpdate.store.snapshots.length,
  };

  final synthetic = SyntheticIntelligenceEngine();
  final bundle = await synthetic.build(
    input: input,
    now: DateTime.now(),
    personality: personality,
    response: effectiveResponse,
    appState: 'coach',
    platform: 'flutter',
    history: previousMessage.isEmpty
        ? const <String>[]
        : <String>[previousMessage],
    context: coreContext,
  );

  return <String, dynamic>{
    ...effectiveResponse.toJson(),
    'response': <String, dynamic>{
      'message': bundle.response.message,
      'emotion': bundle.response.emotion,
      'confidence': bundle.response.confidence,
      'task_title': bundle.response.task?.title,
    },
    'decision': <String, dynamic>{
      'action': bundle.decision.action,
      'safe': bundle.decision.safe,
      'reasoning': bundle.decision.reasoning,
    },
    'core_pipeline': coreContext,
  };
});

final modularSiCoreProvider = Provider<modular_si.SICore>(
  (_) => modular_si.SICore(),
);

AIPersonalityProfile _profileFor(
  AIPersonality personality, {
  String mood = 'balanced',
}) {
  switch (personality) {
    case AIPersonality.strict:
      return const AIPersonalityProfile(
        persona: SIPersona.analyst,
        traits: PersonalityTraits(
          warmth: 0.35,
          directness: 0.9,
          humor: 0.05,
          curiosity: 0.55,
          empathy: 0.42,
        ),
        style: AIStyleDirective(
          tone: 'precise_practical',
          maxWords: 52,
          useSteps: true,
          allowHumor: false,
          pressureLevel: 0.3,
        ),
        identity: 'discipline strategist',
      );
    case AIPersonality.strategist:
      return AIPersonalityProfile(
        persona: SIPersona.coach,
        traits: const PersonalityTraits(
          warmth: 0.62,
          directness: 0.78,
          humor: 0.18,
          curiosity: 0.72,
          empathy: 0.68,
        ),
        style: AIStyleDirective(
          tone: mood == 'stressed' ? 'calm_supportive' : 'focused_motivating',
          maxWords: 60,
          useSteps: true,
          allowHumor: false,
          pressureLevel: 0.25,
        ),
        identity: 'systems strategist',
      );
    case AIPersonality.coach:
      return AIPersonalityProfile(
        persona: SIPersona.mentor,
        traits: const PersonalityTraits(
          warmth: 0.84,
          directness: 0.58,
          humor: 0.22,
          curiosity: 0.61,
          empathy: 0.88,
        ),
        style: AIStyleDirective(
          tone: mood == 'stressed' ? 'calm_supportive' : 'warm_grounded',
          maxWords: 64,
          useSteps: mood == 'confused',
          allowHumor: true,
          pressureLevel: 0.12,
        ),
        identity: 'steady guide',
      );
  }
}
