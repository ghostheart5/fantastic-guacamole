import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/core/utils/rate_limiter.dart';
import 'package:fantastic_guacamole/core/utils/throttle.dart';
import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/core/si_core.dart' as modular_si;
import 'package:fantastic_guacamole/engine/si/models/si_state.dart'
    show SIPersona, PersonalityTraits;
import 'package:fantastic_guacamole/engine/si/si_decision.dart';
import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:fantastic_guacamole/engine/si/si_task_core.dart';
import 'package:fantastic_guacamole/engine/si/synthetic_intelligence_engine.dart';
import 'package:fantastic_guacamole/state/controllers/ai_memory_selection.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/calendar_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/flowmap_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/learning_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/profile_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'ai_controller.providers.dart';
part 'ai_controller.response.dart';
part 'ai_controller.helpers.dart';

final aiControllerProvider = Provider<AIController>((ref) => AIController(ref));

/// Synchronous next-step text derived from the highest-priority pending task.
final nextActionTextProvider = Provider<String>((ref) {
  final tasks = ref.watch(tasksProvider).asData?.value;
  if (tasks == null || tasks.isEmpty) {
    return 'Create your first task to get started.';
  }
  return 'Focus on: ${tasks.first.title}';
});

class AIController {
  /// Main chatbot controller entry point:
  /// receives user text, builds the request context, routes to orchestrator,
  /// and persists resulting SI state/memory snapshots.
  AIController(this._ref);

  final Ref _ref;
  static const String _neuralDumpKey = 'neural_dump';

  Future<AIRecommendation?> sendMessage(String text) async {
    final String rawInput = text.trim();
    final String? forcedSurface = _extractForcedSurface(rawInput);
    final String input = _stripLeadingSurfaceCommand(rawInput);
    if (input.isEmpty) {
      return null;
    }

    final Throttle throttle = _ref.read(aiMessageThrottleProvider);
    if (!throttle.isReady) {
      return const AIRecommendation(
        message: 'Rapid repeat detected. Pause for a moment so I can give you a better response.',
        reasoning: 'throttled',
        emotion: 'balanced',
        confidence: 0.6,
      );
    }

    bool accepted = false;
    throttle.run(() {
      accepted = true;
    });
    if (!accepted) {
      return const AIRecommendation(
        message: 'Rapid repeat detected. Pause for a moment so I can give you a better response.',
        reasoning: 'throttled',
        emotion: 'balanced',
        confidence: 0.6,
      );
    }

    final List<TaskEntity> taskEntities = await _loadConsoleTaskEntities();
    final List<Task> tasks = _mapTaskEntitiesToTasks(taskEntities);
    final Map<String, dynamic>? previousState = await _ref
        .read(siEngineServiceProvider)
        .loadState();
    final si = _ref.read(siStateProvider);
    final learning = _ref.read(learningProvider);
    final profile = _ref.read(profileProvider);
    final emotion = _ref.read(emotionProvider);
    final goals = _ref.read(goalsProvider);
    final insightsBundle = _ref.read(insightsBundleProvider);
    final logsState = _ref.read(logsProvider);
    final memories = _ref.read(memoriesProvider);
    final notifications = _ref.read(notificationProvider);
    final timelineEvents = _ref.read(timelineProvider);
    final flowmapAsync = _ref.read(flowmapProvider);
    final progression = _ref.read(progressionProvider).progress;
    final soulState = _ref.read(soulStateProvider);
    final trajectory = _ref.read(trajectorySummaryProvider);
    final List<String> coreValues =
        _ref.read(profileValuesStoreProvider).load().toList(growable: false)..sort();

    final List<Map<String, String>> history = <Map<String, String>>[];
    final dynamic rawHistory = previousState?['historySummary'];
    if (rawHistory is List<dynamic>) {
      for (final dynamic item in rawHistory) {
        if (item is Map<String, dynamic>) {
          final String role = item['role']?.toString() ?? '';
          final String content = item['content']?.toString() ?? '';
          if (role.isNotEmpty && content.isNotEmpty) {
            history.add(<String, String>{'role': role, 'content': content});
          }
        }
      }
    }

    final int flowmapNodeCount = flowmapAsync.maybeWhen(
      data: (nodes) => nodes.length,
      orElse: () => 0,
    );
    final List<String> planPreview = _ref
        .read(calendarServiceProvider)
        .generateAdaptivePlan(tasks: tasks, energy: si.energy)
        .take(3)
        .map((block) => block.title)
        .toList(growable: false);
    final List<String> matchedSurfaces = _detectQuerySurfaces(input, forcedSurface: forcedSurface);
    final String primarySurface = matchedSurfaces.first;

    final Map<String, dynamic> context = <String, dynamic>{
      'source': 'si_console',
      'mode': 'system_console',
      'intent': _deriveConsoleIntent(matchedSurfaces),
      'querySurface': primarySurface,
      'matchedSurfaces': matchedSurfaces,
      'forcedSurface': ?forcedSurface,
      'responseContract': _responseContract(primarySurface, matchedSurfaces),
      'name': profile.name,
      'level': profile.level,
      'xp': profile.xp,
      'streak': profile.streak,
      'energy': si.energy,
      'emotion': emotion.name,
      'fatigue': si.fatigue,
      'completedToday': si.completedToday,
      'availableSurfaces': <String>[
        'tasks',
        'progression',
        'goals',
        'insights',
        'logs',
        'memories',
        'notifications',
        'plan',
        'flowmap',
        'emotions',
        'soulmap',
        'timeline',
        'trajectory',
        'si_console',
      ],
      'featureSnapshot': <String, dynamic>{
        'tasks': <String, dynamic>{
          'count': tasks.length,
          'top': tasks.take(5).map((Task t) => t.title).toList(growable: false),
          'recentCreated': taskEntities
              .take(5)
              .map((TaskEntity item) => item.title)
              .toList(growable: false),
        },
        'progression': <String, dynamic>{
          'level': progression.level,
          'xp': progression.xp,
          'xpToNext': progression.xpToNext,
          'streak': progression.streak,
          'title': progression.levelTitle,
        },
        'goals': <String, dynamic>{
          'count': goals.length,
          'top': goals.take(5).map((g) => g.title).toList(growable: false),
        },
        'insights': <String, dynamic>{
          'count': insightsBundle.items.length,
          'summary': insightsBundle.summary,
          'top': insightsBundle.items.take(5).map((item) => item.title).toList(growable: false),
        },
        'logs': <String, dynamic>{
          'count': logsState.entries.length,
          'recent': logsState.entries.take(5).map((entry) => entry.message).toList(growable: false),
        },
        'memories': <String, dynamic>{
          'count': memories.length,
          'recent': memories.take(3).map((m) => m.text).toList(growable: false),
        },
        'notifications': <String, dynamic>{
          'count': notifications.length,
          'unread': notifications.where((item) => !item.isRead).length,
          'recent': notifications.take(5).map((item) => item.title).toList(growable: false),
        },
        'plan': <String, dynamic>{'preview': planPreview, 'generatedFromEnergy': si.energy},
        'flowmap': <String, dynamic>{'count': flowmapNodeCount},
        'emotions': <String, dynamic>{'current': emotion.name, 'fatigue': si.fatigue},
        'soulmap': soulState.toJson(),
        'timeline': <String, dynamic>{
          'count': timelineEvents.length,
          'recent': timelineEvents.take(5).map((e) => e.title).toList(growable: false),
        },
        'trajectory': <String, dynamic>{
          'pressure': trajectory.pressureIndex,
          'momentum': trajectory.momentum,
          'prediction': trajectory.predictionOutcome,
        },
        'coreValues': coreValues,
      },
    };

    final AgentRequest request = AgentRequest(
      prompt: input,
      context: context,
      history: history,
      tasks: tasks,
      si: si,
      learning: learning,
      personality: AIPersonality.strategist,
    );

    _ref.read(aiInputProvider.notifier).set(input);
    return _ref
        .read(aiResponseProvider.notifier)
        .execute(
          inputOverride: input,
          personalityOverride: AIPersonality.strategist,
          preferredAgent: null,
          history: history,
          context: context,
          requestOverride: request,
        );
  }

  Future<List<TaskEntity>> _loadConsoleTaskEntities() async {
    try {
      final List<TaskEntity> entities = await _ref.read(domainTaskRepositoryProvider).getAllTasks();
      final List<TaskEntity> active =
          entities
              .where((TaskEntity item) => !item.isCompleted && !item.isCanceled)
              .toList(growable: true)
            ..sort((TaskEntity a, TaskEntity b) => b.createdAt.compareTo(a.createdAt));
      return active;
    } catch (_) {
      final List<Task> fallback = await _ref.read(tasksProvider.future);
      return fallback
          .map(
            (Task item) => TaskEntity(
              id: item.id,
              title: item.title,
              createdAt: DateTime.now(),
              priority: item.priority,
              difficulty: item.difficulty,
              energyRequired: item.energyRequired,
              scheduledFor: item.scheduledFor,
              goalId: item.goalId,
              subtasks: item.subtasks,
              recurrenceRule: item.recurrenceRule,
            ),
          )
          .toList(growable: false);
    }
  }

  List<Task> _mapTaskEntitiesToTasks(List<TaskEntity> entities) {
    return entities
        .map(
          (TaskEntity item) => Task(
            id: item.id,
            title: item.title,
            priority: item.priority,
            difficulty: item.difficulty,
            energyRequired: item.energyRequired,
            scheduledFor: item.scheduledFor,
            goalId: item.goalId,
            subtasks: item.subtasks,
            recurrenceRule: item.recurrenceRule,
          ),
        )
        .toList(growable: false);
  }

  List<String> _detectQuerySurfaces(String input, {String? forcedSurface}) {
    final String lowered = input.toLowerCase();
    final Map<String, List<String>> surfaceKeywords = <String, List<String>>{
      'tasks': <String>[
        'task',
        'todo',
        'focus',
        'next action',
        'priority',
        'create',
        'created',
        'added',
        'made',
        'new task',
      ],
      'progression': <String>['xp', 'level', 'streak', 'progress', 'rank'],
      'goals': <String>['goal', 'target', 'objective', 'mission'],
      'insights': <String>['insight', 'signal', 'pattern', 'analysis'],
      'logs': <String>['log', 'ledger', 'activity', 'record', 'created', 'added', 'made'],
      'memories': <String>['memory', 'remember', 'recall', 'history'],
      'notifications': <String>['notification', 'alert', 'reminder', 'prompt'],
      'plan': <String>['plan', 'schedule', 'calendar', 'time block'],
      'flowmap': <String>['flowmap', 'map', 'dependency', 'path'],
      'emotions': <String>['emotion', 'mood', 'energy', 'fatigue', 'feel'],
      'soulmap': <String>['soul', 'identity', 'continuity', 'narrative'],
      'timeline': <String>['timeline', 'milestone', 'event', 'chronology'],
      'trajectory': <String>['trajectory', 'momentum', 'pressure', 'prediction'],
    };

    final List<String> matched = <String>[];
    if (forcedSurface != null && forcedSurface.isNotEmpty) {
      matched.add(forcedSurface);
    }
    surfaceKeywords.forEach((String surface, List<String> keywords) {
      if (keywords.any(lowered.contains)) {
        if (!matched.contains(surface)) {
          matched.add(surface);
        }
      }
    });

    return matched.isEmpty ? <String>['general'] : matched;
  }

  String? _extractForcedSurface(String input) {
    if (!input.startsWith('/')) {
      return null;
    }
    final String token = input.split(RegExp(r'\s+')).first.toLowerCase();
    const Map<String, String> aliases = <String, String>{
      '/tasks': 'tasks',
      '/task': 'tasks',
      '/progression': 'progression',
      '/xp': 'progression',
      '/goals': 'goals',
      '/goal': 'goals',
      '/memories': 'memories',
      '/memory': 'memories',
      '/plan': 'plan',
      '/planner': 'plan',
      '/flowmap': 'flowmap',
      '/flow': 'flowmap',
      '/emotions': 'emotions',
      '/emotion': 'emotions',
      '/soulmap': 'soulmap',
      '/soul': 'soulmap',
      '/timeline': 'timeline',
      '/milestones': 'timeline',
      '/trajectory': 'trajectory',
    };
    return aliases[token];
  }

  String _stripLeadingSurfaceCommand(String input) {
    if (!input.startsWith('/')) {
      return input;
    }
    final String? forcedSurface = _extractForcedSurface(input);
    if (forcedSurface == null) {
      return input;
    }
    final List<String> parts = input.split(RegExp(r'\s+'));
    if (parts.length <= 1) {
      return forcedSurface;
    }
    return parts.sublist(1).join(' ').trim();
  }

  String _deriveConsoleIntent(List<String> matchedSurfaces) {
    if (matchedSurfaces.contains('plan')) {
      return 'planning';
    }
    if (matchedSurfaces.contains('tasks') || matchedSurfaces.contains('trajectory')) {
      return 'recommendation';
    }
    if (matchedSurfaces.contains('timeline') ||
        matchedSurfaces.contains('memories') ||
        matchedSurfaces.contains('goals')) {
      return 'summarization';
    }
    if (matchedSurfaces.contains('flowmap')) {
      return 'research';
    }
    return 'chat';
  }

  Map<String, dynamic> _responseContract(String primarySurface, List<String> matchedSurfaces) {
    return <String, dynamic>{
      'style': 'module_brief',
      'sections': <String>['signal', 'insight', 'next_actions'],
      'maxActions': 3,
      'primarySurface': primarySurface,
      'matchedSurfaces': matchedSurfaces,
      'grounding': 'featureSnapshot_only',
      'constraints': <String>[
        'Avoid generic motivational filler.',
        'Reference concrete app data when available.',
        'State uncertainty if data is missing.',
      ],
    };
  }

  Future<void> appendNeuralDumpEntry({
    required String task,
    required String reasoning,
    required double confidence,
    required int duration,
    required double quality,
    DateTime? timestamp,
  }) async {
    final store = _ref.read(secureStoreProvider);
    final String? raw = await store.readString(_neuralDumpKey);

    final List<Map<String, dynamic>> existing = (raw == null || raw.trim().isEmpty)
        ? <Map<String, dynamic>>[]
        : ((jsonDecode(raw) as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> e) => e)
              .toList());

    final NeuralEntry entry = NeuralEntry(
      task: task,
      reasoning: reasoning,
      confidence: confidence,
      duration: duration,
      quality: quality,
      timestamp: timestamp ?? DateTime.now(),
    );

    existing.add(entry.toJson());
    await store.writeString(_neuralDumpKey, jsonEncode(existing));
  }

  Future<AIRecommendation?> retryMessage(String messageId) async {
    final siEngineService = _ref.read(siEngineServiceProvider);
    final Map<String, dynamic>? previousState = await siEngineService.loadState();
    final String id = messageId.trim();
    if (id.isEmpty || previousState == null) {
      return null;
    }

    final bool matches =
        previousState['requestId']?.toString() == id ||
        previousState['responseHash']?.toString() == id ||
        previousState['actionKey']?.toString() == id;
    if (!matches) {
      return null;
    }

    final String input = previousState['input']?.toString().trim() ?? '';
    if (input.isEmpty) {
      return null;
    }
    return sendMessage(input);
  }

  Future<void> clearConversation() async {
    final siEngineService = _ref.read(siEngineServiceProvider);
    await siEngineService.saveState(<String, dynamic>{
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'history': const <Map<String, String>>[],
      'historySummary': const <Map<String, String>>[],
      'memoryEvents': const <Map<String, dynamic>>[],
      'message': '',
      'input': '',
    });
    _ref.read(aiInputProvider.notifier).set(null);
    _ref.read(aiAgentTraceProvider.notifier).set(null);
    _ref.read(aiExecutionStatusProvider.notifier).set(const AIExecutionStatus.idle());
    _ref.read(siMemoryProvider.notifier).clear();
    _ref.invalidate(aiResponseProvider);
    _ref.invalidate(siEngineStateProvider);
  }

  Future<void> acceptSuggestion(String actionId) async {
    await _recordSuggestionFeedback(actionId: actionId, accepted: true);
  }

  Future<void> rejectSuggestion(String actionId) async {
    await _recordSuggestionFeedback(actionId: actionId, accepted: false);
  }

  Future<void> _recordSuggestionFeedback({required String actionId, required bool accepted}) async {
    final String id = actionId.trim();
    if (id.isEmpty) {
      return;
    }
    final siEngineService = _ref.read(siEngineServiceProvider);
    final Map<String, dynamic>? state = await siEngineService.loadState();
    final List<Map<String, dynamic>> events = _appendMemoryEvent(
      previousState: state,
      memoryEvent: <String, dynamic>{
        'timestampUtc': DateTime.now().toUtc().toIso8601String(),
        'type': accepted ? 'suggestion_accepted' : 'suggestion_rejected',
        'actionId': id,
      },
    );
    await siEngineService.saveState(<String, dynamic>{
      ...?state,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'memoryEvents': events,
      'lastSuggestionFeedback': <String, dynamic>{'actionId': id, 'accepted': accepted},
    });
    _ref.invalidate(siEngineStateProvider);
  }
}

