part of 'ai_controller.dart';

final aiTriggerProvider = NotifierProvider<AITriggerNotifier, int>(AITriggerNotifier.new);
final aiAgentTraceProvider = NotifierProvider<AIAgentTraceNotifier, AgentResult?>(
  AIAgentTraceNotifier.new,
);
final aiPersonalityProvider = NotifierProvider<AIPersonalityNotifier, AIPersonality>(
  AIPersonalityNotifier.new,
);
final aiInputProvider = NotifierProvider<AIInputNotifier, String?>(AIInputNotifier.new);
final aiExecutionStatusProvider = NotifierProvider<AIExecutionStatusNotifier, AIExecutionStatus>(
  AIExecutionStatusNotifier.new,
);
final aiMessageThrottleProvider = Provider<Throttle>((_) {
  return Throttle(const Duration(milliseconds: 900));
});
final aiSuggestionRateLimiterProvider = Provider<SlidingWindowRateLimiter>((_) {
  return SlidingWindowRateLimiter(maxRequests: 3, window: const Duration(seconds: 20));
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
  const AIExecutionStatus({required this.phase, this.requestId, this.durationMs, this.error});

  const AIExecutionStatus.idle()
    : this(phase: 'idle', requestId: null, durationMs: null, error: null);

  final String phase;
  final String? requestId;
  final int? durationMs;
  final String? error;

  AIExecutionStatus copyWith({String? phase, String? requestId, int? durationMs, String? error}) {
    return AIExecutionStatus(
      phase: phase ?? this.phase,
      requestId: requestId ?? this.requestId,
      durationMs: durationMs ?? this.durationMs,
      error: error,
    );
  }
}
