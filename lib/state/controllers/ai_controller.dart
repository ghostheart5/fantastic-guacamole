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
import 'package:fantastic_guacamole/engine/si/si_core.dart';
import 'package:fantastic_guacamole/engine/si/si_decision.dart';
import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
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

final aiControllerProvider = Provider<AIController>((ref) => AIController(ref));

/// Synchronous next-step text derived from the highest-priority pending task.
final nextActionTextProvider = Provider<String>((ref) {
  final tasks = ref.watch(tasksProvider).asData?.value;
  if (tasks == null || tasks.isEmpty) {
    return 'Create your first task to get started.';
  }
  return 'Focus on: ${tasks.first.title}';
});

final aiTriggerProvider = NotifierProvider<AITriggerNotifier, int>(
  AITriggerNotifier.new,
);
final aiAgentTraceProvider =
    NotifierProvider<AIAgentTraceNotifier, AgentResult?>(
      AIAgentTraceNotifier.new,
    );
final aiPersonalityProvider =
    NotifierProvider<AIPersonalityNotifier, AIPersonality>(
      AIPersonalityNotifier.new,
    );
final aiInputProvider = NotifierProvider<AIInputNotifier, String?>(
  AIInputNotifier.new,
);
final aiExecutionStatusProvider =
    NotifierProvider<AIExecutionStatusNotifier, AIExecutionStatus>(
      AIExecutionStatusNotifier.new,
    );
final aiMessageThrottleProvider = Provider<Throttle>((_) {
  return Throttle(const Duration(milliseconds: 900));
});
final aiSuggestionRateLimiterProvider = Provider<SlidingWindowRateLimiter>((_) {
  return SlidingWindowRateLimiter(
    maxRequests: 3,
    window: const Duration(seconds: 20),
  );
});

class AITriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

class AIAgentTraceNotifier extends Notifier<AgentResult?> {
  @override
  AgentResult? build() => null;

  void set(AgentResult? value) => state = value;
}

class AIPersonalityNotifier extends Notifier<AIPersonality> {
  @override
  AIPersonality build() => AIPersonality.coach;

  void set(AIPersonality value) => state = value;
}

class AIInputNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

class AIExecutionStatusNotifier extends Notifier<AIExecutionStatus> {
  @override
  AIExecutionStatus build() => const AIExecutionStatus.idle();

  void set(AIExecutionStatus value) => state = value;
}

class AIExecutionStatus {
  const AIExecutionStatus({
    required this.phase,
    this.requestId,
    this.durationMs,
    this.error,
  });

  const AIExecutionStatus.idle()
    : this(phase: 'idle', requestId: null, durationMs: null, error: null);

  final String phase;
  final String? requestId;
  final int? durationMs;
  final String? error;

  AIExecutionStatus copyWith({
    String? phase,
    String? requestId,
    int? durationMs,
    String? error,
  }) {
    return AIExecutionStatus(
      phase: phase ?? this.phase,
      requestId: requestId ?? this.requestId,
      durationMs: durationMs ?? this.durationMs,
      error: error,
    );
  }
}

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
        message:
            'Rapid repeat detected. Pause for a moment so I can give you a better response.',
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
        message:
            'Rapid repeat detected. Pause for a moment so I can give you a better response.',
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
        _ref.read(profileValuesStoreProvider).load().toList(growable: false)
          ..sort();

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
    final List<String> matchedSurfaces = _detectQuerySurfaces(
      input,
      forcedSurface: forcedSurface,
    );
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
        'memories': <String, dynamic>{
          'count': memories.length,
          'recent': memories.take(3).map((m) => m.text).toList(growable: false),
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
          'generatedFromEnergy': si.energy,
        },
        'flowmap': <String, dynamic>{'count': flowmapNodeCount},
        'emotions': <String, dynamic>{
          'current': emotion.name,
          'fatigue': si.fatigue,
        },
        'soulmap': soulState.toJson(),
        'timeline': <String, dynamic>{
          'count': timelineEvents.length,
          'recent': timelineEvents
              .take(5)
              .map((e) => e.title)
              .toList(growable: false),
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
      final List<TaskEntity> entities = await _ref
          .read(domainTaskRepositoryProvider)
          .getAllTasks();
      final List<TaskEntity> active =
          entities
              .where((TaskEntity item) => !item.isCompleted && !item.isCanceled)
              .toList(growable: true)
            ..sort(
              (TaskEntity a, TaskEntity b) =>
                  b.createdAt.compareTo(a.createdAt),
            );
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
      'logs': <String>[
        'log',
        'ledger',
        'activity',
        'record',
        'created',
        'added',
        'made',
      ],
      'memories': <String>['memory', 'remember', 'recall', 'history'],
      'notifications': <String>['notification', 'alert', 'reminder', 'prompt'],
      'plan': <String>['plan', 'schedule', 'calendar', 'time block'],
      'flowmap': <String>['flowmap', 'map', 'dependency', 'path'],
      'emotions': <String>['emotion', 'mood', 'energy', 'fatigue', 'feel'],
      'soulmap': <String>['soul', 'identity', 'continuity', 'narrative'],
      'timeline': <String>['timeline', 'milestone', 'event', 'chronology'],
      'trajectory': <String>[
        'trajectory',
        'momentum',
        'pressure',
        'prediction',
      ],
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
    if (matchedSurfaces.contains('tasks') ||
        matchedSurfaces.contains('trajectory')) {
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

  Map<String, dynamic> _responseContract(
    String primarySurface,
    List<String> matchedSurfaces,
  ) {
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

    final List<Map<String, dynamic>> existing =
        (raw == null || raw.trim().isEmpty)
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
    final Map<String, dynamic>? previousState = await siEngineService
        .loadState();
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
    _ref
        .read(aiExecutionStatusProvider.notifier)
        .set(const AIExecutionStatus.idle());
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

  Future<void> _recordSuggestionFeedback({
    required String actionId,
    required bool accepted,
  }) async {
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
      'lastSuggestionFeedback': <String, dynamic>{
        'actionId': id,
        'accepted': accepted,
      },
    });
    _ref.invalidate(siEngineStateProvider);
  }
}

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

class AIResponseController extends AsyncNotifier<AIRecommendation?> {
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
          AIPersonality.coach;
      final input = inputOverride ?? ref.read(aiInputProvider);

      final AiCreditSpendResult spend = await creditService.spend(
        premium: hasPremiumAccess,
        amount: _aiCreditCost(input: input, personality: personality),
      );
      ref.invalidate(aiCreditWalletProvider);

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
          .take(8)
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
  if (existing.length > 24) {
    return existing.sublist(existing.length - 24);
  }
  return existing;
}

List<Map<String, String>> _summarizeHistory(List<Map<String, String>> history) {
  final Iterable<Map<String, String>> tail = history.length > 6
      ? history.sublist(history.length - 6)
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
