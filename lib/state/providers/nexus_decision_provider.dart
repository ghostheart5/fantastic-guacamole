import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nexusDecisionProvider = Provider<NexusDecisionModel>((Ref ref) {
  final AsyncValue<DecisionIntelligence> decisionAsync = ref.watch(
    decisionIntelligenceProvider,
  );
  final progression = ref.watch(progressionProvider);
  final ProgressionIntelligence progressionIntelligence = ref.watch(
    progressionIntelligenceProvider,
  );
  final DailyDecisionIntelligence dailyIntelligence = ref.watch(
    dailyDecisionIntelligenceProvider,
  );
  final bool isOnline = ref.watch(isOnlineProvider);
  final AsyncValue<int> pendingSyncAsync = ref.watch(offlineQueueCountProvider);
  final String? syncError = ref.watch(syncErrorMessageProvider);

  // Riverpod can retain a previous value while a dependency refreshes. Nexus
  // must never present that previous account/scope as current decision state.
  final DecisionIntelligence? intelligence = decisionAsync.isLoading
      ? null
      : decisionAsync.asData?.value;
  final int pendingSyncCount = pendingSyncAsync.asData?.value ?? 0;
  final List<String> failures = <String>[
    if (decisionAsync.hasError) 'Your planning summary is unavailable.',
    if (progression.error != null) 'Progression signals are unavailable.',
    if (pendingSyncAsync.hasError)
      'Queued synchronization status is unavailable.',
    if (syncError != null && syncError.trim().isNotEmpty)
      'Synchronization needs attention.',
  ];

  final bool decisionLoading = intelligence == null && decisionAsync.isLoading;
  final NexusDecisionStatus status;
  if (intelligence == null && failures.isNotEmpty) {
    status = NexusDecisionStatus.error;
  } else if (decisionLoading) {
    status = NexusDecisionStatus.loading;
  } else if (!isOnline) {
    status = NexusDecisionStatus.offline;
  } else if (failures.isNotEmpty) {
    status = NexusDecisionStatus.partial;
  } else {
    status = NexusDecisionStatus.ready;
  }

  final List<String> risks =
      intelligence?.decision.warnings ?? const <String>[];
  final String topRisk = risks.isNotEmpty
      ? risks.first
      : intelligence == null
      ? 'Risk assessment is waiting for current evidence.'
      : dailyIntelligence.warning;
  final String recentProgress = _recentProgress(
    intelligence,
    progressionIntelligence,
  );
  final String statusDetail = switch (status) {
    NexusDecisionStatus.loading => 'Building one evidence-backed decision.',
    NexusDecisionStatus.ready =>
      'Your planning summary is available on this device.',
    NexusDecisionStatus.partial =>
      failures.isEmpty
          ? 'The primary decision is ready while supporting signals finish loading.'
          : failures.join(' '),
    NexusDecisionStatus.offline =>
      pendingSyncCount > 0
          ? 'Using local evidence. $pendingSyncCount change${pendingSyncCount == 1 ? '' : 's'} will synchronize later.'
          : 'Using local evidence. Network-backed freshness is unavailable.',
    NexusDecisionStatus.error =>
      failures.isEmpty
          ? 'Nexus could not build a decision.'
          : failures.join(' '),
  };

  return NexusDecisionModel(
    status: status,
    isOnline: isOnline,
    pendingSyncCount: pendingSyncCount,
    intelligence: intelligence,
    topRisk: topRisk,
    recentProgress: recentProgress,
    statusDetail: statusDetail,
  );
});

final nexusDecisionActionsProvider = Provider<NexusDecisionActions>(
  NexusDecisionActions.new,
);

class NexusDecisionActions {
  const NexusDecisionActions(this._ref);

  final Ref _ref;

  void refresh() {
    _ref
      ..invalidate(operatingSnapshotProvider)
      ..invalidate(operatingDecisionPlanProvider)
      ..invalidate(operatingDecisionReceiptProvider)
      ..invalidate(decisionIntelligenceProvider)
      ..invalidate(offlineQueueCountProvider)
      ..invalidate(progressionProvider)
      ..invalidate(progressionIntelligenceProvider)
      ..invalidate(nexusDecisionProvider);
  }
}

String _recentProgress(
  DecisionIntelligence? intelligence,
  ProgressionIntelligence progression,
) {
  if (intelligence == null) {
    return 'Recent progress is waiting for the current evidence window.';
  }
  final material = intelligence.delta.materialChanges;
  if (material.isNotEmpty) {
    final change = material.first;
    return '${change.label}: ${change.previousValue} to ${change.currentValue}. ${change.reason}';
  }
  return progression.changedSincePriorWindow;
}
