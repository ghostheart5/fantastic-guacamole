import 'dart:convert';

import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SIStateController extends Notifier<SIState> {
  @override
  SIState build() {
    _loadFromAsset();
    return const SIState();
  }

  Future<void> _loadFromAsset() async {
    try {
      final String raw = await rootBundle.loadString('assets/data/user.json');
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      state = SIState(
        energy: (data['energy'] as num?)?.toDouble() ?? 0.7,
        fatigue: (data['fatigue'] as num?)?.toDouble() ?? 0.3,
        completedToday: (data['completedToday'] as int?) ?? 0,
      );
    } catch (_) {
      // Keep defaults on parse failure.
    }
  }

  void sessionComplete() {
    state = state.copyWith(
      energy: (state.energy - 0.08).clamp(0.0, 1.0),
      fatigue: (state.fatigue + 0.10).clamp(0.0, 1.0),
      completedToday: state.completedToday + 1,
    );
  }

  void taskSkipped() {
    state = state.copyWith(fatigue: (state.fatigue + 0.05).clamp(0.0, 1.0));
  }

  void adjustEnergy(double delta) {
    state = state.copyWith(energy: (state.energy + delta).clamp(0.0, 1.0));
  }

  void adjustFatigue(double delta) {
    state = state.copyWith(fatigue: (state.fatigue + delta).clamp(0.0, 1.0));
  }

  void replaceState({
    required double energy,
    required double fatigue,
    int? completedToday,
  }) {
    state = state.copyWith(
      energy: energy.clamp(0.0, 1.0),
      fatigue: fatigue.clamp(0.0, 1.0),
      completedToday: completedToday ?? state.completedToday,
    );
  }

  void reset() {
    state = const SIState();
  }
}

final siStateProvider = NotifierProvider<SIStateController, SIState>(
  SIStateController.new,
);
