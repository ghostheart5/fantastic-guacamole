import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/core/utils/rate_limiter.dart';
import 'package:fantastic_guacamole/core/utils/throttle.dart';
import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_detection_service.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_response_templates.dart';
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
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/calendar_provider.dart';
import 'package:fantastic_guacamole/state/providers/core_values_provider.dart';
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
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:fantastic_guacamole/state/providers/soul_map_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'ai_controller.helpers.dart';
part 'ai_controller.providers.dart';
part 'ai_controller.response.dart';

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
    final int timelineOverdueCount = _ref.read(timelineOverdueProvider).length;
    final int timelineUpcomingCount = _ref
        .read(timelineUpcomingProvider)
        .length;
    final int timelineHealthScore = _ref.read(timelineHealthScoreProvider);
    final int timelineRiskScore = _ref.read(timelineRiskScoreProvider);
    final int timelineRiskEventsCount = _ref
        .read(timelineRiskEventsProvider)
        .length;
    final int timelineRecommendationCount = _ref
        .read(timelineRecommendationsProvider)
        .length;
    final List<TimelineEventEntity> timelineUpcomingEvents = _ref.read(
      timelineUpcomingProvider,
    );
    final List<MilestoneEntity> milestones =
        _ref.read(milestonesProvider).asData?.value ??
        const <MilestoneEntity>[];
    final MilestoneSummary milestoneSummary = _ref.read(
      milestoneSummaryProvider,
    );
    final List<MilestoneRisk> milestoneRisks = _ref.read(
      milestoneRisksProvider,
    );
    final List<MilestoneEntity> milestoneUpcoming = _ref.read(
      milestoneUpcomingProvider,
    );
    final List<MilestoneEntity> milestoneOverdue = _ref.read(
      milestoneOverdueProvider,
    );
    final CoreValuesAlignment coreValuesAlignment = _ref.read(
      coreValuesAlignmentProvider,
    );
    final SoulMapAlignment soulMapAlignment = _ref.read(
      soulMapAlignmentProvider,
    );
    final SoulMapFutureSelfComparison soulMapComparison = _ref.read(
      soulMapFutureSelfComparisonProvider,
    );
    final flowmapAsync = _ref.read(flowmapProvider);
    final progression = _ref.read(progressionProvider).progress;
    final soulState = _ref.read(soulStateProvider);
    final trajectory = _ref.read(trajectorySummaryProvider);
    final List<String> coreValues = coreValuesAlignment.selectedValues.toList(
      growable: false,
    )..sort();

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
    final List<String> selectedMemorySummaries = memories
        .take(3)
        .map((memory) => memory.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final List<String> matchedSurfaces = _detectQuerySurfaces(
      input,
      forcedSurface: forcedSurface,
    );
    final String primarySurface = matchedSurfaces.first;
    final String siIntentCategory = _detectSIIntentCategory(
      input,
      matchedSurfaces,
    );
    final AIRecommendation? timelineDeterministic =
        _tryDeterministicTimelineResponse(
          input: input,
          forcedSurface: forcedSurface,
          matchedSurfaces: matchedSurfaces,
          category: siIntentCategory,
          timelineEvents: timelineEvents,
          timelineUpcomingEvents: timelineUpcomingEvents,
          timelineOverdueCount: timelineOverdueCount,
          timelineUpcomingCount: timelineUpcomingCount,
          timelineHealthScore: timelineHealthScore,
          timelineRiskScore: timelineRiskScore,
          timelineRiskEventsCount: timelineRiskEventsCount,
          timelineRecommendationCount: timelineRecommendationCount,
        );
    if (timelineDeterministic != null) {
      return timelineDeterministic;
    }
    final AIRecommendation? trajectoryDeterministic =
        _tryDeterministicTrajectoryResponse(
          input: input,
          forcedSurface: forcedSurface,
          matchedSurfaces: matchedSurfaces,
          category: siIntentCategory,
          pressure: trajectory.pressureIndex,
          momentum: trajectory.momentum,
          divergence: trajectory.behaviorDivergence,
          prediction: trajectory.predictionOutcome,
          alert: trajectory.alert,
        );
    if (trajectoryDeterministic != null) {
      return trajectoryDeterministic;
    }
    final AIRecommendation? milestoneDeterministic =
        _tryDeterministicMilestoneResponse(
          input: input,
          forcedSurface: forcedSurface,
          matchedSurfaces: matchedSurfaces,
          category: siIntentCategory,
          summary: milestoneSummary,
          milestones: milestones,
          risks: milestoneRisks,
          overdue: milestoneOverdue,
          upcoming: milestoneUpcoming,
        );
    if (milestoneDeterministic != null) {
      return milestoneDeterministic;
    }
    final AIRecommendation? soulMapDeterministic =
        _tryDeterministicSoulMapResponse(
          input: input,
          forcedSurface: forcedSurface,
          matchedSurfaces: matchedSurfaces,
          category: siIntentCategory,
          alignment: soulMapAlignment,
          comparison: soulMapComparison,
        );
    if (soulMapDeterministic != null) {
      return soulMapDeterministic;
    }
    final AIRecommendation? coreValuesDeterministic =
        _tryDeterministicCoreValuesResponse(
          input: input,
          forcedSurface: forcedSurface,
          matchedSurfaces: matchedSurfaces,
          category: siIntentCategory,
          alignment: coreValuesAlignment,
        );
    if (coreValuesDeterministic != null) {
      return coreValuesDeterministic;
    }
    final AssistantIntent assistantIntent =
        const DefaultAssistantIntentDetector().detect(
          input: input,
          surface: 'si_console',
        );
    final DefaultAssistantContextBuilder contextBuilder =
        const DefaultAssistantContextBuilder();
    final List<String> timelineSummaries = timelineEvents
        .take(3)
        .map((event) => event.title.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);

    final Map<String, dynamic> context = <String, dynamic>{
      'source': 'si_console',
      'mode': 'system_console',
      'intent': _deriveConsoleIntent(matchedSurfaces),
      'siIntentCategory': siIntentCategory,
      'querySurface': primarySurface,
      'matchedSurfaces': matchedSurfaces,
      'forcedSurface': forcedSurface,
      'responseContract': _responseContract(primarySurface, matchedSurfaces),
      'assistantIntent': assistantIntent.toJson(),
      'assistantContext': contextBuilder.buildSIConsoleContext(
        input: input,
        intent: assistantIntent,
        matchedSurfaces: matchedSurfaces,
        memorySummaries: selectedMemorySummaries,
        timelineSummaries: timelineSummaries,
        taskCount: tasks.length,
        goalCount: goals.length,
      ),
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
        'milestones',
        'values',
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
          'healthScore': timelineHealthScore,
          'riskScore': timelineRiskScore,
          'overdueCount': timelineOverdueCount,
          'upcomingCount': timelineUpcomingCount,
          'riskEventsCount': timelineRiskEventsCount,
          'recommendationCount': timelineRecommendationCount,
          'recent': timelineEvents
              .take(5)
              .map((e) => e.title)
              .toList(growable: false),
        },
        'milestones': <String, dynamic>{
          'count': milestoneSummary.total,
          'active': milestoneSummary.active,
          'completed': milestoneSummary.completed,
          'overdue': milestoneSummary.overdue,
          'upcoming': milestoneSummary.upcoming,
          'healthScore': milestoneSummary.healthScore,
          'momentumScore': milestoneSummary.momentumScore,
          'riskScore': milestoneSummary.riskScore,
          'next': milestoneSummary.nextMilestone?.title,
          'closest': milestoneSummary.closestMilestone?.title,
          'highestPriority': milestoneSummary.highestPriority?.title,
          'top': milestones
              .take(5)
              .map((MilestoneEntity m) => m.title)
              .toList(growable: false),
        },
        'trajectory': <String, dynamic>{
          'pressure': trajectory.pressureIndex,
          'momentum': trajectory.momentum,
          'prediction': trajectory.predictionOutcome,
        },
        'soulMapAlignment': <String, dynamic>{
          'overall': soulMapAlignment.overall,
          'strongest': soulMapDimensionTitle(soulMapAlignment.strongest),
          'weakest': soulMapDimensionTitle(soulMapAlignment.weakest),
          'scores': soulMapAlignment.scores.map(
            (SoulMapDimension key, SoulMapDimensionScore value) =>
                MapEntry<String, int>(soulMapDimensionTitle(key), value.score),
          ),
          'recommendations': soulMapAlignment.recommendations,
        },
        'soulMapComparison': <String, dynamic>{
          'currentSelfAlignment': soulMapComparison.currentSelfAlignment,
          'futureSelfReadiness': soulMapComparison.futureSelfReadiness,
          'gap': soulMapComparison.gap,
          'stance': soulMapComparison.stance,
          'recommendation': soulMapComparison.recommendation,
        },
        'coreValues': coreValues,
        'coreValuesAlignment': <String, dynamic>{
          'overall': coreValuesAlignment.overall,
          'strongest': coreValueTitle(coreValuesAlignment.strongest),
          'mostNeglected': coreValueTitle(coreValuesAlignment.mostNeglected),
          'scores': coreValuesAlignment.scores.map(
            (CoreValueType key, CoreValueScore value) =>
                MapEntry<String, int>(coreValueTitle(key), value.score),
          ),
          'recommendations': coreValuesAlignment.recommendations,
        },
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
    final AIRecommendation? recommendation = await _ref
        .read(aiResponseProvider.notifier)
        .execute(
          inputOverride: input,
          personalityOverride: AIPersonality.strategist,
          preferredAgent: null,
          history: history,
          context: context,
          requestOverride: request,
        );

    if (recommendation == null ||
        !_isStructuredSIResponse(recommendation.message)) {
      return _buildStructuredSIFallback(
        query: input,
        category: siIntentCategory,
        tasks: taskEntities,
        goalsCount: goals.length,
        timelineOverdueCount: timelineOverdueCount,
        timelineUpcomingCount: timelineUpcomingCount,
        timelineHealthScore: timelineHealthScore,
        timelineRiskScore: timelineRiskScore,
      );
    }

    return recommendation;
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
      'soulmap': <String>[
        'soul map',
        'soulmap',
        'analyze my life',
        'who am i becoming',
        'future self',
        'life direction',
        'legacy',
        'identity',
      ],
      'timeline': <String>['timeline', 'milestone', 'event', 'chronology'],
      'milestones': <String>[
        'milestones',
        'checkpoint',
        'milestone health',
        'milestone risk',
      ],
      'values': <String>[
        'core values',
        'values alignment',
        'most neglected value',
      ],
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
      '/milestones': 'milestones',
      '/values': 'values',
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
        matchedSurfaces.contains('milestones') ||
        matchedSurfaces.contains('memories') ||
        matchedSurfaces.contains('goals')) {
      return 'summarization';
    }
    if (matchedSurfaces.contains('flowmap')) {
      return 'research';
    }
    return 'chat';
  }

  String _detectSIIntentCategory(String input, List<String> matchedSurfaces) {
    final String lowered = input.toLowerCase();
    bool hasAny(List<String> values) => values.any(lowered.contains);

    if (hasAny(<String>[
      'status',
      'system status',
      'system health',
      'health check',
    ])) {
      return 'System Status';
    }
    if (hasAny(<String>['milestone', 'milestones', 'checkpoint'])) {
      return 'Milestone Query';
    }
    if (hasAny(<String>[
      'soul map',
      'soulmap',
      'analyze my life',
      'who am i becoming',
      'future self',
      'life direction',
      'legacy',
    ])) {
      return 'Life Query';
    }
    if (hasAny(<String>[
      'core values',
      'values alignment',
      'most neglected value',
    ])) {
      return 'Core Values Query';
    }
    if (hasAny(<String>['goal', 'goals', 'target', 'objective', 'milestone'])) {
      return 'Goal Query';
    }
    if (hasAny(<String>['open tasks', 'task', 'tasks', 'todo', 'to-do'])) {
      return 'Task Query';
    }
    if (hasAny(<String>['project', 'projects', 'initiative', 'roadmap'])) {
      return 'Project Query';
    }
    if (hasAny(<String>[
      'behind schedule',
      'timeline',
      'due',
      'overdue',
      'deadline',
    ])) {
      return 'Timeline Query';
    }
    if (hasAny(<String>['progress', 'how am i doing', 'on track'])) {
      return 'Progress Query';
    }
    if (hasAny(<String>['recommend', 'suggest', 'advice', 'what should'])) {
      return 'Recommendation Query';
    }
    if (hasAny(<String>['priority', 'what next', 'do next', 'next action'])) {
      return 'Priority Query';
    }
    if (hasAny(<String>[
      'analytics',
      'analyze',
      'trend',
      'insight',
      'metrics',
    ])) {
      return 'Analytics Query';
    }
    if (hasAny(<String>['forget', 'memory', 'remember', 'recall'])) {
      return 'Memory Query';
    }
    if (hasAny(<String>['summarize my life', 'life summary', 'my life'])) {
      return 'Life Query';
    }

    if (matchedSurfaces.contains('goals')) {
      return 'Goal Query';
    }
    if (matchedSurfaces.contains('tasks')) {
      return 'Task Query';
    }
    if (matchedSurfaces.contains('timeline')) {
      return 'Timeline Query';
    }
    if (matchedSurfaces.contains('milestones')) {
      return 'Milestone Query';
    }
    if (matchedSurfaces.contains('soulmap')) {
      return 'Life Query';
    }
    if (matchedSurfaces.contains('values')) {
      return 'Core Values Query';
    }
    if (matchedSurfaces.contains('trajectory') ||
        matchedSurfaces.contains('insights')) {
      return 'Analytics Query';
    }
    if (matchedSurfaces.contains('memories')) {
      return 'Memory Query';
    }
    if (matchedSurfaces.contains('progression')) {
      return 'Progress Query';
    }
    return 'Recommendation Query';
  }

  bool _isStructuredSIResponse(String message) {
    final String lowered = message.toLowerCase();
    return lowered.contains('si analysis') &&
        lowered.contains('query') &&
        lowered.contains('current state') &&
        lowered.contains('next actions') &&
        lowered.contains('confidence');
  }

  AIRecommendation? _tryDeterministicTimelineResponse({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
    required List<TimelineEventEntity> timelineEvents,
    required List<TimelineEventEntity> timelineUpcomingEvents,
    required int timelineOverdueCount,
    required int timelineUpcomingCount,
    required int timelineHealthScore,
    required int timelineRiskScore,
    required int timelineRiskEventsCount,
    required int timelineRecommendationCount,
  }) {
    if (!_isDeterministicTimelineQuery(
      input: input,
      forcedSurface: forcedSurface,
      matchedSurfaces: matchedSurfaces,
      category: category,
    )) {
      return null;
    }

    final TimelineEventEntity? nextUpcoming = timelineUpcomingEvents.isEmpty
        ? null
        : (List<TimelineEventEntity>.from(timelineUpcomingEvents)..sort(
                (a, b) =>
                    (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp),
              ))
              .first;

    final TimelineEventEntity? recentMilestone = timelineEvents
        .where((TimelineEventEntity event) => event.isMilestone)
        .fold<TimelineEventEntity?>(null, (
          TimelineEventEntity? acc,
          TimelineEventEntity event,
        ) {
          if (acc == null) {
            return event;
          }
          final DateTime a = acc.dueAt ?? acc.timestamp;
          final DateTime b = event.dueAt ?? event.timestamp;
          return b.isAfter(a) ? event : acc;
        });

    final String trackState =
        timelineHealthScore >= 75 && timelineOverdueCount == 0
        ? 'On Track'
        : timelineHealthScore >= 55
        ? 'Watchlist'
        : 'At Risk';
    final String nextDeadlineText = nextUpcoming == null
        ? 'No upcoming deadline found in timeline data.'
        : '${nextUpcoming.title} (${(nextUpcoming.dueAt ?? nextUpcoming.timestamp).toLocal().toIso8601String().split('T').first})';
    final String milestoneText = recentMilestone == null
        ? 'No milestone event recorded yet.'
        : '${recentMilestone.shortLabel}: ${recentMilestone.title}';

    final String output =
        'SI ANALYSIS\n\n'
        'Query: Timeline Deterministic Response\n\n'
        'Current State:\n'
        '- Health: $timelineHealthScore%\n'
        '- Risk: $timelineRiskScore%\n'
        '- On-track state: $trackState\n'
        '- Overdue items: $timelineOverdueCount\n'
        '- Upcoming items: $timelineUpcomingCount\n'
        '- Risk events: $timelineRiskEventsCount\n'
        '- Recommendations: $timelineRecommendationCount\n'
        '- Next deadline: $nextDeadlineText\n'
        '- Latest milestone: $milestoneText\n\n'
        'Priority Task: Recover one overdue item or execute the nearest deadline now.\n'
        'Impact: ${timelineOverdueCount > 0 ? 'High' : 'Medium'}\n'
        'Timeline Effect: Deterministic timeline signals used for overdue, upcoming, and on-track judgement.\n\n'
        'Next Actions:\n'
        '1. ${timelineOverdueCount > 0 ? 'Close one overdue item today.' : 'Protect timeline by completing the next deadline item.'}\n'
        '2. ${timelineUpcomingCount > 0 ? 'Pre-plan the next upcoming deadline block.' : 'Create one upcoming deadline anchor.'}\n'
        '3. ${timelineRiskEventsCount > 0 ? 'Apply one timeline recommendation to reduce risk.' : 'Record a milestone after completion to keep timeline fidelity high.'}\n\n'
        'Confidence: 94%';

    return AIRecommendation(
      message: output,
      reasoning: 'si_console_timeline_deterministic',
      emotion: 'focused',
      confidence: 0.94,
    );
  }

  bool _isDeterministicTimelineQuery({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
  }) {
    final String lowered = input.toLowerCase();
    bool hasAny(List<String> values) => values.any(lowered.contains);

    final bool forcedTimeline = forcedSurface == 'timeline';
    final bool categoryTimeline = category == 'Timeline Query';
    final bool surfaceTimeline = matchedSurfaces.contains('timeline');
    final bool asksTimelineOps = hasAny(<String>[
      'overdue',
      'what is next',
      'next deadline',
      'next milestone',
      'on track',
      'am i on track',
      'timeline health',
      'timeline risk',
    ]);

    return forcedTimeline ||
        categoryTimeline ||
        (surfaceTimeline && asksTimelineOps);
  }

  AIRecommendation? _tryDeterministicTrajectoryResponse({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
    required int pressure,
    required double momentum,
    required int divergence,
    required String? prediction,
    required String? alert,
  }) {
    if (!_isDeterministicTrajectoryQuery(
      input: input,
      forcedSurface: forcedSurface,
      matchedSurfaces: matchedSurfaces,
      category: category,
    )) {
      return null;
    }

    final int momentumPct = (momentum * 100).round();
    final String safePrediction =
        (prediction == null || prediction.trim().isEmpty)
        ? 'No prediction available.'
        : prediction;
    final String safeAlert = (alert == null || alert.trim().isEmpty)
        ? 'No active alert.'
        : alert;
    final String trackState =
        pressure <= 45 && divergence <= 25 && momentum >= 0.70
        ? 'On Track'
        : pressure <= 70 && divergence <= 45 && momentum >= 0.45
        ? 'Watchlist'
        : 'At Risk';
    final String impact = pressure >= 75 || divergence >= 55 || momentum <= 0.35
        ? 'High'
        : pressure >= 55 || divergence >= 35 || momentum <= 0.55
        ? 'Medium'
        : 'Low';

    final String nextAction1 = pressure >= 70
        ? 'Drop one low-impact commitment and protect one critical execution block.'
        : 'Keep current plan scope and execute the highest-impact block first.';
    final String nextAction2 = divergence >= 45
        ? 'Realign today with your top goal and remove one off-track task.'
        : 'Reinforce alignment by completing one goal-linked task now.';
    final String nextAction3 = momentum <= 0.45
        ? 'Trigger momentum recovery with one fast, definitive completion in the next hour.'
        : 'Maintain momentum with a second focused completion before context switching.';

    final String output =
        'SI ANALYSIS\n\n'
        'Query: Trajectory Deterministic Response\n\n'
        'Current State:\n'
        '- Pressure: $pressure\n'
        '- Momentum: $momentumPct%\n'
        '- Divergence: $divergence%\n'
        '- Prediction: $safePrediction\n'
        '- Alert: $safeAlert\n'
        '- On-track state: $trackState\n\n'
        'Priority Task: Execute one goal-aligned high-impact block now.\n'
        'Impact: $impact\n'
        'Timeline Effect: Deterministic trajectory signals used for pressure, momentum, divergence, and on-track judgement.\n\n'
        'Next Actions:\n'
        '1. $nextAction1\n'
        '2. $nextAction2\n'
        '3. $nextAction3\n\n'
        'Confidence: 93%';

    return AIRecommendation(
      message: output,
      reasoning: 'si_console_trajectory_deterministic',
      emotion: 'focused',
      confidence: 0.93,
    );
  }

  bool _isDeterministicTrajectoryQuery({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
  }) {
    final String lowered = input.toLowerCase();
    bool hasAny(List<String> values) => values.any(lowered.contains);

    final bool forcedTrajectory = forcedSurface == 'trajectory';
    final bool surfaceTrajectory = matchedSurfaces.contains('trajectory');
    final bool categoryTrajectory =
        category == 'Analytics Query' || category == 'Progress Query';
    final bool asksTrajectoryOps = hasAny(<String>[
      'pressure',
      'momentum',
      'divergence',
      'prediction',
      'trajectory',
      'am i on track',
      'on track',
      'how am i doing',
    ]);

    return forcedTrajectory ||
        surfaceTrajectory ||
        (categoryTrajectory && asksTrajectoryOps);
  }

  AIRecommendation? _tryDeterministicMilestoneResponse({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
    required MilestoneSummary summary,
    required List<MilestoneEntity> milestones,
    required List<MilestoneRisk> risks,
    required List<MilestoneEntity> overdue,
    required List<MilestoneEntity> upcoming,
  }) {
    if (!_isDeterministicMilestoneQuery(
      input: input,
      forcedSurface: forcedSurface,
      matchedSurfaces: matchedSurfaces,
      category: category,
    )) {
      return null;
    }

    final String topMilestones = milestones
        .take(3)
        .map((MilestoneEntity m) => m.title)
        .join(' | ');
    final String overdueNames = overdue
        .take(3)
        .map((MilestoneEntity m) => m.title)
        .join(' | ');
    final String upcomingNames = upcoming
        .take(3)
        .map((MilestoneEntity m) => m.title)
        .join(' | ');
    final String topRisk = risks.isEmpty
        ? 'No critical risk detected.'
        : '${risks.first.milestone.title}: ${risks.first.reason}';
    final String trackState = summary.healthScore >= 75 && summary.overdue == 0
        ? 'On Track'
        : summary.healthScore >= 55
        ? 'Watchlist'
        : 'At Risk';

    final String output =
        'SI ANALYSIS\n\n'
        'Query: Milestone Deterministic Response\n\n'
        'Current State:\n'
        '- Total milestones: ${summary.total}\n'
        '- Active: ${summary.active}\n'
        '- Completed: ${summary.completed}\n'
        '- Overdue: ${summary.overdue}\n'
        '- Upcoming: ${summary.upcoming}\n'
        '- Milestone Health: ${summary.healthScore}%\n'
        '- Milestone Momentum: ${summary.momentumScore}%\n'
        '- Milestone Risk: ${summary.riskScore}%\n'
        '- On-track state: $trackState\n'
        '- Next milestone: ${summary.nextMilestone?.title ?? 'No upcoming milestone'}\n'
        '- Closest milestone: ${summary.closestMilestone?.title ?? 'No milestone'}\n'
        '- Highest priority milestone: ${summary.highestPriority?.title ?? 'No milestone'}\n'
        '- Top risk: $topRisk\n\n'
        'Priority Task: Advance the highest-priority active milestone this week.\n'
        'Impact: ${summary.overdue > 0 ? 'High' : 'Medium'}\n'
        'Timeline Effect: Milestones bridge goals to daily execution and improve forecast reliability.\n\n'
        'Next Actions:\n'
        '1. ${summary.overdue > 0 ? 'Recover one overdue milestone immediately.' : 'Move the next milestone forward today.'}\n'
        '2. ${summary.highestPriority == null ? 'Create one high-priority milestone.' : 'Block execution time for ${summary.highestPriority!.title}.'}\n'
        '3. ${risks.isEmpty ? 'Record progress updates to maintain milestone momentum.' : 'Apply risk recommendation: ${risks.first.recommendation}'}\n\n'
        'Milestones: ${topMilestones.isEmpty ? 'None yet.' : topMilestones}\n'
        'Overdue list: ${overdueNames.isEmpty ? 'None' : overdueNames}\n'
        'Upcoming list: ${upcomingNames.isEmpty ? 'None' : upcomingNames}\n\n'
        'Confidence: 94%';

    return AIRecommendation(
      message: output,
      reasoning: 'si_console_milestone_deterministic',
      emotion: 'focused',
      confidence: 0.94,
    );
  }

  bool _isDeterministicMilestoneQuery({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
  }) {
    final String lowered = input.toLowerCase();
    bool hasAny(List<String> values) => values.any(lowered.contains);

    final bool forcedMilestones = forcedSurface == 'milestones';
    final bool surfaceMilestones = matchedSurfaces.contains('milestones');
    final bool categoryMilestones = category == 'Milestone Query';
    final bool asksMilestoneOps = hasAny(<String>[
      'milestone',
      'milestones',
      'checkpoint',
      'milestone risk',
      'milestone health',
      'closest milestone',
      'next milestone',
      'completed milestones',
      'upcoming milestones',
      'overdue milestones',
    ]);

    return forcedMilestones ||
        surfaceMilestones ||
        (categoryMilestones && asksMilestoneOps);
  }

  AIRecommendation? _tryDeterministicCoreValuesResponse({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
    required CoreValuesAlignment alignment,
  }) {
    if (!_isDeterministicCoreValuesQuery(
      input: input,
      forcedSurface: forcedSurface,
      matchedSurfaces: matchedSurfaces,
      category: category,
    )) {
      return null;
    }

    final List<String> rows = CoreValueType.values
        .map(
          (CoreValueType value) =>
              '- ${coreValueTitle(value)}: ${alignment.scores[value]?.score ?? 0}%',
        )
        .toList(growable: false);
    final String strongest = coreValueTitle(alignment.strongest);
    final String neglected = coreValueTitle(alignment.mostNeglected);

    final String output =
        'SI ANALYSIS\n\n'
        'Query: Core Values Alignment\n\n'
        'Current State:\n'
        '${rows.join('\n')}\n\n'
        '- Overall alignment: ${alignment.overall}%\n'
        '- Strongest value: $strongest\n'
        '- Most neglected value: $neglected\n\n'
        'Priority Task: Execute one action that increases $neglected this week.\n'
        'Impact: ${alignment.overall >= 70 ? 'Medium' : 'High'}\n'
        'Timeline Effect: Core values alignment acts as your internal compass for decision quality.\n\n'
        'Next Actions:\n'
        '1. ${alignment.recommendations.firstWhere((String item) => item.toLowerCase().contains('schedule one action'), orElse: () => 'Schedule one action this week aligned to the neglected value.')}\n'
        '2. Use the guiding question for $neglected before your next major decision.\n'
        '3. Preserve momentum in $strongest while reducing the gap in $neglected.\n\n'
        'Confidence: 95%';

    return AIRecommendation(
      message: output,
      reasoning: 'si_console_core_values_deterministic',
      emotion: 'focused',
      confidence: 0.95,
    );
  }

  bool _isDeterministicCoreValuesQuery({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
  }) {
    final String lowered = input.toLowerCase();
    bool hasAny(List<String> values) => values.any(lowered.contains);

    final bool forced = forcedSurface == 'values';
    final bool surface = matchedSurfaces.contains('values');
    final bool categoryMatch =
        category == 'Core Values Query' || category == 'Life Query';
    final bool asks = hasAny(<String>[
      'core values',
      'values alignment',
      'most neglected value',
    ]);

    return forced || surface || (categoryMatch && asks);
  }

  AIRecommendation? _tryDeterministicSoulMapResponse({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
    required SoulMapAlignment alignment,
    required SoulMapFutureSelfComparison comparison,
  }) {
    if (!_isDeterministicSoulMapQuery(
      input: input,
      forcedSurface: forcedSurface,
      matchedSurfaces: matchedSurfaces,
      category: category,
    )) {
      return null;
    }

    final int purpose = alignment.scores[SoulMapDimension.purpose]?.score ?? 0;
    final int identity =
        alignment.scores[SoulMapDimension.identity]?.score ?? 0;
    final int values =
        alignment.scores[SoulMapDimension.coreValues]?.score ?? 0;
    final int futureSelf =
        alignment.scores[SoulMapDimension.futureSelf]?.score ?? 0;
    final String strongest = soulMapDimensionTitle(alignment.strongest);
    final String weakest = soulMapDimensionTitle(alignment.weakest);
    final String recommendation = alignment.recommendations.firstWhere(
      (String item) =>
          item.toLowerCase().contains('schedule one concrete action'),
      orElse: () =>
          'Schedule one concrete action this week to strengthen $weakest.',
    );
    final String lowered = input.toLowerCase();
    final bool compareMode =
        lowered.contains('compare') || lowered.contains('current self');

    if (compareMode) {
      final String compareOutput =
          'SI ANALYSIS\n\n'
          'Query: SoulMap Current vs Future Self\n\n'
          'Current State:\n'
          '- Current Self Alignment: ${comparison.currentSelfAlignment}%\n'
          '- Future Self Readiness: ${comparison.futureSelfReadiness}%\n'
          '- Gap: ${comparison.gap}%\n'
          '- Stance: ${comparison.stance}\n\n'
          'Priority Task: Execute one action today that directly reduces the future-self gap.\n'
          'Impact: ${comparison.gap > 20 ? 'High' : 'Medium'}\n'
          'Timeline Effect: Gap reduction compounds identity consistency over 1/5/10 year horizons.\n\n'
          'Next Actions:\n'
          '1. ${comparison.recommendation}\n'
          '2. Define one 1-year and one 5-year future-self outcome in SoulMap profile.\n'
          '3. Audit your current top goal for alignment before quitting or recommitting.\n\n'
          'Confidence: 95%';

      return AIRecommendation(
        message: compareOutput,
        reasoning: 'si_console_soulmap_compare_deterministic',
        emotion: 'focused',
        confidence: 0.95,
      );
    }

    final String output =
        'SI ANALYSIS\n\n'
        'Query: SoulMap Analysis\n\n'
        'Current State:\n'
        '- Purpose Alignment: $purpose%\n'
        '- Identity Alignment: $identity%\n'
        '- Values Alignment: $values%\n'
        '- Future Self Progress: $futureSelf%\n'
        '- Overall SoulMap: ${alignment.overall}%\n'
        '- Strongest Area: $strongest\n'
        '- Weakest Area: $weakest\n\n'
        'Priority Task: Execute one decision today that strengthens $weakest.\n'
        'Impact: ${alignment.overall >= 70 ? 'Medium' : 'High'}\n'
        'Timeline Effect: SoulMap aligns goals, values, and identity into one life direction compass.\n\n'
        'Next Actions:\n'
        '1. $recommendation\n'
        '2. Test one active goal against your Future Self before committing or quitting.\n'
        '3. Protect your strongest area ($strongest) while repairing $weakest.\n\n'
        'Confidence: 95%';

    return AIRecommendation(
      message: output,
      reasoning: 'si_console_soulmap_deterministic',
      emotion: 'focused',
      confidence: 0.95,
    );
  }

  bool _isDeterministicSoulMapQuery({
    required String input,
    required String? forcedSurface,
    required List<String> matchedSurfaces,
    required String category,
  }) {
    final String lowered = input.toLowerCase();
    bool hasAny(List<String> values) => values.any(lowered.contains);

    final bool forced = forcedSurface == 'soulmap';
    final bool surface = matchedSurfaces.contains('soulmap');
    final bool categoryMatch = category == 'Life Query';
    final bool asks = hasAny(<String>[
      'analyze my life',
      'compare current self to future self',
      'current self vs future self',
      'soul map',
      'soulmap',
      'who am i becoming',
      'future self',
      'life direction',
      'legacy',
      'what kind of life',
    ]);

    return forced || surface || (categoryMatch && asks);
  }

  AIRecommendation _buildStructuredSIFallback({
    required String query,
    required String category,
    required List<TaskEntity> tasks,
    required int goalsCount,
    required int timelineOverdueCount,
    required int timelineUpcomingCount,
    required int timelineHealthScore,
    required int timelineRiskScore,
  }) {
    final int openTasks = tasks.length;
    final DateTime now = DateTime.now();
    final int overdueFromTasks = tasks
        .where(
          (TaskEntity task) =>
              task.scheduledFor != null && task.scheduledFor!.isBefore(now),
        )
        .length;
    final int overdue = category == 'Timeline Query'
        ? timelineOverdueCount
        : overdueFromTasks;

    final TaskEntity? topTask = tasks.isEmpty ? null : tasks.first;
    final int taskPriority = topTask?.priority ?? 0;
    final String impact = taskPriority >= 4
        ? 'High'
        : taskPriority >= 2
        ? 'Medium'
        : 'Low';

    final String priorityTask = topTask?.title ?? 'No priority task available';
    final List<String> nextActions = <String>[];
    if (topTask != null) {
      nextActions.add(topTask.title);
    }
    nextActions.addAll(
      tasks
          .skip(topTask == null ? 0 : 1)
          .take(2)
          .map((TaskEntity task) => task.title),
    );
    while (nextActions.length < 3) {
      nextActions.add(
        nextActions.length == 1
            ? 'Review goals'
            : nextActions.length == 2
            ? 'Check timeline risks'
            : 'Create next task',
      );
    }

    final String timelineEffect = switch (category) {
      'Goal Query' => 'Keeps core goals on measurable milestones.',
      'Milestone Query' =>
        'Improves checkpoint clarity with milestone health $timelineHealthScore% and risk $timelineRiskScore% context.',
      'Core Values Query' =>
        'Aligns execution decisions with your personal operating system and neglected value recovery.',
      'Timeline Query' =>
        overdue > 0
            ? 'Reduces delay risk by addressing overdue work first (health $timelineHealthScore%, risk $timelineRiskScore%).'
            : 'Maintains schedule stability with no overdue drift (health $timelineHealthScore%, upcoming $timelineUpcomingCount).',
      'Progress Query' => 'Improves completion momentum over the next cycle.',
      'Memory Query' => 'Prevents context loss and repeated mistakes.',
      'Life Query' => 'Aligns daily execution with long-term direction.',
      _ => 'Keeps current execution aligned with active priorities.',
    };

    final int confidence =
        (70 +
                (goalsCount > 0 ? 8 : 0) +
                (openTasks > 0 ? 8 : 0) +
                (overdue == 0 ? 6 : 0))
            .clamp(62, 96);
    final String output = AssistantResponseTemplates.siAnalysis(
      query: query,
      category: category,
      goalsCount: goalsCount,
      openTasks: openTasks,
      overdue: overdue,
      priorityTask: priorityTask,
      impact: impact,
      timelineEffect: timelineEffect,
      nextActions: nextActions,
      confidence: confidence,
    );

    return AIRecommendation(
      message: output,
      reasoning: 'si_console_structured_fallback',
      emotion: 'focused',
      confidence: confidence / 100,
    );
  }

  Map<String, dynamic> _responseContract(
    String primarySurface,
    List<String> matchedSurfaces,
  ) {
    return <String, dynamic>{
      'style': 'si_analysis_block',
      'sections': <String>[
        'query',
        'current_state',
        'priority_task',
        'impact',
        'timeline_effect',
        'next_actions',
        'confidence',
      ],
      'maxActions': 3,
      'primarySurface': primarySurface,
      'matchedSurfaces': matchedSurfaces,
      'grounding': 'featureSnapshot_only',
      'constraints': <String>[
        'Avoid generic motivational filler.',
        'Reference concrete app data when available.',
        'State uncertainty if data is missing.',
        'Prefer SI ANALYSIS response block formatting.',
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
    _captureSnapshot(
      SISnapshot(
        timestamp: DateTime.now(),
        energy: _ref.read(siStateProvider).energy,
        fatigue: _ref.read(siStateProvider).fatigue,
        completed: _ref.read(learningProvider).completed,
        skipped: _ref.read(learningProvider).skipped,
        reasoning: 'conversation_cleared',
        responseHash: 'clear_conversation',
        responseSummary: 'Conversation and transient SI history were reset.',
        actionKey: 'clear_conversation',
      ),
    );
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

  void _captureSnapshot(SISnapshot snapshot) {
    _ref.read(siMemoryProvider.notifier).capture(snapshot);
  }
}
