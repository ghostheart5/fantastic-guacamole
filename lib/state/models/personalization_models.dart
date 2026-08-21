enum PlanningStyle { flexible, timeBlocked, energyMatched, singleTask }

enum PriorityStrategy {
  balanced,
  deadlineFirst,
  energyFirst,
  goalFirst,
  quickWins,
}

enum RecoveryPolicy { askFirst, reschedule, reduceScope, recoveryQueue }

enum RecommendationMode { onDemand, gentle, proactive }

enum ExplanationDepth { brief, standard, detailed }

/// Explicit choices the user makes about how ChronoSpark should guide them.
/// This is deliberately separate from inferred behaviour so a guess can never
/// silently override a user preference.
class PersonalizationProfile {
  const PersonalizationProfile({
    this.version = 1,
    this.goalCategory = '',
    this.planningStyle = PlanningStyle.flexible,
    this.priorityStrategy = PriorityStrategy.balanced,
    this.recoveryPolicy = RecoveryPolicy.askFirst,
    this.recommendationMode = RecommendationMode.gentle,
    this.explanationDepth = ExplanationDepth.standard,
    this.useEmotionSignals = true,
    this.useMemoryContext = false,
    this.externalAiAllowed = false,
    this.lastReviewedAt,
  });

  final int version;
  final String goalCategory;
  final PlanningStyle planningStyle;
  final PriorityStrategy priorityStrategy;
  final RecoveryPolicy recoveryPolicy;
  final RecommendationMode recommendationMode;
  final ExplanationDepth explanationDepth;
  final bool useEmotionSignals;
  final bool useMemoryContext;
  final bool externalAiAllowed;
  final DateTime? lastReviewedAt;

  PersonalizationProfile copyWith({
    String? goalCategory,
    PlanningStyle? planningStyle,
    PriorityStrategy? priorityStrategy,
    RecoveryPolicy? recoveryPolicy,
    RecommendationMode? recommendationMode,
    ExplanationDepth? explanationDepth,
    bool? useEmotionSignals,
    bool? useMemoryContext,
    bool? externalAiAllowed,
    DateTime? lastReviewedAt,
  }) => PersonalizationProfile(
    version: version,
    goalCategory: goalCategory ?? this.goalCategory,
    planningStyle: planningStyle ?? this.planningStyle,
    priorityStrategy: priorityStrategy ?? this.priorityStrategy,
    recoveryPolicy: recoveryPolicy ?? this.recoveryPolicy,
    recommendationMode: recommendationMode ?? this.recommendationMode,
    explanationDepth: explanationDepth ?? this.explanationDepth,
    useEmotionSignals: useEmotionSignals ?? this.useEmotionSignals,
    useMemoryContext: useMemoryContext ?? this.useMemoryContext,
    externalAiAllowed: externalAiAllowed ?? this.externalAiAllowed,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'goalCategory': goalCategory,
    'planningStyle': planningStyle.name,
    'priorityStrategy': priorityStrategy.name,
    'recoveryPolicy': recoveryPolicy.name,
    'recommendationMode': recommendationMode.name,
    'explanationDepth': explanationDepth.name,
    'useEmotionSignals': useEmotionSignals,
    'useMemoryContext': useMemoryContext,
    'externalAiAllowed': externalAiAllowed,
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
  };

  factory PersonalizationProfile.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String? raw, T fallback) {
      return values.firstWhere(
        (T value) => value.name == raw,
        orElse: () => fallback,
      );
    }

    return PersonalizationProfile(
      version: (json['version'] as num?)?.toInt() ?? 1,
      goalCategory: (json['goalCategory'] as String?)?.trim() ?? '',
      planningStyle: enumValue(
        PlanningStyle.values,
        json['planningStyle']?.toString(),
        PlanningStyle.flexible,
      ),
      priorityStrategy: enumValue(
        PriorityStrategy.values,
        json['priorityStrategy']?.toString(),
        PriorityStrategy.balanced,
      ),
      recoveryPolicy: enumValue(
        RecoveryPolicy.values,
        json['recoveryPolicy']?.toString(),
        RecoveryPolicy.askFirst,
      ),
      recommendationMode: enumValue(
        RecommendationMode.values,
        json['recommendationMode']?.toString(),
        RecommendationMode.gentle,
      ),
      explanationDepth: enumValue(
        ExplanationDepth.values,
        json['explanationDepth']?.toString(),
        ExplanationDepth.standard,
      ),
      useEmotionSignals: json['useEmotionSignals'] as bool? ?? true,
      useMemoryContext: json['useMemoryContext'] as bool? ?? false,
      externalAiAllowed: json['externalAiAllowed'] as bool? ?? false,
      lastReviewedAt: DateTime.tryParse(
        json['lastReviewedAt']?.toString() ?? '',
      ),
    );
  }
}

/// Lightweight, non-sensitive evidence used to tune defaults over time.
class ObservedPlanningPatterns {
  const ObservedPlanningPatterns({
    this.version = 1,
    this.completed = 0,
    this.skipped = 0,
    this.shortTaskCompletions = 0,
    this.deepTaskCompletions = 0,
    this.lastUpdatedAt,
  });

  final int version;
  final int completed;
  final int skipped;
  final int shortTaskCompletions;
  final int deepTaskCompletions;
  final DateTime? lastUpdatedAt;

  double get completionRate {
    final int attempts = completed + skipped;
    return attempts == 0 ? 0 : completed / attempts;
  }

  ObservedPlanningPatterns copyWith({
    int? completed,
    int? skipped,
    int? shortTaskCompletions,
    int? deepTaskCompletions,
    DateTime? lastUpdatedAt,
  }) => ObservedPlanningPatterns(
    version: version,
    completed: completed ?? this.completed,
    skipped: skipped ?? this.skipped,
    shortTaskCompletions: shortTaskCompletions ?? this.shortTaskCompletions,
    deepTaskCompletions: deepTaskCompletions ?? this.deepTaskCompletions,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'completed': completed,
    'skipped': skipped,
    'shortTaskCompletions': shortTaskCompletions,
    'deepTaskCompletions': deepTaskCompletions,
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
  };

  factory ObservedPlanningPatterns.fromJson(
    Map<String, dynamic> json,
  ) => ObservedPlanningPatterns(
    version: (json['version'] as num?)?.toInt() ?? 1,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    skipped: (json['skipped'] as num?)?.toInt() ?? 0,
    shortTaskCompletions: (json['shortTaskCompletions'] as num?)?.toInt() ?? 0,
    deepTaskCompletions: (json['deepTaskCompletions'] as num?)?.toInt() ?? 0,
    lastUpdatedAt: DateTime.tryParse(json['lastUpdatedAt']?.toString() ?? ''),
  );
}

class PersonalizationDecision {
  const PersonalizationDecision({
    required this.surface,
    required this.explanation,
    required this.signalsUsed,
    this.confidence = 0,
  });

  final String surface;
  final String explanation;
  final List<String> signalsUsed;
  final double confidence;
}
