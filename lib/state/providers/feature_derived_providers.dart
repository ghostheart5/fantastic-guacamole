import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/usecases/get_progress_signals.dart';
import 'package:fantastic_guacamole/engine/si/offline/narrative_engine.dart';
import 'package:fantastic_guacamole/engine/si/offline/user_growth_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_soul_layer.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userGrowthProvider = Provider<UserGrowthState>((ref) {
  final profile = ref.watch(profileProvider);
  final traj = ref.watch(trajectorySummaryProvider);
  final double consistency = traj.momentum > 0.6
      ? 0.9
      : traj.momentum > 0.3
      ? 0.6
      : 0.3;

  return const UserGrowthEngine().update(
    const UserGrowthState(),
    completedTasks: profile.xp ~/ 10,
    streak: profile.streak,
    consistency: consistency,
  );
});

final userGrowthTitleProvider = Provider<String>((ref) {
  final UserGrowthState growth = ref.watch(userGrowthProvider);
  return const UserGrowthEngine().growthTitle(growth);
});

final progressSignalsProvider = Provider<ProgressSignals>((ref) {
  final traj = ref.watch(trajectorySummaryProvider);
  return GetProgressSignals()(traj);
});

final narrativeProvider = Provider<UserNarrative>((ref) {
  final profile = ref.watch(profileProvider);
  final signals = ref.watch(progressSignalsProvider);
  final double consistency = signals.consistency.startsWith('High')
      ? 0.9
      : signals.consistency.startsWith('Med')
      ? 0.6
      : 0.3;

  return const NarrativeEngine().generate(
    streak: profile.streak,
    completedTasks: profile.xp ~/ 10,
    consistency: consistency,
  );
});

final soulStateProvider = Provider<SoulState>((ref) {
  final si = ref.watch(siStateProvider);
  final traj = ref.watch(trajectorySummaryProvider);
  final emotion = ref.watch(emotionProvider);
  final insightsBundle = ref.watch(insightsBundleProvider);
  final logsState = ref.watch(logsProvider);
  final List<MemoryEntity> memories = ref.watch(memoriesProvider);
  final List<TimelineEventEntity> timelineEvents = ref.watch(timelineProvider);
  final List<FlowmapNode> flowNodes = ref
      .watch(flowmapProvider)
      .maybeWhen(
        data: (List<FlowmapNode> nodes) => nodes,
        orElse: () => const <FlowmapNode>[],
      );
  final String mood =
      emotion == EmotionalState.anxious ||
          emotion == EmotionalState.fatigued ||
          emotion == EmotionalState.scattered
      ? 'stressed'
      : 'neutral';

  final int nodeCount = flowNodes.length;
  final int describedCount = flowNodes
      .where(
        (FlowmapNode node) => (node.description?.trim().isNotEmpty ?? false),
      )
      .length;
  final int taggedCount = flowNodes
      .where((FlowmapNode node) => node.tags.isNotEmpty)
      .length;
  final int connectedCount = flowNodes
      .where((FlowmapNode node) => node.connectedTo.isNotEmpty)
      .length;
  final int memoryCount = memories.length;
  final int recentMemoryCount = memories
      .where((MemoryEntity memory) => memory.isRecent)
      .length;
  final int starredMemoryCount = memories
      .where((MemoryEntity memory) => memory.starred)
      .length;
  final int insightCount = insightsBundle.items.length;
  final int recentLogCount = logsState.entries
      .where((LogEntryEntity entry) => entry.isRecent)
      .length;
  final int logSourceCount = logsState.entries
      .map((entry) => entry.source)
      .toSet()
      .length;
  final int recentTimelineCount = timelineEvents
      .where((event) => event.isRecent)
      .length;
  final int milestoneTimelineCount = timelineEvents
      .where(
        (TimelineEventEntity event) =>
            event.isGoalComplete || event.isLevelUp || event.isStreak,
      )
      .length;
  final double mapDensity = nodeCount == 0
      ? 0.0
      : ((describedCount + taggedCount + connectedCount) / (nodeCount * 3))
            .clamp(0.0, 1.0);
  final double flowPresenceBoost = (nodeCount * 0.035).clamp(0.0, 0.18);
  final double flowEmergenceBoost = ((nodeCount * 0.02) + (mapDensity * 0.16))
      .clamp(0.0, 0.22);
  final bool hasFlowNarrative = nodeCount >= 3 || connectedCount > 0;
  final double memoryPresenceBoost = (memoryCount * 0.012).clamp(0.0, 0.10);
  final double memoryEmergenceBoost =
      ((recentMemoryCount * 0.018) + (starredMemoryCount * 0.02)).clamp(
        0.0,
        0.14,
      );
  final bool hasMemoryNarrative =
      recentMemoryCount > 0 || starredMemoryCount > 0;
  final double insightPresenceBoost =
      ((insightCount * 0.015) + (insightsBundle.healthScore * 0.04)).clamp(
        0.0,
        0.12,
      );
  final double insightEmergenceBoost =
      ((insightCount * 0.02) + (insightsBundle.healthScore * 0.05)).clamp(
        0.0,
        0.16,
      );
  final bool hasInsightNarrative = insightCount > 0;
  final double timelinePresenceBoost = (recentTimelineCount * 0.015).clamp(
    0.0,
    0.10,
  );
  final double timelineEmergenceBoost =
      ((milestoneTimelineCount * 0.025) + (recentTimelineCount * 0.01)).clamp(
        0.0,
        0.16,
      );
  final bool hasTimelineNarrative =
      milestoneTimelineCount > 0 || recentTimelineCount >= 3;
  final double logPresenceBoost = (recentLogCount * 0.01).clamp(0.0, 0.08);
  final double logEmergenceBoost =
      ((logSourceCount * 0.015) + (recentLogCount * 0.008)).clamp(0.0, 0.12);
  final bool hasLogNarrative = recentLogCount > 0 || logSourceCount >= 2;

  return const SyntheticSoulLayer().harmonize(
    presence:
        (si.energy +
                flowPresenceBoost +
                memoryPresenceBoost +
                insightPresenceBoost +
                timelinePresenceBoost +
                logPresenceBoost)
            .clamp(0.0, 1.0),
    emergence:
        (traj.momentum +
                flowEmergenceBoost +
                memoryEmergenceBoost +
                insightEmergenceBoost +
                timelineEmergenceBoost +
                logEmergenceBoost)
            .clamp(0.0, 1.0),
    mood: mood,
    hasNarrative:
        traj.completedTasks > 0 ||
        hasFlowNarrative ||
        hasMemoryNarrative ||
        hasInsightNarrative ||
        hasTimelineNarrative ||
        hasLogNarrative,
  );
});
