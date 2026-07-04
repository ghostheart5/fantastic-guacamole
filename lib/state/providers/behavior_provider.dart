import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/si/offline/behavior_shaping_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final behaviorStateProvider = NotifierProvider<BehaviorNotifier, BehaviorState>(
  BehaviorNotifier.new,
);

final behaviorTargetProvider = Provider<BehaviorTarget>((ref) {
  final state = ref.watch(behaviorStateProvider);
  return const BehaviorShapingEngine().generateTarget(state);
});

class BehaviorNotifier extends Notifier<BehaviorState> {
  static const _key = 'behavior_state_v1';
  static const _engine = BehaviorShapingEngine();

  @override
  BehaviorState build() {
    final raw = SharedPrefsService.load(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        return BehaviorState(
          consistency: (j['consistency'] as num?)?.toDouble() ?? 0.2,
          capacity: (j['capacity'] as num?)?.toDouble() ?? 0.2,
          stability: (j['stability'] as num?)?.toDouble() ?? 0.2,
        );
      } catch (_) {}
    }
    return const BehaviorState(consistency: 0.2, capacity: 0.2, stability: 0.2);
  }

  Future<void> onSessionComplete({
    required bool sessionCompleted,
    required bool taskCompleted,
    double frictionScore = 0.0,
  }) async {
    state = _engine.update(
      current: state,
      sessionCompleted: sessionCompleted,
      taskCompleted: taskCompleted,
      frictionScore: frictionScore,
    );
    await _persist();
  }

  Future<void> _persist() async {
    await SharedPrefsService.save(
      _key,
      jsonEncode({
        'consistency': state.consistency,
        'capacity': state.capacity,
        'stability': state.stability,
      }),
    );
  }
}
