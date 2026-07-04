import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/si/offline/identity_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final identityStateProvider = NotifierProvider<IdentityNotifier, IdentityState>(
  IdentityNotifier.new,
);

class IdentityNotifier extends Notifier<IdentityState> {
  static const _key = 'identity_state_v1';
  static const _engine = IdentityEngine();

  @override
  IdentityState build() {
    final raw = SharedPrefsService.load(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        return IdentityState(
          disciplineIdentity: (j['discipline'] as num?)?.toDouble() ?? 0.1,
          focusIdentity: (j['focus'] as num?)?.toDouble() ?? 0.1,
          growthIdentity: (j['growth'] as num?)?.toDouble() ?? 0.1,
        );
      } catch (_) {}
    }
    return const IdentityState(
      disciplineIdentity: 0.1,
      focusIdentity: 0.1,
      growthIdentity: 0.1,
    );
  }

  Future<void> onFocusComplete({
    required bool sessionCompleted,
    required bool taskCompleted,
    required bool streakMaintained,
  }) async {
    state = _engine.update(
      current: state,
      sessionCompleted: sessionCompleted,
      taskCompleted: taskCompleted,
      streakMaintained: streakMaintained,
    );
    await _persist();
  }

  String get reinforcementMessage => _engine.reinforceIdentity(state, '');

  String get archetype {
    if (state.disciplineIdentity >= state.focusIdentity &&
        state.disciplineIdentity >= state.growthIdentity) {
      return 'The Executor';
    }
    if (state.focusIdentity >= state.growthIdentity) return 'The Strategist';
    return 'The Seeker';
  }

  Future<void> _persist() async {
    await SharedPrefsService.save(
      _key,
      jsonEncode({
        'discipline': state.disciplineIdentity,
        'focus': state.focusIdentity,
        'growth': state.growthIdentity,
      }),
    );
  }
}
