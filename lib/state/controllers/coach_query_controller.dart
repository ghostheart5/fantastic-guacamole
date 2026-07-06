import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/calendar_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/flowmap_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coachQueryControllerProvider = Provider<CoachQueryController>((ref) {
  return CoachQueryController(ref);
});

class CoachCoachingResult {
  const CoachCoachingResult({
    required this.prompt,
    required this.message,
    required this.savedNotes,
  });

  final String prompt;
  final String message;
  final String? savedNotes;
}

class CoachQueryController {
  const CoachQueryController(this._ref);

  final Ref _ref;

  bool detectsCrisis(String text) => CrisisDetectionPolicy.detects(text);

  Future<CoachCoachingResult> requestCoaching({
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
        ? 'Give me a practical coaching check-in for my current energy and '
              'emotional state. Include one clear next action.'
        : notes;
    final String knowledge = _knowledgeContext();
    final Map<String, dynamic> moduleSnapshot = _coachModuleSnapshot(
      energy: energy,
      reflection: notes,
    );
    final String aiInput = knowledge.isEmpty
        ? prompt
        : '$prompt\n\nCONTEXT SNAPSHOT:\n$knowledge';

    _ref.read(aiInputProvider.notifier).set(aiInput);
    final recommendation = await _safeCoachQuery(
      input: aiInput,
      history: history,
      context: <String, dynamic>{
        'source': 'smart_coach',
        'energy': energy,
        'emotion': emotion.name,
        'reflection': notes,
        'knowledge': knowledge,
        ...moduleSnapshot,
      },
      source: 'smart_coach',
    );

    final String generated = recommendation?.message.trim() ?? '';
    final String message = generated.isNotEmpty
        ? generated
        : _buildCoachingMessage(energy, emotion, notes);

    _ref.read(profileProvider.notifier).addXP(10);

    return CoachCoachingResult(
      prompt: prompt,
      message: message,
      savedNotes: savedNotes,
    );
  }

  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    final String knowledge = _knowledgeContext();
    final Map<String, dynamic> moduleSnapshot = _coachModuleSnapshot(
      energy: energy,
      reflection: reflection,
    );
    final String aiInput = knowledge.isEmpty
        ? input
        : '$input\n\nCONTEXT SNAPSHOT:\n$knowledge';

    _ref.read(aiInputProvider.notifier).set(aiInput);
    final recommendation = await _safeCoachQuery(
      input: aiInput,
      history: history,
      context: <String, dynamic>{
        'source': 'smart_coach_follow_up',
        'energy': energy,
        'emotion': emotion.name,
        'reflection': reflection,
        'knowledge': knowledge,
        ...moduleSnapshot,
      },
      source: 'smart_coach_follow_up',
    );

    final String generated = recommendation?.message.trim() ?? '';
    return generated.isNotEmpty
        ? generated
        : _buildFollowUpReply(input, energy, emotion);
  }

  String _knowledgeContext() {
    final goals = _ref.read(goalsProvider);
    final memories = _ref.read(memoriesProvider);

    final List<String> topGoals = goals
        .take(3)
        .map((goal) => goal.title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final List<String> recentMemories = memories
        .take(3)
        .map((memory) => memory.text.trim())
        .where((text) => text.isNotEmpty)
        .map((text) => text.length > 90 ? '${text.substring(0, 90)}...' : text)
        .toList(growable: false);

    final List<String> chunks = <String>[];
    if (topGoals.isNotEmpty) {
      chunks.add('Top goals: ${topGoals.join(' | ')}');
    }
    if (recentMemories.isNotEmpty) {
      chunks.add('Recent memories: ${recentMemories.join(' | ')}');
    }
    return chunks.join('\n');
  }

  Map<String, dynamic> _coachModuleSnapshot({
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
    final AsyncValue<List<FlowmapNode>> flowmapAsync = _ref.read(
      flowmapProvider,
    );
    final progression = _ref.read(progressionProvider).progress;
    final soulState = _ref.read(soulStateProvider);
    final flowmapNodes = flowmapAsync.maybeWhen(
      data: (List<FlowmapNode> nodes) => nodes,
      orElse: () => const <FlowmapNode>[],
    );
    final planPreview = _ref
        .read(calendarServiceProvider)
        .generateAdaptivePlan(tasks: tasks, energy: energy)
        .take(3)
        .map((block) => block.title)
        .toList(growable: false);

    return <String, dynamic>{
      'mode': 'smart_coach',
      'name': profile.name,
      'level': profile.level,
      'xp': profile.xp,
      'streak': profile.streak,
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
        'flowmap': <String, dynamic>{
          'count': flowmapNodes.length,
          'top': flowmapNodes
              .take(5)
              .map((node) => node.title)
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
          'recent': memories
              .take(5)
              .map((memory) => memory.text)
              .toList(growable: false),
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
        'soulmap': soulState.toJson(),
      },
    };
  }

  Future<AIRecommendation?> _safeCoachQuery({
    required String input,
    required List<Map<String, String>> history,
    required Map<String, dynamic> context,
    required String source,
  }) async {
    try {
      return await _ref
          .read(aiResponseProvider.notifier)
          .executeCoachQuery(input: input, history: history, context: context);
    } catch (error, stackTrace) {
      Logger.error(
        'Coach query failed for $source; falling back to local response. $stackTrace',
        error,
      );
      return null;
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

  static String _buildCoachingMessage(
    double energy,
    EmotionalState emotion,
    String notes,
  ) {
    final int pct = (energy * 100).round();

    final String opening = energy > 0.65
        ? 'You\'re running strong at $pct% — that\'s real capacity to work with.'
        : energy < 0.4
        ? 'At $pct% energy, your body is sending a clear message. Honor it.'
        : 'Steady at $pct%. Consistency built here is what lasts.';

    final String insight;
    switch (emotion) {
      case EmotionalState.energized:
        insight =
            'You\'re energized — use this for something that truly matters to you, not just what\'s urgent. Bold decisions made in peak states stick.';
      case EmotionalState.focused:
        insight =
            'Your focus is sharp. Point it at the thing you\'ve been avoiding — that\'s usually where the most growth hides.';
      case EmotionalState.positive:
        insight =
            'Positivity compounds. Let it flow outward — encourage someone, start something creative, or strengthen a relationship you\'ve neglected.';
      case EmotionalState.calm:
        insight =
            'Calm is clarity. From here, you can see your life honestly. Are you building toward the future you actually want, or drifting?';
      case EmotionalState.neutral:
        insight =
            'Neutral days are the foundation. No one sees the reps you put in here, but you feel them. Steady work is still work.';
      case EmotionalState.scattered:
        insight =
            'When the mind scatters, simplify. Pick one thing — not ten, one. Completion restores clarity faster than anything else.';
      case EmotionalState.anxious:
        insight =
            'Anxiety often means you care deeply about something. Breathe, name what you\'re afraid of. A fear named loses half its power.';
      case EmotionalState.negative:
        insight =
            'Hard states are data, not verdicts. What is this feeling pointing toward? Discomfort is sometimes a compass, not an enemy.';
      case EmotionalState.fatigued:
        insight =
            'Recovery is not weakness — it\'s strategy. Your best work requires your best self. Rest today so you can show up fully tomorrow.';
    }

    final String closing = notes.isEmpty
        ? 'What\'s the most honest thing you could do for yourself right now?'
        : 'You wrote: "${notes.length > 80 ? '${notes.substring(0, 80)}...' : notes}" — sit with that. There\'s something important in it.';

    return '$opening\n\n$insight\n\n$closing';
  }

  static String _buildFollowUpReply(
    String question,
    double energy,
    EmotionalState emotion,
  ) {
    final String q = question.toLowerCase();
    if (q.contains('how') && (q.contains('start') || q.contains('begin'))) {
      return 'Start small, start now. The smallest honest action toward your intention is enough. Momentum follows movement, not the other way around.';
    }
    if (q.contains('afraid') || q.contains('fear') || q.contains('scared')) {
      return 'Fear is information, not instruction. What is it protecting you from, and is that protection still serving you? Often the answer is no.';
    }
    if (q.contains('motivat')) {
      return 'Motivation follows action — not the other way around. You don\'t wait to feel ready. You act, and readiness appears.';
    }
    if (q.contains('routine') || q.contains('habit')) {
      return 'Systems beat willpower every time. Build an environment where the right behavior is the easiest choice, and discipline becomes unnecessary.';
    }
    if (q.contains('purpose') || q.contains('meaning') || q.contains('why')) {
      return 'Purpose isn\'t found — it\'s built through what you repeatedly choose. What are you already choosing? That is your life\'s direction.';
    }
    if (q.contains('fail') || q.contains('mistake') || q.contains('wrong')) {
      return 'Failure is the fastest feedback loop available to you. Every person you admire has a longer list of failures than successes. The difference is they kept going.';
    }
    if (q.contains('stress') || q.contains('overwhelm')) {
      return 'When overwhelmed, your only job is to reduce the list. What are you doing that doesn\'t need to be done? Remove that first.';
    }
    final String vibe = energy < 0.4 || emotion == EmotionalState.fatigued
        ? 'Start with recovery, then act.'
        : 'Convert that insight into one concrete action.';
    return 'That\'s worth sitting with. The fact that you\'re asking the question means part of you already knows the answer — trust that. $vibe';
  }
}
