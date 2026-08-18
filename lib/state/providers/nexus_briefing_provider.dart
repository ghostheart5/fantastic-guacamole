import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_record.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_briefing_model.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_console_message.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/creator_creation_receipt.dart';
import 'package:fantastic_guacamole/state/providers/creator_receipt_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_command_briefing_provider.dart';
import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_console_thread_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nexusBriefingProvider = Provider<NexusBriefingModel>((Ref ref) {
  final AsyncValue<OperatingBriefing> briefingAsync = ref.watch(
    operatingBriefingProvider,
  );
  final AsyncValue<NexusScreenModel> screenAsync = ref.watch(
    nexusScreenModelProvider,
  );
  final AsyncValue<List<HabitRecord>> habitsAsync = ref.watch(habitsProvider);
  final AsyncValue<List<NoteEntity>> notesAsync = ref.watch(notesProvider);
  final AsyncValue<CreatorCreationReceipt?> creatorReceiptAsync = ref.watch(
    latestCreatorReceiptProvider,
  );
  final AsyncValue<List<SIConsoleMessage>> siThreadAsync = ref.watch(
    siConsoleThreadProvider,
  );
  final progression = ref.watch(progressionProvider);
  final ProgressionIntelligence progressionIntelligence = ref.watch(
    progressionIntelligenceProvider,
  );
  final DailyCommandBriefing dailyBriefing = ref.watch(
    dailyCommandBriefingProvider,
  );
  final ExplainableSIState explainableSI = ref.watch(explainableSIProvider);
  final FutureDecision futureDecision = ref.watch(futureDecisionEngineProvider);
  final bool isOnline = ref.watch(isOnlineProvider);
  final AsyncValue<int> pendingSyncAsync = ref.watch(offlineQueueCountProvider);
  final String? syncError = ref.watch(syncErrorMessageProvider);

  // Riverpod can retain a previous value while a dependency refreshes. Nexus
  // must never present that previous account/scope as current command state.
  final OperatingBriefing? briefing = briefingAsync.isLoading
      ? null
      : briefingAsync.asData?.value;
  final NexusScreenModel? screen = screenAsync.isLoading
      ? null
      : screenAsync.asData?.value;
  final int pendingSyncCount = pendingSyncAsync.asData?.value ?? 0;
  final List<String> failures = <String>[
    if (briefingAsync.hasError) 'Your planning summary is unavailable.',
    if (screenAsync.hasError) 'Connected planning signals are unavailable.',
    if (habitsAsync.hasError) 'Creator habit signals are unavailable.',
    if (notesAsync.hasError) 'Creator note signals are unavailable.',
    if (creatorReceiptAsync.hasError)
      'The latest Creator receipt is unavailable.',
    if (siThreadAsync.hasError) 'The latest SI Console output is unavailable.',
    if (progression.error != null) 'Progression signals are unavailable.',
    if (pendingSyncAsync.hasError)
      'Queued synchronization status is unavailable.',
    if (syncError != null && syncError.trim().isNotEmpty)
      'Synchronization needs attention.',
  ];

  final List<NexusFeatureSignal> features = _buildFeatureSignals(
    screenAsync: screenAsync,
    screen: screen,
    habitsAsync: habitsAsync,
    notesAsync: notesAsync,
    creatorReceiptAsync: creatorReceiptAsync,
    siThreadAsync: siThreadAsync,
    progressionLoading: progression.loading,
    progressionError: progression.error,
    progressionLevel: progression.progress.level,
    progressionXp: progression.progress.xp,
    progressionIntelligence: progressionIntelligence,
    dailyBriefing: dailyBriefing,
    explainableSI: explainableSI,
    futureDecision: futureDecision,
  );

  final bool hasSecondaryLoading = features.any(
    (NexusFeatureSignal item) => item.health == NexusFeatureHealth.loading,
  );
  final bool hasDegradedFeature = features.any(
    (NexusFeatureSignal item) =>
        item.health == NexusFeatureHealth.degraded ||
        item.health == NexusFeatureHealth.unavailable,
  );
  final bool briefingLoading = briefing == null && briefingAsync.isLoading;
  final NexusBriefingStatus status;
  if (briefing == null && failures.isNotEmpty) {
    status = NexusBriefingStatus.error;
  } else if (briefingLoading) {
    status = NexusBriefingStatus.loading;
  } else if (!isOnline) {
    status = NexusBriefingStatus.offline;
  } else if (failures.isNotEmpty || hasSecondaryLoading || hasDegradedFeature) {
    status = NexusBriefingStatus.partial;
  } else {
    status = NexusBriefingStatus.ready;
  }

  final List<String> risks = briefing?.decision.warnings ?? const <String>[];
  final String topRisk = risks.isNotEmpty
      ? risks.first
      : briefing == null
      ? 'Risk assessment is waiting for current operating evidence.'
      : dailyBriefing.warning;
  final String recentProgress = _recentProgress(
    briefing,
    progressionIntelligence,
  );
  final String statusDetail = switch (status) {
    NexusBriefingStatus.loading =>
      'Building one evidence-backed operating decision.',
    NexusBriefingStatus.ready =>
      'Your planning summary is available on this device.',
    NexusBriefingStatus.partial =>
      failures.isEmpty
          ? 'The primary decision is ready while supporting signals finish loading.'
          : failures.join(' '),
    NexusBriefingStatus.offline =>
      pendingSyncCount > 0
          ? 'Using local evidence. $pendingSyncCount change${pendingSyncCount == 1 ? '' : 's'} will synchronize later.'
          : 'Using local evidence. Network-backed freshness is unavailable.',
    NexusBriefingStatus.error =>
      failures.isEmpty
          ? 'Nexus could not build an operating decision.'
          : failures.join(' '),
  };

  return NexusBriefingModel(
    status: status,
    isOnline: isOnline,
    pendingSyncCount: pendingSyncCount,
    briefing: briefing,
    featureSignals: features,
    topRisk: topRisk,
    recentProgress: recentProgress,
    statusDetail: statusDetail,
  );
});

final nexusBriefingActionsProvider = Provider<NexusBriefingActions>(
  NexusBriefingActions.new,
);

class NexusBriefingActions {
  const NexusBriefingActions(this._ref);

  final Ref _ref;

  void refresh() {
    _ref
      ..invalidate(operatingBriefingProvider)
      ..invalidate(nexusScreenModelProvider)
      ..invalidate(habitsProvider)
      ..invalidate(notesProvider)
      ..invalidate(latestCreatorReceiptProvider)
      ..invalidate(siConsoleThreadProvider)
      ..invalidate(offlineQueueCountProvider)
      ..invalidate(progressionProvider)
      ..invalidate(progressionIntelligenceProvider)
      ..invalidate(nexusBriefingProvider);
  }
}

List<NexusFeatureSignal> _buildFeatureSignals({
  required AsyncValue<NexusScreenModel> screenAsync,
  required NexusScreenModel? screen,
  required AsyncValue<List<HabitRecord>> habitsAsync,
  required AsyncValue<List<NoteEntity>> notesAsync,
  required AsyncValue<CreatorCreationReceipt?> creatorReceiptAsync,
  required AsyncValue<List<SIConsoleMessage>> siThreadAsync,
  required bool progressionLoading,
  required String? progressionError,
  required int progressionLevel,
  required int progressionXp,
  required ProgressionIntelligence progressionIntelligence,
  required DailyCommandBriefing dailyBriefing,
  required ExplainableSIState explainableSI,
  required FutureDecision futureDecision,
}) {
  final SIStateAggregation? aggregation = screen?.aggregation;
  final SIDecisionOutput? decision = screen?.decision;
  final bool coreLoading = screen == null && screenAsync.isLoading;
  final bool coreError = screenAsync.hasError;
  final int tasks = aggregation?.tasks.length ?? 0;
  final int goals = aggregation?.goals.length ?? 0;
  final int habits = habitsAsync.isLoading
      ? 0
      : habitsAsync.asData?.value.length ?? 0;
  final int notes = notesAsync.isLoading
      ? 0
      : notesAsync.asData?.value.length ?? 0;
  final CreatorCreationReceipt? receipt = creatorReceiptAsync.isLoading
      ? null
      : creatorReceiptAsync.asData?.value;
  final int timelineItems = aggregation?.timeline.length ?? 0;
  final int overdue =
      aggregation?.timeline.where((item) => item.isOverdue).length ?? 0;
  final int planBlocks = aggregation?.planPreview.length ?? 0;
  final int siMessages = siThreadAsync.isLoading
      ? 0
      : siThreadAsync.asData?.value.length ?? 0;

  NexusFeatureHealth coreHealth({required bool empty}) {
    if (coreError) return NexusFeatureHealth.unavailable;
    if (coreLoading) return NexusFeatureHealth.loading;
    return empty ? NexusFeatureHealth.empty : NexusFeatureHealth.ready;
  }

  final bool creatorLoading =
      coreLoading ||
      habitsAsync.isLoading ||
      notesAsync.isLoading ||
      creatorReceiptAsync.isLoading;
  final bool creatorError =
      coreError ||
      habitsAsync.hasError ||
      notesAsync.hasError ||
      creatorReceiptAsync.hasError;
  final NexusFeatureHealth creatorHealth = creatorError
      ? NexusFeatureHealth.degraded
      : creatorLoading
      ? NexusFeatureHealth.loading
      : tasks + goals + habits + notes == 0
      ? NexusFeatureHealth.empty
      : NexusFeatureHealth.ready;
  final NexusFeatureHealth siHealth = coreError || siThreadAsync.hasError
      ? NexusFeatureHealth.degraded
      : coreLoading || siThreadAsync.isLoading
      ? NexusFeatureHealth.loading
      : NexusFeatureHealth.ready;

  return <NexusFeatureSignal>[
    NexusFeatureSignal(
      featureId: ChronoSparkFeatureId.smartPlanner,
      health: coreHealth(empty: planBlocks == 0),
      headline: coreLoading
          ? 'Reconciling plan inputs'
          : decision?.plannerMessage ?? 'No reconciled plan is active yet.',
      detail: planBlocks == 0
          ? dailyBriefing.replanAction ??
                'Smart Planner can build the first feasible plan from Creator inputs.'
          : '$planBlocks near-term block${planBlocks == 1 ? '' : 's'} reconciled • ${decision?.nextAction ?? 'next action pending'}',
      revision: 'plan:$planBlocks',
    ),
    NexusFeatureSignal(
      featureId: ChronoSparkFeatureId.creator,
      health: creatorHealth,
      headline: '$tasks tasks • $goals goals • $habits habits • $notes notes',
      detail: receipt == null
          ? 'Creator inputs are ready for one accountable next commitment.'
          : 'Latest ${receipt.kind.name}: ${receipt.title}. ${receipt.whyItMatters}',
      revision: 'creator:$tasks:$goals:$habits:$notes',
    ),
    NexusFeatureSignal(
      featureId: ChronoSparkFeatureId.timeline,
      health: coreHealth(empty: timelineItems == 0),
      headline: '$timelineItems scheduled or recorded • $overdue overdue',
      detail: overdue > 0
          ? 'Recover the highest-ranked overdue commitment before pressure compounds.'
          : 'Timeline is reconciled with the current operating decision.',
      revision: 'timeline:$timelineItems:$overdue',
    ),
    NexusFeatureSignal(
      featureId: ChronoSparkFeatureId.trajectoryEngine,
      health: coreHealth(empty: aggregation == null),
      headline: aggregation == null
          ? 'Future state is still evaluating'
          : 'Momentum ${(aggregation.trajectory.momentum * 100).round()}% • Pressure ${aggregation.trajectory.pressureIndex}%',
      detail:
          aggregation?.trajectory.alert ??
          'Trajectory Engine will expose assumptions and correction options when evidence is ready.',
      revision: aggregation == null
          ? 'trajectory:pending'
          : 'trajectory:${aggregation.trajectory.momentum}:${aggregation.trajectory.pressureIndex}',
    ),
    NexusFeatureSignal(
      featureId: ChronoSparkFeatureId.progression,
      health: progressionError != null
          ? NexusFeatureHealth.degraded
          : progressionLoading
          ? NexusFeatureHealth.loading
          : NexusFeatureHealth.ready,
      headline:
          'Level $progressionLevel • $progressionXp XP • ${progressionIntelligence.status}',
      detail:
          '${progressionIntelligence.changedSincePriorWindow} ${progressionIntelligence.nextBestAction}',
      revision: 'progression:$progressionLevel:$progressionXp',
    ),
    NexusFeatureSignal(
      featureId: ChronoSparkFeatureId.siConsole,
      health: siHealth,
      headline: decision == null
          ? 'Strategic output is still evaluating'
          : futureDecision.recommendedChoice,
      detail: decision == null
          ? 'SI Console will explain evidence, uncertainty, and alternatives when ready.'
          : '${futureDecision.reason} ${explainableSI.primaryReason}',
      revision:
          'si:$siMessages:${decision?.warnings.length ?? 0}:${futureDecision.modelVersion}',
    ),
  ];
}

String _recentProgress(
  OperatingBriefing? briefing,
  ProgressionIntelligence progression,
) {
  if (briefing == null) {
    return 'Recent progress is waiting for the current evidence window.';
  }
  final material = briefing.delta.materialChanges;
  if (material.isNotEmpty) {
    final change = material.first;
    return '${change.label}: ${change.previousValue} to ${change.currentValue}. ${change.reason}';
  }
  return progression.changedSincePriorWindow;
}
