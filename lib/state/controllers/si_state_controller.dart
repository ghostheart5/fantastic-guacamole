import 'dart:async';

import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SIStateController extends Notifier<SIState> {
  static const checkInFreshness = Duration(hours: 2);
  Timer? _energyExpiry;
  Timer? _fatigueExpiry;
  bool _expiryDisposalRegistered = false;

  /// Owns live SI operating state used by chat and recommendation flows.
  @override
  SIState build() => const SIState();

  void recordCompletion() {
    state = state.copyWith(completedToday: state.completedToday + 1);
  }

  void taskSkipped() {}

  void adjustEnergy(double delta) {
    if (!delta.isFinite) return;
    state = state.copyWith(
      energy: (state.energy + delta).clamp(0.0, 1.0),
      energyOrigin: PredictiveEvidenceOrigin.observed,
    );
    _scheduleExpiry(energy: true, observed: true);
  }

  void adjustFatigue(double delta) {
    if (!delta.isFinite) return;
    state = state.copyWith(
      fatigue: (state.fatigue + delta).clamp(0.0, 1.0),
      fatigueOrigin: PredictiveEvidenceOrigin.observed,
    );
    _scheduleExpiry(energy: false, observed: true);
  }

  void replaceState({
    required double energy,
    required double fatigue,
    int? completedToday,
    PredictiveEvidenceOrigin? energyOrigin,
    PredictiveEvidenceOrigin? fatigueOrigin,
  }) {
    if (!energy.isFinite || !fatigue.isFinite) return;
    state = state.copyWith(
      energy: energy.clamp(0.0, 1.0),
      fatigue: fatigue.clamp(0.0, 1.0),
      completedToday: completedToday ?? state.completedToday,
      energyOrigin: energyOrigin ?? state.energyOrigin,
      fatigueOrigin: fatigueOrigin ?? state.fatigueOrigin,
    );
    if (energyOrigin != null) {
      _scheduleExpiry(energy: true, observed: state.hasObservedEnergy);
    }
    if (fatigueOrigin != null) {
      _scheduleExpiry(energy: false, observed: state.hasObservedFatigue);
    }
  }

  void reset() {
    _energyExpiry?.cancel();
    _fatigueExpiry?.cancel();
    state = const SIState();
  }

  void _scheduleExpiry({required bool energy, required bool observed}) {
    if (!_expiryDisposalRegistered) {
      _expiryDisposalRegistered = true;
      ref.onDispose(() {
        _energyExpiry?.cancel();
        _fatigueExpiry?.cancel();
        _expiryDisposalRegistered = false;
      });
    }
    if (energy) {
      _energyExpiry?.cancel();
      _energyExpiry = observed
          ? Timer(checkInFreshness, () {
              state = state.copyWith(
                energy: .5,
                energyOrigin: PredictiveEvidenceOrigin.unavailable,
              );
            })
          : null;
    } else {
      _fatigueExpiry?.cancel();
      _fatigueExpiry = observed
          ? Timer(checkInFreshness, () {
              state = state.copyWith(
                fatigue: .5,
                fatigueOrigin: PredictiveEvidenceOrigin.unavailable,
              );
            })
          : null;
    }
  }
}

final siStateProvider = NotifierProvider<SIStateController, SIState>(
  SIStateController.new,
);
