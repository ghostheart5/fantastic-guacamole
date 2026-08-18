import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrajectoryEngineStatus { loading, ready, empty, partial, offline, error }

class TrajectoryEngineModel {
  const TrajectoryEngineModel({
    required this.status,
    required this.summary,
    required this.momentum,
    required this.statusDetail,
    required this.isOnline,
    this.comparison,
    this.operatingBriefing,
  });

  final TrajectoryEngineStatus status;
  final TrajectorySummaryView summary;
  final MomentumEngineState momentum;
  final TrajectoryComparison? comparison;
  final OperatingBriefing? operatingBriefing;
  final String statusDetail;
  final bool isOnline;

  bool get hasComparison =>
      comparison != null && comparison!.outcomes.isNotEmpty;
}

final trajectoryEngineModelProvider = Provider<TrajectoryEngineModel>((
  Ref ref,
) {
  final TrajectorySummaryView summary = ref.watch(trajectorySummaryProvider);
  final MomentumEngineState momentum = ref.watch(momentumEngineProvider);
  final AsyncValue<TrajectoryComparison> comparisonAsync = ref.watch(
    trajectoryConsequenceProvider,
  );
  final AsyncValue<OperatingBriefing> briefingAsync = ref.watch(
    operatingBriefingProvider,
  );
  final bool isOnline = ref.watch(isOnlineProvider);
  final TrajectoryComparison? comparison = comparisonAsync.isLoading
      ? null
      : comparisonAsync.asData?.value;
  final OperatingBriefing? briefing = briefingAsync.isLoading
      ? null
      : briefingAsync.asData?.value;

  final TrajectoryEngineStatus status;
  final String detail;
  if (summary.sourceState == TrajectorySourceState.error ||
      comparisonAsync.hasError) {
    status = TrajectoryEngineStatus.error;
    detail =
        'Trajectory evidence could not be reconciled. No future conclusion is currently valid.';
  } else if (summary.sourceState == TrajectorySourceState.loading ||
      comparisonAsync.isLoading) {
    status = TrajectoryEngineStatus.loading;
    detail = 'Building a revisioned baseline before comparing future paths.';
  } else if (!isOnline) {
    status = TrajectoryEngineStatus.offline;
    detail =
        'Using locally available evidence. Network-backed freshness is unavailable.';
  } else if (summary.sourceState == TrajectorySourceState.empty ||
      comparison?.baseline.tasks.isEmpty == true) {
    status = TrajectoryEngineStatus.empty;
    detail =
        'Add a task with an estimate and, when relevant, a goal or deadline before simulating consequences.';
  } else if (summary.sourceState == TrajectorySourceState.partial ||
      briefingAsync.hasError ||
      briefingAsync.isLoading) {
    status = TrajectoryEngineStatus.partial;
    detail =
        'The scenario comparison is available, but one supporting intelligence source is incomplete.';
  } else {
    status = TrajectoryEngineStatus.ready;
    detail =
        'Current baseline, Smart Planner plan, Timeline links, goals, and Progression signals are reconciled.';
  }

  return TrajectoryEngineModel(
    status: status,
    summary: summary,
    momentum: momentum,
    comparison: comparison,
    operatingBriefing: briefing,
    statusDetail: detail,
    isOnline: isOnline,
  );
});

final trajectoryEngineActionsProvider = Provider<TrajectoryEngineActions>(
  TrajectoryEngineActions.new,
);

class TrajectoryEngineActions {
  const TrajectoryEngineActions(this._ref);

  final Ref _ref;

  void refresh() {
    _ref
      ..invalidate(trajectorySummaryProvider)
      ..invalidate(trajectoryConsequenceProvider)
      ..invalidate(operatingBriefingProvider)
      ..invalidate(trajectoryEngineModelProvider);
  }
}
