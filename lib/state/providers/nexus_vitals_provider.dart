import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home reflects the current Trajectory baseline, never a scenario projection.
final nexusTrajectoryVitalsProvider = Provider<NexusTrajectoryVitals>((ref) {
  final model = ref.watch(trajectoryEngineModelProvider);
  final String label = switch (model.status) {
    TrajectoryEngineStatus.loading => 'UPDATING',
    TrajectoryEngineStatus.error => 'UNAVAILABLE',
    TrajectoryEngineStatus.learning => 'LEARNING',
    TrajectoryEngineStatus.empty => 'NO PLAN',
    _ =>
      model.comparison == null
          ? 'UNAVAILABLE'
          : trajectoryMomentumBand(model.comparison!.baseline.momentum),
  };
  final available = switch (model.status) {
    TrajectoryEngineStatus.loading ||
    TrajectoryEngineStatus.error ||
    TrajectoryEngineStatus.learning ||
    TrajectoryEngineStatus.empty => false,
    _ => model.comparison != null,
  };
  final baseline = available ? model.comparison!.baseline : null;
  return NexusTrajectoryVitals(
    momentumLabel: label,
    momentumPercent: baseline?.momentum,
    pressurePercent: baseline?.pressure,
    activeCount: baseline?.tasks.length,
    unavailableDetail: available ? null : model.statusDetail,
  );
});

final nexusMomentumLabelProvider = Provider<String>(
  (ref) => ref.watch(nexusTrajectoryVitalsProvider).momentumLabel,
);

class NexusTrajectoryVitals {
  const NexusTrajectoryVitals({
    required this.momentumLabel,
    this.momentumPercent,
    this.pressurePercent,
    this.activeCount,
    this.unavailableDetail,
  });
  final String momentumLabel;
  final int? momentumPercent;
  final int? pressurePercent;
  final int? activeCount;
  final String? unavailableDetail;
}
