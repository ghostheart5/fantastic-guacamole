import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_detection_service.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_response_templates.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/personal_alignment_models.dart';
import 'package:fantastic_guacamole/state/providers/core_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/personal_alignment_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smartPlannerQueryControllerProvider =
    Provider<SmartPlannerQueryController>((ref) {
      return SmartPlannerQueryController(ref);
    });

class SmartPlannerResult {
  const SmartPlannerResult({
    required this.prompt,
    required this.message,
    required this.savedNotes,
  });

  final String prompt;
  final String message;
  final String? savedNotes;
}

class SmartPlannerQueryController implements SmartPlannerInterface {
  const SmartPlannerQueryController(this._ref);

  final Ref _ref;

  bool detectsCrisis(String text) => CrisisDetectionPolicy.detects(text);

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    final currentSi = _ref.read(siStateProvider);
    _ref
        .read(siStateProvider.notifier)
        .replaceState(
          energy: energy,
          fatigue: _fatigueFromEmotion(emotion, currentSi.fatigue),
          completedToday: currentSi.completedToday,
        );
    _ref.read(emotionProvider.notifier).set(emotion);

    String? savedNotes = previousSavedNotes;
    if (notes.isNotEmpty && notes != previousSavedNotes) {
      await _ref
          .read(workspaceStoreServiceProvider)
          .appendSiReflection(
            note: notes,
            energy: energy,
            emotion: emotion.name,
          );
      await _ref.read(memoriesActionsProvider).saveMirroredMemory(notes);
      savedNotes = notes;
    }

    final String prompt = notes.isEmpty
        ? 'Give me a practical planning guidance check-in for my current energy and '
              'emotional state. Include one clear next action.'
        : notes;
    final personalization = _ref.read(personalizationProfileProvider);
    final EmotionalState contextEmotion = personalization.useEmotionSignals
        ? emotion
        : EmotionalState.neutral;
    final _PlannerTopic detectedTopic = _detectTopic(prompt, emotion: emotion);
    final String detectedTopicLabel = _topicLabel(detectedTopic);
    final AssistantIntent assistantIntent =
        const DefaultAssistantIntentDetector().detect(
          input: prompt,
          surface: 'smart_planner',
        );
    final DefaultAssistantContextBuilder contextBuilder =
        const DefaultAssistantContextBuilder();
    final List<String> goalSummaries = _ref
        .read(goalsProvider)
        .take(3)
        .map((goal) => goal.title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final List<String> memorySummaries = personalization.useMemoryContext
        ? _ref
              .read(memoriesProvider)
              .take(3)
              .map((memory) => memory.text.trim())
              .where((text) => text.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final List<String> timelineSummaries = _ref
        .read(timelineProvider)
        .take(3)
        .map((event) => event.title.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);

    if (detectedTopic != _PlannerTopic.generalChat) {
      final String message = _buildStructuredResponse(
        topic: detectedTopic,
        energy: energy,
        input: prompt,
      );
      await _persistConversationTurn(
        role: 'user',
        channel: 'planner',
        content: prompt,
      );
      await _persistConversationTurn(
        role: 'assistant',
        channel: 'planner',
        content: message,
      );
      return SmartPlannerResult(
        prompt: prompt,
        message: message,
        savedNotes: savedNotes,
      );
    }

    final String policy = _smartPlannerPolicy();
    final String structuredPrompt =
        '$policy\n\nDetected Topic: $detectedTopicLabel\n\nUSER INPUT:\n$prompt';
    final String knowledge = _knowledgeContext();
    final Map<String, dynamic> moduleSnapshot = _plannerModuleSnapshot(
      energy: energy,
      reflection: notes,
    );
    final String aiInput = knowledge.isEmpty
        ? structuredPrompt
        : '$structuredPrompt\n\nCONTEXT SNAPSHOT:\n$knowledge';

    _ref.read(aiInputProvider.notifier).set(aiInput);
    final recommendation = personalization.externalAiAllowed
        ? await _safeSmartPlannerQuery(
            input: aiInput,
            history: history,
            context: <String, dynamic>{
              'source': 'smart_planner',
              'externalAiAllowed': true,
              'energy': energy,
              'emotion': contextEmotion.name,
              'detectedTopic': detectedTopicLabel,
              'assistantIntent': assistantIntent.toJson(),
              'assistantContext': contextBuilder.buildSmartPlannerContext(
                input: prompt,
                intent: assistantIntent,
                energy: energy,
                emotion: contextEmotion.name,
                memorySummaries: memorySummaries,
                timelineSummaries: timelineSummaries,
                goalSummaries: goalSummaries,
              ),
              'reflection': notes,
              'knowledge': knowledge,
              ...moduleSnapshot,
            },
            source: 'smart_planner',
          )
        : null;

    final String generated = recommendation?.message.trim() ?? '';
    final bool aiFallbackDetected = _isNonActionableAIFallback(
      message: generated,
      reasoning: recommendation?.reasoning,
    );
    final bool aiStructured = _isStructuredPlannerResponse(generated);
    final String message =
        generated.isNotEmpty && !aiFallbackDetected && aiStructured
        ? generated
        : _buildPlanningGuidanceMessage(energy, emotion, notes);

    await _persistConversationTurn(
      role: 'user',
      channel: 'planner',
      content: prompt,
    );
    await _persistConversationTurn(
      role: 'assistant',
      channel: 'planner',
      content: message,
    );

    return SmartPlannerResult(
      prompt: prompt,
      message: message,
      savedNotes: savedNotes,
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
    final _PlannerTopic detectedTopic = _detectTopic(input, emotion: emotion);
    final personalization = _ref.read(personalizationProfileProvider);
    final EmotionalState contextEmotion = personalization.useEmotionSignals
        ? emotion
        : EmotionalState.neutral;
    final String detectedTopicLabel = _topicLabel(detectedTopic);
    final AssistantIntent assistantIntent =
        const DefaultAssistantIntentDetector().detect(
          input: input,
          surface: 'smart_planner',
        );
    final DefaultAssistantContextBuilder contextBuilder =
        const DefaultAssistantContextBuilder();
    final List<String> goalSummaries = _ref
        .read(goalsProvider)
        .take(3)
        .map((goal) => goal.title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final List<String> memorySummaries = personalization.useMemoryContext
        ? _ref
              .read(memoriesProvider)
              .take(3)
              .map((memory) => memory.text.trim())
              .where((text) => text.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final List<String> timelineSummaries = _ref
        .read(timelineProvider)
        .take(3)
        .map((event) => event.title.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);

    if (detectedTopic != _PlannerTopic.generalChat) {
      final String fallbackReply = _buildFollowUpResponse(
        topic: detectedTopic,
        energy: energy,
        input: input,
      );
      await _persistConversationTurn(
        role: 'user',
        channel: 'follow_up',
        content: input,
      );
      await _persistConversationTurn(
        role: 'assistant',
        channel: 'follow_up',
        content: fallbackReply,
      );
      return fallbackReply;
    }

    final String policy = _smartPlannerPolicy();
    final String structuredPrompt =
        '$policy\n\nDetected Topic: $detectedTopicLabel\n\nUSER INPUT:\n$input';
    final String knowledge = _knowledgeContext();
    final Map<String, dynamic> moduleSnapshot = _plannerModuleSnapshot(
      energy: energy,
      reflection: reflection,
    );
    final String aiInput = knowledge.isEmpty
        ? structuredPrompt
        : '$structuredPrompt\n\nCONTEXT SNAPSHOT:\n$knowledge';

    _ref.read(aiInputProvider.notifier).set(aiInput);
    final recommendation = personalization.externalAiAllowed
        ? await _safeSmartPlannerQuery(
            input: aiInput,
            history: history,
            context: <String, dynamic>{
              'source': 'smart_planner_follow_up',
              'externalAiAllowed': true,
              'energy': energy,
              'emotion': contextEmotion.name,
              'detectedTopic': detectedTopicLabel,
              'assistantIntent': assistantIntent.toJson(),
              'assistantContext': contextBuilder.buildSmartPlannerContext(
                input: input,
                intent: assistantIntent,
                energy: energy,
                emotion: contextEmotion.name,
                memorySummaries: memorySummaries,
                timelineSummaries: timelineSummaries,
                goalSummaries: goalSummaries,
              ),
              'reflection': reflection,
              'knowledge': knowledge,
              ...moduleSnapshot,
            },
            source: 'smart_planner_follow_up',
          )
        : null;

    final String generated = recommendation?.message.trim() ?? '';
    final bool aiFallbackDetected = _isNonActionableAIFallback(
      message: generated,
      reasoning: recommendation?.reasoning,
    );
    final bool aiStructured = _isStructuredPlannerResponse(generated);
    final String response =
        generated.isNotEmpty && !aiFallbackDetected && aiStructured
        ? generated
        : _buildFollowUpReply(input, energy, emotion);
    await _persistConversationTurn(
      role: 'user',
      channel: 'follow_up',
      content: input,
    );
    await _persistConversationTurn(
      role: 'assistant',
      channel: 'follow_up',
      content: response,
    );
    return response;
  }

  static bool _isNonActionableAIFallback({
    required String message,
    required String? reasoning,
  }) {
    final String loweredMessage = message.toLowerCase();
    final String loweredReasoning = (reasoning ?? '').toLowerCase();
    if (loweredReasoning.contains('final_dedup_fallback')) {
      return true;
    }
    return loweredMessage.contains('available app evidence has not changed') ||
        loweredMessage.contains(
          'do not have a materially new grounded answer yet',
        );
  }

  static String _smartPlannerPolicy() {
    return 'You are Smart Planner. '
        'Identify the user\'s intent category before generating planning guidance. '
        'Never respond with generic encouragement alone. '
        'Detect topics automatically: health usecases like weight loss, weight gain, nutrition, hydration, exercise, running, strength training, energy, fatigue, sleep, and recovery; '
        'mental usecases like stress, anxiety, burnout, focus, confidence, motivation, discipline, and emotional support; '
        'productivity usecases like procrastination, deep work, time management, task planning, goal recovery, and habit building; '
        'life usecases like relationships, career, learning, personal growth, purpose, future self, and decision making; '
        'plus general chat. '
        'Respond with this structure: Goal Detected, Insight (cause analysis), Actions, Next Step, Momentum Score, Planner Question. '
        'Always provide practical actions first and follow-up questions second.';
  }

  static bool _isStructuredPlannerResponse(String message) {
    if (message.trim().isEmpty) {
      return false;
    }
    final String lower = message.toLowerCase();
    return lower.contains('goal detected') &&
        lower.contains('insight') &&
        lower.contains('actions') &&
        lower.contains('next step') &&
        lower.contains('planner question');
  }

  String _knowledgeContext() {
    final goals = _ref.read(goalsProvider);
    final memories = _ref.read(memoriesProvider);
    final CoreValuesAlignment coreValues = _ref.read(
      coreValuesAlignmentProvider,
    );
    final PersonalAlignmentAlignment personalAlignment = _ref.read(
      personalAlignmentAlignmentProvider,
    );

    final List<String> topGoals = goals
        .take(3)
        .map((goal) => goal.title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final personalization = _ref.read(personalizationProfileProvider);
    final List<String> recentMemories = personalization.useMemoryContext
        ? memories
              .take(3)
              .map((memory) => memory.text.trim())
              .where((text) => text.isNotEmpty)
              .map(
                (text) => text.length > 90 ? '${text.substring(0, 90)}...' : text,
              )
              .toList(growable: false)
        : const <String>[];

    final List<String> chunks = <String>[];
    if (topGoals.isNotEmpty) {
      chunks.add('Top goals: ${topGoals.join(' | ')}');
    }
    if (recentMemories.isNotEmpty) {
      chunks.add('Recent memories: ${recentMemories.join(' | ')}');
    }
    chunks.add(
      'Core values alignment: overall ${coreValues.overall}% | strongest ${coreValueTitle(coreValues.strongest)} | neglected ${coreValueTitle(coreValues.mostNeglected)}',
    );
    chunks.add(
      'PersonalAlignment alignment: overall ${personalAlignment.overall}% | strongest ${personalAlignmentDimensionTitle(personalAlignment.strongest)} | weakest ${personalAlignmentDimensionTitle(personalAlignment.weakest)}',
    );
    final patterns = _ref.read(observedPlanningPatternsProvider);
    chunks.add(
      'Planning preferences: style=${personalization.planningStyle.name}, priority=${personalization.priorityStrategy.name}, recovery=${personalization.recoveryPolicy.name}, recommendations=${personalization.recommendationMode.name}',
    );
    chunks.add(
      'Observed planning evidence: completed=${patterns.completed}, skipped=${patterns.skipped}, completionRate=${(patterns.completionRate * 100).round()}%',
    );
    return chunks.join('\n');
  }

  Map<String, dynamic> _plannerModuleSnapshot({
    required double energy,
    required String reflection,
  }) {
    final List<Task> tasks =
        _ref.read(tasksProvider).asData?.value ?? const <Task>[];
    final profile = _ref.read(profileProvider);
    final goals = _ref.read(goalsProvider);
    final insightsBundle = _ref.read(insightsBundleProvider);
    final logsState = _ref.read(logsProvider);
    final memories = _ref.read(memoriesProvider);
    final notifications = _ref.read(notificationProvider);
    final timelineEvents = _ref.read(timelineProvider);
    final progression = _ref.read(progressionProvider).progress;
    final soulState = _ref.read(soulStateProvider);
    final CoreValuesAlignment coreValues = _ref.read(
      coreValuesAlignmentProvider,
    );
    final PersonalAlignmentAlignment personalAlignment = _ref.read(
      personalAlignmentAlignmentProvider,
    );
    final personalization = _ref.read(personalizationProfileProvider);
    final patterns = _ref.read(observedPlanningPatternsProvider);
    final planPreview = _ref
        .read(generateAdaptivePlanUseCaseProvider)
        .call(tasks: tasks, energy: energy)
        .take(3)
        .map((block) => block.title)
        .toList(growable: false);

    return <String, dynamic>{
      'mode': 'smart_planner',
      'name': profile.name,
      'level': profile.level,
      'xp': profile.xp,
      'streak': profile.streak,
      'personalization': <String, dynamic>{
        'goalCategory': personalization.goalCategory,
        'planningStyle': personalization.planningStyle.name,
        'priorityStrategy': personalization.priorityStrategy.name,
        'recoveryPolicy': personalization.recoveryPolicy.name,
        'recommendationMode': personalization.recommendationMode.name,
        'explanationDepth': personalization.explanationDepth.name,
        'useEmotionSignals': personalization.useEmotionSignals,
        'useMemoryContext': personalization.useMemoryContext,
        'externalAiAllowed': personalization.externalAiAllowed,
        'observedCompletionRate': patterns.completionRate,
      },
      'knowledge': <String, dynamic>{
        'reflection': reflection,
        'tasks': <String, dynamic>{
          'count': tasks.length,
          'top': tasks
              .take(5)
              .map((Task task) => task.title)
              .toList(growable: false),
        },
        'goals': <String, dynamic>{
          'count': goals.length,
          'top': goals
              .take(5)
              .map((goal) => goal.title)
              .toList(growable: false),
        },
        'insights': <String, dynamic>{
          'count': insightsBundle.items.length,
          'summary': insightsBundle.summary,
          'top': insightsBundle.items
              .take(5)
              .map((item) => item.title)
              .toList(growable: false),
        },
        'logs': <String, dynamic>{
          'count': logsState.entries.length,
          'recent': logsState.entries
              .take(5)
              .map((entry) => entry.message)
              .toList(growable: false),
        },
        'timeline': <String, dynamic>{
          'count': timelineEvents.length,
          'recent': timelineEvents
              .take(5)
              .map((event) => event.title)
              .toList(growable: false),
        },
        'progression': <String, dynamic>{
          'level': progression.level,
          'xp': progression.xp,
          'xpToNext': progression.xpToNext,
          'streak': progression.streak,
          'title': progression.levelTitle,
        },
        'memories': <String, dynamic>{
          'count': memories.length,
          'recent': personalization.useMemoryContext
              ? memories
                    .take(5)
                    .map((memory) => memory.text)
                    .toList(growable: false)
              : const <String>[],
        },
        'notifications': <String, dynamic>{
          'count': notifications.length,
          'unread': notifications.where((item) => !item.isRead).length,
          'recent': notifications
              .take(5)
              .map((item) => item.title)
              .toList(growable: false),
        },
        'plan': <String, dynamic>{
          'preview': planPreview,
          'generatedFromEnergy': energy,
        },
        'profile': <String, dynamic>{
          'name': profile.name,
          'level': profile.level,
          'xp': profile.xp,
          'streak': profile.streak,
        },
        'coreValues': <String, dynamic>{
          'overall': coreValues.overall,
          'strongest': coreValueTitle(coreValues.strongest),
          'neglected': coreValueTitle(coreValues.mostNeglected),
          'scores': coreValues.scores.map(
            (CoreValueType key, CoreValueScore value) =>
                MapEntry<String, int>(coreValueTitle(key), value.score),
          ),
        },
        'personalAlignmentAlignment': <String, dynamic>{
          'overall': personalAlignment.overall,
          'strongest': personalAlignmentDimensionTitle(
            personalAlignment.strongest,
          ),
          'weakest': personalAlignmentDimensionTitle(personalAlignment.weakest),
          'scores': personalAlignment.scores.map(
            (
              PersonalAlignmentDimension key,
              PersonalAlignmentDimensionScore value,
            ) => MapEntry<String, int>(
              personalAlignmentDimensionTitle(key),
              value.score,
            ),
          ),
          'recommendations': personalAlignment.recommendations,
        },
        'personal_alignment': soulState.toJson(),
      },
    };
  }

  Future<AIRecommendation?> _safeSmartPlannerQuery({
    required String input,
    required List<Map<String, String>> history,
    required Map<String, dynamic> context,
    required String source,
  }) async {
    try {
      return await _ref
          .read(aiResponseProvider.notifier)
          .executeSmartPlannerQuery(
            input: input,
            history: history,
            context: context,
          );
    } catch (error, stackTrace) {
      Logger.error(
        'Planner query failed for $source; falling back to local response. $stackTrace',
        error,
      );
      return null;
    }
  }

  Future<void> _persistConversationTurn({
    required String role,
    required String channel,
    required String content,
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final String id =
        'planner.$channel.$role.${DateTime.now().microsecondsSinceEpoch}';
    final String label = '[$channel][$role] $trimmed';
    try {
      await _ref
          .read(savePlannerMessageUseCaseProvider)
          .call(PlannerMessage(id: id, label: label));
    } catch (_) {
      // Keep planning guidance non-blocking when history persistence fails.
    }
  }

  static double _fatigueFromEmotion(EmotionalState emotion, double current) {
    switch (emotion) {
      case EmotionalState.fatigued:
        return 0.75;
      case EmotionalState.anxious:
        return 0.65;
      case EmotionalState.scattered:
        return 0.60;
      case EmotionalState.negative:
        return 0.55;
      case EmotionalState.neutral:
        return current;
      case EmotionalState.calm:
        return 0.25;
      case EmotionalState.positive:
        return 0.30;
      case EmotionalState.focused:
        return 0.20;
      case EmotionalState.energized:
        return 0.15;
    }
  }

  static String _buildPlanningGuidanceMessage(
    double energy,
    EmotionalState emotion,
    String notes,
  ) {
    final _PlannerTopic topic = _detectTopic(notes, emotion: emotion);
    return _buildStructuredResponse(topic: topic, energy: energy, input: notes);
  }

  static String _buildFollowUpReply(
    String question,
    double energy,
    EmotionalState emotion,
  ) {
    final _PlannerTopic topic = _detectTopic(question, emotion: emotion);
    return _buildFollowUpResponse(
      topic: topic,
      energy: energy,
      input: question,
    );
  }

  static String _buildFollowUpResponse({
    required _PlannerTopic topic,
    required double energy,
    required String input,
  }) {
    final String answerSummary = _summarizeFollowUpAnswer(topic, input);
    late final String move;
    late final String question;

    switch (topic) {
      case _PlannerTopic.weightLoss:
        move = answerSummary.isEmpty
            ? 'Start with 16 oz water, then add protein to your next meal and walk 10 minutes.'
            : '$answerSummary Start with 16 oz water, then add protein to your next meal and walk 10 minutes.';
        question = 'What is your current weight and target weight?';
      case _PlannerTopic.weightGain:
        move = answerSummary.isEmpty
            ? 'Eat a calorie-dense meal with protein, then add a short resistance session.'
            : '$answerSummary Eat a calorie-dense meal with protein, then add a short resistance session.';
        question = 'What is your current weight and goal weight?';
      case _PlannerTopic.hydration:
        move = answerSummary.isEmpty
            ? 'Drink a full glass of water now and keep a bottle within reach.'
            : '$answerSummary Drink a full glass of water now and keep a bottle within reach.';
        question = 'How much water have you had so far today?';
      case _PlannerTopic.fatigue:
        move = answerSummary.isEmpty
            ? 'Reset with sunlight, water, and one balanced meal before you try to push hard again.'
            : '$answerSummary Reset with sunlight, water, and one balanced meal before you try to push hard again.';
        question =
            'How many hours did you sleep last night, and when was your last full meal?';
      case _PlannerTopic.sleep:
        move = answerSummary.isEmpty
            ? 'Lock in a bedtime, reduce screens tonight, and stop caffeine early tomorrow.'
            : '$answerSummary Lock in a bedtime, reduce screens tonight, and stop caffeine early tomorrow.';
        question = 'What time do you need to wake up tomorrow?';
      case _PlannerTopic.recovery:
        move = answerSummary.isEmpty
            ? 'Lower training load today, hydrate well, and protect your sleep window.'
            : '$answerSummary Lower training load today, hydrate well, and protect your sleep window.';
        question =
            'What needs the most recovery right now: sleep, training, or stress?';
      case _PlannerTopic.stress:
        move = answerSummary.isEmpty
            ? 'Use 2 minutes of breathing, then write the top 3 stressors and one next step each.'
            : '$answerSummary Use 2 minutes of breathing, then write the top 3 stressors and one next step each.';
        question =
            'Which stressor needs action today, and which one can wait 24 hours?';
      case _PlannerTopic.burnout:
        move = answerSummary.isEmpty
            ? 'Step back from the overload, cut one commitment, and protect a real recovery block.'
            : '$answerSummary Step back from the overload, cut one commitment, and protect a real recovery block.';
        question = 'What is draining you the fastest right now?';
      case _PlannerTopic.nutrition:
        move = answerSummary.isEmpty
            ? 'Build your next meal around protein first, then add a fiber-rich food.'
            : '$answerSummary Build your next meal around protein first, then add a fiber-rich food.';
        question =
            'Any dietary restrictions, and what foods do you already have available today?';
      case _PlannerTopic.exercise:
        move = answerSummary.isEmpty
            ? 'Warm up, then do one full-body session and finish with a short cooldown.'
            : '$answerSummary Warm up, then do one full-body session and finish with a short cooldown.';
        question =
            'Do you want a beginner, intermediate, or advanced session for today?';
      case _PlannerTopic.confidence:
        move = answerSummary.isEmpty
            ? 'Pick one situation, practice the response once, and prove it with action.'
            : '$answerSummary Pick one situation, practice the response once, and prove it with action.';
        question = 'What situation is testing your confidence most right now?';
      case _PlannerTopic.discipline:
        move = answerSummary.isEmpty
            ? 'Choose one rule you can keep today and remove one easy excuse.'
            : '$answerSummary Choose one rule you can keep today and remove one easy excuse.';
        question = 'What is the one rule you want to follow today?';
      case _PlannerTopic.focus:
        move = answerSummary.isEmpty
            ? 'Protect one deep-work block, remove two distractions, and start with the hardest task first.'
            : '$answerSummary Protect one deep-work block, remove two distractions, and start with the hardest task first.';
        question =
            'What is the one task you will focus on for the next 25 minutes?';
      case _PlannerTopic.procrastination:
        move = answerSummary.isEmpty
            ? 'Shrink the task to a 5-minute starter and begin before motivation catches up.'
            : '$answerSummary Shrink the task to a 5-minute starter and begin before motivation catches up.';
        question = 'What 5-minute starter action can you do right now?';
      case _PlannerTopic.habits:
        move = answerSummary.isEmpty
            ? 'Anchor one daily habit to an existing routine and track completion visibly.'
            : '$answerSummary Anchor one daily habit to an existing routine and track completion visibly.';
        question = 'Which single habit should become automatic this week?';
      case _PlannerTopic.productivity:
      case _PlannerTopic.timeManagement:
      case _PlannerTopic.taskPlanning:
      case _PlannerTopic.habitBuilding:
        move = answerSummary.isEmpty
            ? 'Pick one priority task, shrink it to a 10-minute start, and silence distractions.'
            : '$answerSummary Pick one priority task, shrink it to a 10-minute start, and silence distractions.';
        question = 'What single task will move your day forward the most?';
      case _PlannerTopic.mentalHealth:
        move = answerSummary.isEmpty
            ? 'Name the feeling, take a grounding break, and reach out to one trusted person.'
            : '$answerSummary Name the feeling, take a grounding break, and reach out to one trusted person.';
        question =
            'Would you like a 5-minute grounding exercise you can do immediately?';
      case _PlannerTopic.motivation:
        move = answerSummary.isEmpty
            ? 'Choose one task, shrink it to the first 10 minutes, and start the timer now.'
            : '$answerSummary Choose one task, shrink it to the first 10 minutes, and start the timer now.';
        question = 'What exact 10-minute step are you committing to right now?';
      case _PlannerTopic.relationships:
      case _PlannerTopic.career:
      case _PlannerTopic.learning:
      case _PlannerTopic.personalGrowth:
      case _PlannerTopic.decisionMaking:
      case _PlannerTopic.goals:
      case _PlannerTopic.goalRecovery:
      case _PlannerTopic.futureSelf:
      case _PlannerTopic.purpose:
        move = answerSummary.isEmpty
            ? 'Pick one outcome, define the next step, and make it visible on your calendar.'
            : '$answerSummary Pick one outcome, define the next step, and make it visible on your calendar.';
        question =
            'What outcome matters most right now, and what is the next step?';
      case _PlannerTopic.generalChat:
        move = answerSummary.isEmpty
            ? 'Pick one outcome, choose one action, and run a focused 10-minute sprint.'
            : '$answerSummary Pick one outcome, choose one action, and run a focused 10-minute sprint.';
        question = 'What result do you want to achieve today?';
    }

    return AssistantResponseTemplates.smartPlannerFollowUp(
      move: move,
      question: question,
      energy: energy,
    );
  }

  static String _summarizeFollowUpAnswer(_PlannerTopic topic, String input) {
    final String lowered = input.toLowerCase();
    final RegExp hoursPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)');
    final Match? hoursMatch = hoursPattern.firstMatch(lowered);
    final List<String> parts = <String>[];

    if (topic == _PlannerTopic.weightLoss ||
        topic == _PlannerTopic.weightGain) {
      final RegExp weightPattern = RegExp(
        r'(\d+(?:\.\d+)?)\s*(?:lb|lbs|pounds|kg)',
      );
      final Match? currentWeight = weightPattern.firstMatch(lowered);
      final Match? targetWeight = RegExp(
        r'(?:target|goal|want to be|get to|want to get to|want|aim for)\s*(?:weight)?\s*(\d+(?:\.\d+)?)\s*(?:lb|lbs|pounds|kg)?',
      ).firstMatch(lowered);
      if (currentWeight != null ||
          targetWeight != null ||
          lowered.contains('lose weight')) {
        final String current = currentWeight?.group(1) ?? 'your current weight';
        final String target = targetWeight?.group(1) ?? 'your target weight';
        return 'You said $current and want to get to $target.';
      }
    }

    if (topic == _PlannerTopic.stress) {
      if (lowered.contains('deadline') ||
          lowered.contains('work') ||
          lowered.contains('pressure')) {
        return 'You said the stress is tied to work pressure or deadlines.';
      }
      if (lowered.contains('overwhelm') || lowered.contains('too much')) {
        return 'You said it feels overwhelming and spread too thin.';
      }
    }

    if (topic == _PlannerTopic.burnout) {
      if (lowered.contains('tired') ||
          lowered.contains('drained') ||
          lowered.contains('exhausted')) {
        return 'You said you feel drained and close to burnout.';
      }
      if (lowered.contains('too much') || lowered.contains('overload')) {
        return 'You said the load feels too heavy right now.';
      }
    }

    if (topic == _PlannerTopic.nutrition) {
      if (lowered.contains('haven\'t eaten') ||
          lowered.contains('haven’t eaten') ||
          lowered.contains('no meal') ||
          lowered.contains('skipped a meal')) {
        return 'You said you haven\'t eaten yet.';
      }
      if (RegExp(r'\bate\b').hasMatch(lowered) ||
          lowered.contains('had a meal')) {
        return 'You said you already ate.';
      }
    }

    if (topic == _PlannerTopic.hydration) {
      if (lowered.contains('dehydr') ||
          lowered.contains('thirst') ||
          lowered.contains('water')) {
        return 'You said hydration has been low.';
      }
    }

    if (topic == _PlannerTopic.confidence) {
      if (lowered.contains('nervous') ||
          lowered.contains('uncertain') ||
          lowered.contains('hesitant')) {
        return 'You said confidence feels shaky in that situation.';
      }
    }

    if (topic == _PlannerTopic.discipline) {
      if (lowered.contains('skip') ||
          lowered.contains('break') ||
          lowered.contains('resist')) {
        return 'You said sticking to the rule has been hard.';
      }
    }

    if (topic == _PlannerTopic.relationships ||
        topic == _PlannerTopic.career ||
        topic == _PlannerTopic.learning ||
        topic == _PlannerTopic.personalGrowth ||
        topic == _PlannerTopic.decisionMaking) {
      return input.trim().isEmpty ? '' : 'You said: ${input.trim()}.';
    }

    if (hoursMatch != null) {
      parts.add('You got ${hoursMatch.group(1)} hours of sleep,');
    }
    if (lowered.contains('haven\'t eaten') ||
        lowered.contains('haven’t eaten') ||
        lowered.contains('no meal') ||
        lowered.contains('not eaten') ||
        lowered.contains('skipped a meal')) {
      parts.add('and you haven\'t eaten yet.');
    } else if (RegExp(r'\bate\b').hasMatch(lowered) ||
        lowered.contains('had a meal')) {
      parts.add('and you already ate.');
    }

    if (parts.isEmpty) {
      return input.trim().isEmpty ? '' : 'You said: ${input.trim()}.';
    }

    return parts.join(' ');
  }

  static _PlannerTopic _detectTopic(
    String text, {
    required EmotionalState emotion,
  }) {
    final String normalized = text.toLowerCase();
    bool hasAny(List<String> patterns) => patterns.any(normalized.contains);

    if (hasAny(<String>[
      'weight gain',
      'gain weight',
      'put on weight',
      'bulk',
      'build mass',
    ])) {
      return _PlannerTopic.weightGain;
    }
    if (hasAny(<String>[
      'weight loss',
      'lose weight',
      'fat loss',
      'body fat',
      'cutting',
      'weigh',
      'weight',
      'lbs',
      'pounds',
      'kg',
      'current weight',
      'target weight',
    ])) {
      return _PlannerTopic.weightLoss;
    }
    if (hasAny(<String>[
      'hydrate',
      'hydration',
      'dehydrated',
      'dehydration',
      'water intake',
      'electrolyte',
    ])) {
      return _PlannerTopic.hydration;
    }
    if (hasAny(<String>[
      'sleep',
      'insomnia',
      'restless',
      'wake up',
      'bedtime',
      'nap',
    ])) {
      return _PlannerTopic.sleep;
    }
    if (hasAny(<String>[
      'recovery',
      'recover',
      'rest day',
      'rest and recover',
      'soreness',
      'healing',
    ])) {
      return _PlannerTopic.recovery;
    }
    if (hasAny(<String>['burnout', 'burned out', 'burned-out'])) {
      return _PlannerTopic.burnout;
    }
    if (hasAny(<String>[
          'tired',
          'fatigue',
          'fatigued',
          'exhausted',
          'drained',
          'no energy',
        ]) ||
        emotion == EmotionalState.fatigued) {
      return _PlannerTopic.fatigue;
    }
    if (hasAny(<String>[
      'stress',
      'stressed',
      'overwhelm',
      'pressure',
      'overloaded',
      'deadline',
    ])) {
      return _PlannerTopic.stress;
    }
    if (hasAny(<String>[
      'mental health',
      'depressed',
      'depression',
      'hopeless',
      'panic',
      'lonely',
      'anxiety',
      'anxious',
      'emotional support',
    ])) {
      return _PlannerTopic.mentalHealth;
    }
    if (hasAny(<String>['confidence', 'self esteem', 'self-esteem'])) {
      return _PlannerTopic.confidence;
    }
    if (hasAny(<String>[
      'motivat',
      'procrastin',
      'cant start',
      'can\'t start',
    ])) {
      return _PlannerTopic.motivation;
    }
    if (hasAny(<String>['discipline', 'self control', 'self-control'])) {
      return _PlannerTopic.discipline;
    }
    if (hasAny(<String>['focus', 'distract', 'attention', 'concentration'])) {
      return _PlannerTopic.focus;
    }
    if (hasAny(<String>[
      'procrastin',
      'avoidance',
      'delay starting',
      'putting off',
    ])) {
      return _PlannerTopic.procrastination;
    }
    if (hasAny(<String>[
      'deep work',
      'time management',
      'task planning',
      'schedule',
      'calendar',
    ])) {
      return _PlannerTopic.timeManagement;
    }
    if (hasAny(<String>[
      'habit',
      'habit building',
      'build a habit',
      'routine',
    ])) {
      return _PlannerTopic.habits;
    }
    if (hasAny(<String>[
      'goal recovery',
      'recover my goal',
      'off track',
      'fell behind',
      'missed my goal',
      'get back on track',
    ])) {
      return _PlannerTopic.goalRecovery;
    }
    if (hasAny(<String>[
      'future self',
      'future me',
      'future version',
      'future identity',
      'long term self',
    ])) {
      return _PlannerTopic.futureSelf;
    }
    if (hasAny(<String>[
      'purpose',
      'meaning',
      'why am i doing this',
      'my why',
      'life purpose',
    ])) {
      return _PlannerTopic.purpose;
    }
    if (hasAny(<String>[
      'habit',
      'habit building',
      'build a habit',
      'routine',
    ])) {
      return _PlannerTopic.habitBuilding;
    }
    if (hasAny(<String>[
      'exercise',
      'workout',
      'training',
      'gym',
      'run',
      'lift',
      'cardio',
    ])) {
      return _PlannerTopic.exercise;
    }
    if (hasAny(<String>[
      'nutrition',
      'diet',
      'meal',
      'food',
      'protein',
      'macros',
      'calorie',
      'eaten',
      'hungry',
      'fasting',
      'not eaten',
      'haven\'t eaten',
    ])) {
      return _PlannerTopic.nutrition;
    }
    if (hasAny(<String>[
      'productivity',
      'focus',
      'distract',
      'attention',
      'concentration',
    ])) {
      return _PlannerTopic.productivity;
    }
    if (hasAny(<String>[
      'relationships',
      'relationship',
      'partner',
      'friendship',
      'family',
    ])) {
      return _PlannerTopic.relationships;
    }
    if (hasAny(<String>[
      'career',
      'job',
      'promotion',
      'work path',
      'workplace',
    ])) {
      return _PlannerTopic.career;
    }
    if (hasAny(<String>['learn', 'learning', 'study', 'education', 'skill'])) {
      return _PlannerTopic.learning;
    }
    if (hasAny(<String>[
      'growth',
      'personal growth',
      'self improvement',
      'self-improvement',
    ])) {
      return _PlannerTopic.personalGrowth;
    }
    if (hasAny(<String>[
      'decision',
      'decide',
      'choice',
      'options',
      'should i',
    ])) {
      return _PlannerTopic.decisionMaking;
    }
    if (hasAny(<String>[
      'goal',
      'target',
      'milestone',
      'objective',
      'goal achievement',
    ])) {
      return _PlannerTopic.goals;
    }
    return _PlannerTopic.generalChat;
  }

  static String _topicLabel(_PlannerTopic topic) {
    switch (topic) {
      case _PlannerTopic.weightLoss:
        return 'Weight Loss';
      case _PlannerTopic.weightGain:
        return 'Weight Gain';
      case _PlannerTopic.hydration:
        return 'Hydration';
      case _PlannerTopic.fatigue:
        return 'Fatigue';
      case _PlannerTopic.sleep:
        return 'Sleep';
      case _PlannerTopic.recovery:
        return 'Recovery';
      case _PlannerTopic.stress:
        return 'Stress';
      case _PlannerTopic.burnout:
        return 'Burnout';
      case _PlannerTopic.nutrition:
        return 'Nutrition';
      case _PlannerTopic.exercise:
        return 'Exercise';
      case _PlannerTopic.confidence:
        return 'Confidence';
      case _PlannerTopic.discipline:
        return 'Discipline';
      case _PlannerTopic.focus:
        return 'Focus';
      case _PlannerTopic.procrastination:
        return 'Procrastination';
      case _PlannerTopic.habits:
        return 'Habits';
      case _PlannerTopic.productivity:
        return 'Productivity';
      case _PlannerTopic.timeManagement:
        return 'Time Management';
      case _PlannerTopic.taskPlanning:
        return 'Task Planning';
      case _PlannerTopic.habitBuilding:
        return 'Habit Building';
      case _PlannerTopic.mentalHealth:
        return 'Mental Health';
      case _PlannerTopic.motivation:
        return 'Motivation';
      case _PlannerTopic.goals:
        return 'Goals';
      case _PlannerTopic.goalRecovery:
        return 'Goal Recovery';
      case _PlannerTopic.futureSelf:
        return 'Future Self';
      case _PlannerTopic.purpose:
        return 'Purpose';
      case _PlannerTopic.relationships:
        return 'Relationships';
      case _PlannerTopic.career:
        return 'Career';
      case _PlannerTopic.learning:
        return 'Learning';
      case _PlannerTopic.personalGrowth:
        return 'Personal Growth';
      case _PlannerTopic.decisionMaking:
        return 'Decision Making';
      case _PlannerTopic.generalChat:
        return 'General Chat';
    }
  }

  static String _buildStructuredResponse({
    required _PlannerTopic topic,
    required double energy,
    required String input,
  }) {
    final int pct = (energy * 100).round();
    late final String insight;
    late final List<String> actions;
    late final String nextStep;
    late final String followUp;

    switch (topic) {
      case _PlannerTopic.weightLoss:
        insight =
            'You’re probably getting slowed down by calorie drift and not enough daily movement.';
        actions = <String>[
          'Drink 16 oz water now.',
          'Add a palm-sized protein serving to your next meal.',
          'Walk 10-20 minutes today at a steady pace.',
        ];
        nextStep =
            'Track your next meal before eating it, then take a 10-minute walk within 30 minutes after that meal.';
        followUp = 'What is your current weight and target weight?';
      case _PlannerTopic.weightGain:
        insight =
            'You’re probably not getting enough calories, protein, or resistance work to move weight up consistently.';
        actions = <String>[
          'Add one calorie-dense meal or snack today.',
          'Include protein in every meal.',
          'Do a short strength session to signal growth.',
        ];
        nextStep =
            'Plan your next meal and one strength session before the day gets away from you.';
        followUp = 'What is your current weight and goal weight?';
      case _PlannerTopic.hydration:
        insight =
            'Hydration usually drops when water intake is not visible and electrolytes are not kept up.';
        actions = <String>[
          'Drink a full glass of water now.',
          'Keep a bottle nearby and track refills.',
          'Add electrolytes if you have been sweating or training hard.',
        ];
        nextStep = 'Finish one glass of water in the next 5 minutes.';
        followUp = 'How much water have you had so far today?';
      case _PlannerTopic.fatigue:
        insight =
            'This kind of tiredness usually comes from sleep debt, dehydration, under-fueling, or too much mental load stacking up.';
        actions = <String>[
          'Get 10 minutes of sunlight and light movement now.',
          'Drink 500 ml water with electrolytes.',
          'Eat protein plus complex carbs in the next 60 minutes.',
        ];
        nextStep =
            'Run one 25-minute focused work block, then take a 5-minute movement break.';
        followUp =
            'How many hours did you sleep last night, and when was your last full meal?';
      case _PlannerTopic.sleep:
        insight =
            'Poor sleep is usually tied to inconsistent timing, evening screens, or caffeine too late in the day.';
        actions = <String>[
          'Set a fixed bedtime and wake time for tonight and tomorrow.',
          'Stop caffeine at least 8 hours before bed.',
          'Dim lights and avoid screens for the last 45 minutes before sleep.',
        ];
        nextStep =
            'Set a bedtime alarm right now and prep your wind-down routine.';
        followUp = 'What time do you need to wake up tomorrow?';
      case _PlannerTopic.recovery:
        insight =
            'Recovery slips when training, stress, and sleep are all pulling in the same direction without enough downtime.';
        actions = <String>[
          'Reduce today\'s training load.',
          'Hydrate and eat a recovery-focused meal.',
          'Protect a longer sleep window tonight.',
        ];
        nextStep =
            'Choose one thing to recover from today and give it a proper rest block.';
        followUp =
            'What needs the most recovery right now: sleep, training, or stress?';
      case _PlannerTopic.stress:
        insight =
            'Stress spikes when too many open loops and unresolved decisions stay active at once.';
        actions = <String>[
          'Do 2 minutes of box breathing (4-4-4-4).',
          'Write your top 3 stressors on paper.',
          'Define one actionable next step for each stressor.',
        ];
        nextStep =
            'Choose the single most urgent stressor and execute its next step first.';
        followUp =
            'Which stressor needs action today, and which one can wait 24 hours?';
      case _PlannerTopic.burnout:
        insight =
            'Burnout shows up when effort stays high for too long and the recovery window stays too small.';
        actions = <String>[
          'Cut one nonessential commitment today.',
          'Block real recovery time on your calendar.',
          'Tell one person what is overloaded right now.',
        ];
        nextStep =
            'Remove one load-bearing task from today before you add anything else.';
        followUp = 'What is draining you the fastest right now?';
      case _PlannerTopic.nutrition:
        insight =
            'Nutrition usually improves fastest when meal quality and protein consistency improve together.';
        actions = <String>[
          'Build your next meal around protein first.',
          'Add one high-fiber food (vegetable, fruit, or oats).',
          'Prepare a healthy snack to prevent reactive eating.',
        ];
        nextStep =
            'Plan your next two meals now so decisions are already made.';
        followUp =
            'Any dietary restrictions, and what foods do you already have available today?';
      case _PlannerTopic.exercise:
        insight =
            'Exercise progress comes from consistency and gradual overload, not random hard sessions.';
        actions = <String>[
          'Warm up for 5 minutes before training.',
          'Do one full-body session today (squat/push/pull/core).',
          'Finish with 5 minutes of easy cooldown and stretching.',
        ];
        nextStep =
            'Start your first set within the next 15 minutes at moderate effort.';
        followUp =
            'Do you want a beginner, intermediate, or advanced session for today?';
      case _PlannerTopic.confidence:
        insight =
            'Confidence grows from proof, repetition, and surviving small reps of the hard thing.';
        actions = <String>[
          'Pick one situation that feels intimidating.',
          'Practice the first sentence or first action once.',
          'Log one win afterward so the evidence is visible.',
        ];
        nextStep = 'Rehearse the hardest part once before the day ends.';
        followUp = 'What situation is testing your confidence most right now?';
      case _PlannerTopic.discipline:
        insight =
            'Discipline gets easier when the rule is obvious and the excuse path is closed off.';
        actions = <String>[
          'Choose one rule for today only.',
          'Remove one easy distraction or escape path.',
          'Commit publicly or in writing before you start.',
        ];
        nextStep =
            'Write the rule down and follow it once before you negotiate again.';
        followUp = 'What is the one rule you want to follow today?';
      case _PlannerTopic.focus:
        insight =
            'Focus breaks when attention gets fragmented by notifications, context switching, and unclear task boundaries.';
        actions = <String>[
          'Choose one priority outcome for this block.',
          'Silence nonessential notifications and close extra tabs.',
          'Run one 25-minute deep-focus cycle with a single task.',
        ];
        nextStep =
            'Start a 25-minute timer and commit to one task until it ends.';
        followUp =
            'What is the one task you will focus on for the next 25 minutes?';
      case _PlannerTopic.procrastination:
        insight =
            'Procrastination often signals hidden friction, fear of imperfect output, or unclear first steps.';
        actions = <String>[
          'Define a 5-minute starter action only.',
          'Lower the quality bar for the first draft.',
          'Start immediately before negotiating with yourself.',
        ];
        nextStep =
            'Complete one 5-minute starter action now and log it as a win.';
        followUp = 'What 5-minute starter action can you do right now?';
      case _PlannerTopic.habits:
        insight =
            'Habits stick when they are small, anchored to existing routines, and tracked consistently.';
        actions = <String>[
          'Pick one tiny habit with a clear trigger.',
          'Attach it to a routine you already do daily.',
          'Track completion visibly for the next 7 days.',
        ];
        nextStep =
            'Define your habit trigger and complete the first rep today.';
        followUp = 'Which single habit should become automatic this week?';
      case _PlannerTopic.productivity:
      case _PlannerTopic.timeManagement:
      case _PlannerTopic.taskPlanning:
      case _PlannerTopic.habitBuilding:
        insight =
            'Productivity drops when the task is vague and context switching keeps pulling you around.';
        actions = <String>[
          'Pick one priority task only.',
          'Break it into a 10-minute starter action.',
          'Silence notifications for one focused block.',
        ];
        nextStep =
            'Run a 25-minute timer and finish your first defined subtask.';
        followUp = 'What single task will move your day forward the most?';
      case _PlannerTopic.mentalHealth:
        insight =
            'Mental strain often builds when hard thoughts stay unspoken and routines start slipping.';
        actions = <String>[
          'Name the feeling clearly in one sentence.',
          'Take a 10-minute walk or grounding break.',
          'Reach out to one trusted person for support today.',
        ];
        nextStep =
            'Send one support message now and commit to a calming routine tonight.';
        followUp =
            'Would you like a 5-minute grounding exercise you can do immediately?';
      case _PlannerTopic.motivation:
        insight = 'Motivation usually shows up after you start, not before.';
        actions = <String>[
          'Choose one task tied to your main goal.',
          'Shrink it to a 10-minute first step.',
          'Start immediately with a visible timer.',
        ];
        nextStep = 'Complete that 10-minute step before doing anything else.';
        followUp = 'What exact 10-minute step are you committing to right now?';
      case _PlannerTopic.goalRecovery:
        insight =
            'Goal recovery works best when you diagnose drift quickly and restart with a narrowed, realistic checkpoint.';
        actions = <String>[
          'Identify why momentum broke (time, scope, energy, or clarity).',
          'Reset the goal into one recoverable weekly milestone.',
          'Schedule a restart action within the next 24 hours.',
        ];
        nextStep =
            'Pick one recovery milestone and block it on your calendar right now.';
        followUp =
            'What caused the drift, and what is the first recovery milestone?';
      case _PlannerTopic.futureSelf:
        insight =
            'Future-self alignment strengthens when today\'s actions are explicitly tied to the person you want to become.';
        actions = <String>[
          'Name one future-self trait you want to embody.',
          'Choose one action today that proves that trait.',
          'Review tonight whether your behavior matched your future identity.',
        ];
        nextStep = 'Complete one identity-proof action before the day ends.';
        followUp = 'What future-self trait are you proving today?';
      case _PlannerTopic.purpose:
        insight =
            'Purpose feels clearer when daily work maps to core values and long-term direction instead of short-term urgency alone.';
        actions = <String>[
          'Write one sentence for why this goal matters to your life direction.',
          'Choose one action that reflects your top value today.',
          'Cut one low-value task that does not serve your purpose.',
        ];
        nextStep =
            'Do the highest-purpose action first in your next work block.';
        followUp =
            'What value or purpose are you serving with your next action?';
      case _PlannerTopic.relationships:
      case _PlannerTopic.career:
      case _PlannerTopic.learning:
      case _PlannerTopic.personalGrowth:
      case _PlannerTopic.decisionMaking:
      case _PlannerTopic.goals:
        insight =
            'Goals slip when they never turn into weekly actions and measurable checkpoints.';
        actions = <String>[
          'Pick one outcome that matters most right now.',
          'Define one measurable milestone for this week.',
          'Schedule the first action on your calendar today.',
        ];
        nextStep =
            'Block time for the first milestone action in the next 24 hours.';
        followUp =
            'What outcome matters most right now, and what is the next step?';
      case _PlannerTopic.generalChat:
        insight =
            'When priorities are unclear, progress slows because effort gets spread too thin.';
        actions = <String>[
          'Pick one outcome you want by end of day.',
          'Choose one action that directly drives it.',
          'Do that action in a focused 10-minute sprint.',
        ];
        nextStep =
            'Start the first 10-minute sprint now at your current energy ($pct%).';
        followUp = 'What result do you want to achieve today?';
    }

    return AssistantResponseTemplates.smartPlannerBlock(
      insight: insight,
      actions: actions,
      nextStep: nextStep,
      followUp: followUp,
      energy: energy,
    );
  }
}

enum _PlannerTopic {
  weightLoss,
  weightGain,
  hydration,
  fatigue,
  sleep,
  recovery,
  stress,
  burnout,
  nutrition,
  exercise,
  confidence,
  discipline,
  focus,
  procrastination,
  habits,
  productivity,
  timeManagement,
  taskPlanning,
  habitBuilding,
  mentalHealth,
  motivation,
  goals,
  goalRecovery,
  futureSelf,
  purpose,
  relationships,
  career,
  learning,
  personalGrowth,
  decisionMaking,
  generalChat,
}
