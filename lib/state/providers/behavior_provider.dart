import 'dart:convert';

import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/si/offline/behavior_shaping_engine.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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
  late SharedPrefsStore _store;

  @override
  BehaviorState build() {
    _store = AccountScopedSharedPrefsStore(
      delegate: ref.read(sharedPrefsStoreProvider),
      scope: ref.watch(accountStorageScopeProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    );
    final raw = _store.load(_key);
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

  Future<void> onCompletionRecorded({
    required bool completionRecorded,
    required bool taskCompleted,
    double frictionScore = 0.0,
  }) async {
    state = _engine.update(
      current: state,
      completionRecorded: completionRecorded,
      taskCompleted: taskCompleted,
      frictionScore: frictionScore,
    );
    await _persist();
  }

  Future<void> _persist() async {
    await _store.save(
      _key,
      jsonEncode({
        'consistency': state.consistency,
        'capacity': state.capacity,
        'stability': state.stability,
      }),
    );
  }
}
