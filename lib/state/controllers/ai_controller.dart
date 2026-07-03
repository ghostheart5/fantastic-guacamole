import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/si_core.dart';
import 'package:fantastic_guacamole/engine/si/si_decision.dart';
import 'package:fantastic_guacamole/engine/si/synthetic_intelligence_engine.dart';
import 'package:fantastic_guacamole/features/paywall/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/paywall/services/credit_service.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiControllerProvider = Provider<AIController>((ref) => AIController(ref));

/// Synchronous next-step text derived from the highest-priority pending task.
final nextActionTextProvider = Provider<String>((ref) {
  final tasks = ref.watch(tasksProvider).asData?.value;
  if (tasks == null || tasks.isEmpty) {
    return 'Create your first task to get started.';
  }
  final sorted = [...tasks]..sort((a, b) => a.priority.compareTo(b.priority));
  return 'Focus on: ${sorted.first.title}';
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
  AIController(this._ref);

  final Ref _ref;
  static const String _neuralDumpKey = 'neural_dump';

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
    ref.read(notificationProvider.notifier).pushDecision(decision.task.title);
  }

  return decision;
});

final aiResponseProvider =
    AsyncNotifierProvider<AIResponseController, AIRecommendation?>(
      AIResponseController.new,
    );

class AIResponseController extends AsyncNotifier<AIRecommendation?> {
  static int _requestCounter = 0;

  @override
  Future<AIRecommendation?> build() async {
    return null;
  }

  Future<AIRecommendation?> execute({
    String? inputOverride,
    AIPersonality? personalityOverride,
  }) async {
    final int seq = ++_requestCounter;
    final String requestId = 'ai-${DateTime.now().millisecondsSinceEpoch}-$seq';
    final Stopwatch stopwatch = Stopwatch()..start();

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

      final AgentResult agentResult = await agentOrchestrator.execute(
        prompt: input ?? '',
        context: <String, dynamic>{
          'mode': 'coach',
          'previousMessage': previousState?['message']?.toString(),
          'requestId': requestId,
        },
        request: AgentRequest(
          prompt: input ?? '',
          context: <String, dynamic>{
            'mode': 'coach',
            'previousMessage': previousState?['message']?.toString(),
            'requestId': requestId,
          },
          tasks: tasks,
          si: si,
          learning: learning,
          personality: personality,
        ),
      );
      ref.read(aiAgentTraceProvider.notifier).set(agentResult);

      final AIResponse response = _responseFromAgentResult(agentResult, tasks);
      final AIRecommendation recommendation = AIRecommendation.fromResponse(
        response,
      );

      stopwatch.stop();

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
        'previousMessage': previousState?['message']?.toString(),
      });
      ref.invalidate(siEngineStateProvider);

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

AIResponse _responseFromAgentResult(AgentResult result, List<Task> tasks) {
  final Map<String, dynamic>? taskMap = result.taskMap;
  final Task? task = taskMap != null
      ? Task.fromJson(taskMap)
      : (tasks.isEmpty ? null : tasks.first);

  return AIResponse(
    task: task,
    message: result.message,
    reasoning: result.reasoning,
    emotion: result.emotion,
    confidence: result.confidence,
  );
}

final siOutputBundleProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final String input = ref.watch(aiInputProvider) ?? '';
  final AIPersonality personality = ref.watch(aiPersonalityProvider);
  final AIRecommendation? response = ref
      .watch(aiResponseProvider)
      .asData
      ?.value;

  final bundle = const SyntheticIntelligenceEngine().build(
    input: input,
    now: DateTime.now(),
    personality: personality,
    response: response,
    appState: 'coach',
    platform: 'flutter',
  );

  return bundle.toJson();
});
