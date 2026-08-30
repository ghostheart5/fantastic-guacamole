import 'dart:convert';

import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SIStateController extends Notifier<SIState> {
  bool _loadScheduled = false;
  int _mutationVersion = 0;

  /// Owns live SI operating state used by chat and recommendation flows.
  @override
  SIState build() {
    if (!_loadScheduled) {
      _loadScheduled = true;
      Future<void>.microtask(_loadFromAsset);
    }
    return const SIState();
  }

  Future<void> _loadFromAsset() async {
    final int loadVersion = _mutationVersion;
    try {
      final String raw = await rootBundle.loadString('assets/data/user.json');
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      if (!ref.mounted || _mutationVersion != loadVersion) {
        return;
      }
      state = SIState(
        energy: (data['energy'] as num?)?.toDouble() ?? 0.7,
        fatigue: (data['fatigue'] as num?)?.toDouble() ?? 0.3,
        completedToday: (data['completedToday'] as int?) ?? 0,
        energyOrigin: PredictiveEvidenceOrigin.estimated,
        fatigueOrigin: PredictiveEvidenceOrigin.estimated,
      );
    } catch (_) {
      // Keep defaults on parse failure.
    }
  }

  void recordCompletion() {
    _mutationVersion++;
    state = state.copyWith(
      energy: (state.energy - 0.08).clamp(0.0, 1.0),
      fatigue: (state.fatigue + 0.10).clamp(0.0, 1.0),
      completedToday: state.completedToday + 1,
    );
  }

  void taskSkipped() {
    _mutationVersion++;
    state = state.copyWith(fatigue: (state.fatigue + 0.05).clamp(0.0, 1.0));
  }

  void adjustEnergy(double delta) {
    _mutationVersion++;
    state = state.copyWith(energy: (state.energy + delta).clamp(0.0, 1.0));
  }

  void adjustFatigue(double delta) {
    _mutationVersion++;
    state = state.copyWith(fatigue: (state.fatigue + delta).clamp(0.0, 1.0));
  }

  void replaceState({
    required double energy,
    required double fatigue,
    int? completedToday,
    PredictiveEvidenceOrigin? energyOrigin,
    PredictiveEvidenceOrigin? fatigueOrigin,
  }) {
    _mutationVersion++;
    state = state.copyWith(
      energy: energy.clamp(0.0, 1.0),
      fatigue: fatigue.clamp(0.0, 1.0),
      completedToday: completedToday ?? state.completedToday,
      energyOrigin: energyOrigin ?? state.energyOrigin,
      fatigueOrigin: fatigueOrigin ?? state.fatigueOrigin,
    );
  }

  void reset() {
    _mutationVersion++;
    state = const SIState();
  }
}

final siStateProvider = NotifierProvider<SIStateController, SIState>(
  SIStateController.new,
);
