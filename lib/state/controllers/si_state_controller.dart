import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SIStateController extends Notifier<SIState> {
  /// Owns live SI operating state used by chat and recommendation flows.
  @override
  SIState build() => const SIState();

  void recordCompletion() {
    state = state.copyWith(completedToday: state.completedToday + 1);
  }

  void taskSkipped() {}

  void adjustEnergy(double delta) {
    state = state.copyWith(
      energy: (state.energy + delta).clamp(0.0, 1.0),
      energyOrigin: PredictiveEvidenceOrigin.observed,
    );
  }

  void adjustFatigue(double delta) {
    state = state.copyWith(
      fatigue: (state.fatigue + delta).clamp(0.0, 1.0),
      fatigueOrigin: PredictiveEvidenceOrigin.observed,
    );
  }

  void replaceState({
    required double energy,
    required double fatigue,
    int? completedToday,
    PredictiveEvidenceOrigin? energyOrigin,
    PredictiveEvidenceOrigin? fatigueOrigin,
  }) {
    state = state.copyWith(
      energy: energy.clamp(0.0, 1.0),
      fatigue: fatigue.clamp(0.0, 1.0),
      completedToday: completedToday ?? state.completedToday,
      energyOrigin: energyOrigin ?? state.energyOrigin,
      fatigueOrigin: fatigueOrigin ?? state.fatigueOrigin,
    );
  }

  void reset() {
    state = const SIState();
  }
}

final siStateProvider = NotifierProvider<SIStateController, SIState>(
  SIStateController.new,
);
