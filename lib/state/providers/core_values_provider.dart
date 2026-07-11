import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/profile_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coreValuesAlignmentProvider = Provider<CoreValuesAlignment>((Ref ref) {
  final Set<String> selectedValues = ref.watch(profileValuesProvider);
  final int streak = ref.watch(profileProvider).streak;
  final siState = ref.watch(siStateProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final int timelineHealth = ref.watch(timelineHealthScoreProvider);
  final int timelineOverdue = ref.watch(timelineOverdueProvider).length;
  final MilestoneSummary milestoneSummary = ref.watch(milestoneSummaryProvider);
  final List<Task> tasks =
      ref.watch(tasksProvider).asData?.value ?? const <Task>[];
  final int goalsCount = ref.watch(goalsProvider).length;
  final int flowmapCount = ref.watch(flowmapProvider).asData?.value.length ?? 0;
  final List<MemoryEntity> memories = ref.watch(memoriesProvider);
  final EmotionalState emotion = ref.watch(emotionProvider);

  bool selected(CoreValueType value) =>
      selectedValues.contains(coreValueTitle(value));

  final int discipline =
      (38 +
              (streak * 4).clamp(0, 30) +
              (siState.completedToday * 7).clamp(0, 21) -
              ((timelineOverdue + milestoneSummary.overdue) * 5).clamp(0, 28) +
              (selected(CoreValueType.discipline) ? 6 : 0))
          .clamp(0, 100);

  final int growth =
      (36 +
              (goalsCount * 6).clamp(0, 24) +
              (milestoneSummary.completed * 4).clamp(0, 24) +
              (trajectory.momentum * 22).round().clamp(0, 22) +
              (selected(CoreValueType.growth) ? 6 : 0))
          .clamp(0, 100);

  final int clarity =
      (34 +
              ((timelineHealth * 0.32).round()).clamp(0, 32) +
              ((milestoneSummary.healthScore * 0.24).round()).clamp(0, 24) +
              (tasks.isNotEmpty ? 10 : 0) -
              (trajectory.pressureIndex ~/ 4) +
              (selected(CoreValueType.clarity) ? 6 : 0))
          .clamp(0, 100);

  final int resilience =
      (42 +
              ((100 - trajectory.pressureIndex) * 0.30).round().clamp(0, 30) +
              ((1 - siState.fatigue).clamp(0, 1) * 22).round().clamp(0, 22) -
              (_emotionPenalty(emotion)) +
              (selected(CoreValueType.resilience) ? 6 : 0))
          .clamp(0, 100);

  final int creativitySignals = memories.where((MemoryEntity memory) {
    final String lower = memory.text.toLowerCase();
    return lower.contains('create') ||
        lower.contains('write') ||
        lower.contains('design') ||
        lower.contains('build') ||
        lower.contains('idea');
  }).length;

  final int creativity =
      (28 +
              (flowmapCount * 5).clamp(0, 30) +
              (creativitySignals * 4).clamp(0, 24) +
              (selected(CoreValueType.creativity) ? 8 : 0))
          .clamp(0, 100);

  final int connectionSignals = memories.where((MemoryEntity memory) {
    final String lower = memory.text.toLowerCase();
    return lower.contains('family') ||
        lower.contains('friend') ||
        lower.contains('team') ||
        lower.contains('community') ||
        lower.contains('relationship');
  }).length;

  final int connection =
      (30 +
              (connectionSignals * 6).clamp(0, 36) +
              (selected(CoreValueType.connection) ? 10 : 0) +
              (emotion == EmotionalState.positive ||
                      emotion == EmotionalState.calm
                  ? 8
                  : 0))
          .clamp(0, 100);

  final int purpose =
      (34 +
              (goalsCount * 7).clamp(0, 28) +
              (milestoneSummary.active * 5).clamp(0, 25) +
              (trajectory.momentum * 18).round().clamp(0, 18) +
              (selected(CoreValueType.purpose) ? 10 : 0))
          .clamp(0, 100);

  final Map<CoreValueType, int> rawScores = <CoreValueType, int>{
    CoreValueType.discipline: discipline,
    CoreValueType.growth: growth,
    CoreValueType.clarity: clarity,
    CoreValueType.resilience: resilience,
    CoreValueType.creativity: creativity,
    CoreValueType.connection: connection,
    CoreValueType.purpose: purpose,
  };

  final Map<CoreValueType, CoreValueScore> scores =
      <CoreValueType, CoreValueScore>{};
  for (final CoreValueType type in CoreValueType.values) {
    final CoreValueDefinition definition = coreValueDefinitions[type]!;
    scores[type] = CoreValueScore(
      type: type,
      score: rawScores[type]!.clamp(0, 100),
      definition: definition.definition,
      guidingQuestion: definition.guidingQuestion,
      supports: definition.supports,
    );
  }

  final List<MapEntry<CoreValueType, CoreValueScore>> ordered =
      scores.entries.toList(growable: false)..sort(
        (
          MapEntry<CoreValueType, CoreValueScore> a,
          MapEntry<CoreValueType, CoreValueScore> b,
        ) => b.value.score.compareTo(a.value.score),
      );

  final int overall = ordered.isEmpty
      ? 0
      : (ordered
                    .map(
                      (MapEntry<CoreValueType, CoreValueScore> entry) =>
                          entry.value.score,
                    )
                    .reduce((int a, int b) => a + b) /
                ordered.length)
            .round();

  final CoreValueType strongest = ordered.first.key;
  final CoreValueType mostNeglected = ordered.last.key;
  final List<String> recommendations = <String>[
    'Strongest value: ${coreValueTitle(strongest)}.',
    'Most neglected value: ${coreValueTitle(mostNeglected)}.',
    'Schedule one action this week that directly improves ${coreValueTitle(mostNeglected)}.',
  ];

  return CoreValuesAlignment(
    scores: scores,
    overall: overall,
    strongest: strongest,
    mostNeglected: mostNeglected,
    recommendations: recommendations,
    selectedValues: selectedValues,
  );
});

int _emotionPenalty(EmotionalState emotion) {
  return switch (emotion) {
    EmotionalState.anxious => 12,
    EmotionalState.scattered => 10,
    EmotionalState.negative => 11,
    EmotionalState.fatigued => 9,
    _ => 0,
  };
}
