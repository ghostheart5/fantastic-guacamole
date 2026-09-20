import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siStateClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

class SIStateController extends Notifier<SIState> {
  static const checkInFreshness = Duration(hours: 2);
  static const _storageKey = 'si_human_state_check_in.v1';

  Timer? _energyExpiry;
  Timer? _fatigueExpiry;
  DateTime? _energyObservedAt;
  DateTime? _fatigueObservedAt;
  SharedPrefsStore? _store;
  DateTime Function()? _clock;
  bool _disposeRegistered = false;
  Future<void> _writes = Future<void>.value();

  /// Owns live SI operating state used by chat and recommendation flows.
  /// Explicit human check-ins survive process restarts for their two-hour
  /// freshness window and remain isolated by the account-scoped store.
  @override
  SIState build() {
    _energyExpiry?.cancel();
    _fatigueExpiry?.cancel();
    _store = ref.watch(accountSharedPrefsStoreProvider);
    _clock = ref.watch(siStateClockProvider);
    final restored = _restore();
    _registerDisposal();
    _scheduleExpiry(
      energy: true,
      observed: restored.hasObservedEnergy,
      observedAt: _energyObservedAt,
    );
    _scheduleExpiry(
      energy: false,
      observed: restored.hasObservedFatigue,
      observedAt: _fatigueObservedAt,
    );
    return restored;
  }

  void recordCompletion() {
    state = state.copyWith(completedToday: state.completedToday + 1);
  }

  void taskSkipped() {}

  void adjustEnergy(double delta) {
    if (!delta.isFinite) return;
    _energyObservedAt = _now();
    state = state.copyWith(
      energy: (state.energy + delta).clamp(0.0, 1.0),
      energyOrigin: PredictiveEvidenceOrigin.observed,
    );
    _scheduleExpiry(
      energy: true,
      observed: true,
      observedAt: _energyObservedAt,
    );
    _persist();
  }

  void adjustFatigue(double delta) {
    if (!delta.isFinite) return;
    _fatigueObservedAt = _now();
    state = state.copyWith(
      fatigue: (state.fatigue + delta).clamp(0.0, 1.0),
      fatigueOrigin: PredictiveEvidenceOrigin.observed,
    );
    _scheduleExpiry(
      energy: false,
      observed: true,
      observedAt: _fatigueObservedAt,
    );
    _persist();
  }

  void replaceState({
    required double energy,
    required double fatigue,
    int? completedToday,
    PredictiveEvidenceOrigin? energyOrigin,
    PredictiveEvidenceOrigin? fatigueOrigin,
  }) {
    if (!energy.isFinite || !fatigue.isFinite) return;
    final now = _now();
    if (energyOrigin != null) {
      _energyObservedAt = energyOrigin == PredictiveEvidenceOrigin.observed
          ? now
          : null;
    }
    if (fatigueOrigin != null) {
      _fatigueObservedAt = fatigueOrigin == PredictiveEvidenceOrigin.observed
          ? now
          : null;
    }
    state = state.copyWith(
      energy: energy.clamp(0.0, 1.0),
      fatigue: fatigue.clamp(0.0, 1.0),
      completedToday: completedToday ?? state.completedToday,
      energyOrigin: energyOrigin ?? state.energyOrigin,
      fatigueOrigin: fatigueOrigin ?? state.fatigueOrigin,
    );
    if (energyOrigin != null) {
      _scheduleExpiry(
        energy: true,
        observed: state.hasObservedEnergy,
        observedAt: _energyObservedAt,
      );
    }
    if (fatigueOrigin != null) {
      _scheduleExpiry(
        energy: false,
        observed: state.hasObservedFatigue,
        observedAt: _fatigueObservedAt,
      );
    }
    if (energyOrigin != null || fatigueOrigin != null) _persist();
  }

  void reset() {
    _energyExpiry?.cancel();
    _fatigueExpiry?.cancel();
    _energyObservedAt = null;
    _fatigueObservedAt = null;
    state = const SIState();
    final store = _resolvedStore;
    _enqueue(() => store.delete(_storageKey));
  }

  SIState _restore() {
    try {
      final raw = _resolvedStore.load(_storageKey);
      if (raw == null) return const SIState();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const SIState();
      final now = _now();
      final energy = _freshObservation(
        decoded['energy'],
        decoded['energyObservedAt'],
        now,
      );
      final fatigue = _freshObservation(
        decoded['fatigue'],
        decoded['fatigueObservedAt'],
        now,
      );
      _energyObservedAt = energy?.observedAt;
      _fatigueObservedAt = fatigue?.observedAt;
      return SIState(
        energy: energy?.value ?? .5,
        fatigue: fatigue?.value ?? .5,
        energyOrigin: energy == null
            ? PredictiveEvidenceOrigin.unavailable
            : PredictiveEvidenceOrigin.observed,
        fatigueOrigin: fatigue == null
            ? PredictiveEvidenceOrigin.unavailable
            : PredictiveEvidenceOrigin.observed,
      );
    } on Object {
      return const SIState();
    }
  }

  _StoredObservation? _freshObservation(
    Object? rawValue,
    Object? rawObservedAt,
    DateTime now,
  ) {
    if (rawValue is! num || !rawValue.isFinite || rawObservedAt is! String) {
      return null;
    }
    final observedAt = DateTime.tryParse(rawObservedAt)?.toUtc();
    if (observedAt == null || observedAt.isAfter(now)) return null;
    final age = now.difference(observedAt);
    if (age >= checkInFreshness) return null;
    return _StoredObservation(
      value: rawValue.clamp(0.0, 1.0).toDouble(),
      observedAt: observedAt,
    );
  }

  void _scheduleExpiry({
    required bool energy,
    required bool observed,
    required DateTime? observedAt,
  }) {
    _registerDisposal();
    final timer = energy ? _energyExpiry : _fatigueExpiry;
    timer?.cancel();
    Timer? replacement;
    if (observed && observedAt != null) {
      final remaining = observedAt.add(checkInFreshness).difference(_now());
      replacement = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (energy) {
          _energyObservedAt = null;
          state = state.copyWith(
            energy: .5,
            energyOrigin: PredictiveEvidenceOrigin.unavailable,
          );
        } else {
          _fatigueObservedAt = null;
          state = state.copyWith(
            fatigue: .5,
            fatigueOrigin: PredictiveEvidenceOrigin.unavailable,
          );
        }
        _persist();
      });
    }
    if (energy) {
      _energyExpiry = replacement;
    } else {
      _fatigueExpiry = replacement;
    }
  }

  void _persist() {
    final store = _resolvedStore;
    final payload = jsonEncode({
      if (state.hasObservedEnergy && _energyObservedAt != null) ...{
        'energy': state.energy,
        'energyObservedAt': _energyObservedAt!.toUtc().toIso8601String(),
      },
      if (state.hasObservedFatigue && _fatigueObservedAt != null) ...{
        'fatigue': state.fatigue,
        'fatigueObservedAt': _fatigueObservedAt!.toUtc().toIso8601String(),
      },
    });
    _enqueue(() => store.save(_storageKey, payload));
  }

  void _enqueue(Future<void> Function() operation) {
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => operation())
        .catchError((Object _) {});
  }

  void _registerDisposal() {
    if (_disposeRegistered) return;
    _disposeRegistered = true;
    ref.onDispose(() {
      _energyExpiry?.cancel();
      _fatigueExpiry?.cancel();
    });
  }

  SharedPrefsStore get _resolvedStore =>
      _store ?? ref.read(accountSharedPrefsStoreProvider);

  DateTime _now() {
    final configuredClock = _clock;
    if (configuredClock != null) return configuredClock();
    return ref.read(siStateClockProvider)();
  }
}

final class _StoredObservation {
  const _StoredObservation({required this.value, required this.observedAt});
  final double value;
  final DateTime observedAt;
}

final siStateProvider = NotifierProvider<SIStateController, SIState>(
  SIStateController.new,
);
