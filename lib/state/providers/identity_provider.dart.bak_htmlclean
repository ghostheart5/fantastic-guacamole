import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/engine/si/offline/identity_engine.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final identityStateProvider = NotifierProvider<IdentityNotifier, IdentityState>(
  IdentityNotifier.new,
);

class IdentityNotifier extends Notifier<IdentityState> {
  static const _engine = IdentityEngine();
  bool _hydrateScheduled = false;

  @override
  IdentityState build() {
    if (!_hydrateScheduled) {
      _hydrateScheduled = true;
      Future<void>.microtask(_hydrate);
    }
    return const IdentityState(
      disciplineIdentity: 0.1,
      focusIdentity: 0.1,
      growthIdentity: 0.1,
    );
  }

  Future<void> _hydrate() async {
    final IdentityProfileEntity? profile = await ref
        .read(getIdentityProfileUseCaseProvider)
        .call();
    if (profile == null) {
      return;
    }
    state = IdentityState(
      disciplineIdentity: profile.disciplineIdentity,
      focusIdentity: profile.focusIdentity,
      growthIdentity: profile.growthIdentity,
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
    await ref
        .read(saveIdentityProfileUseCaseProvider)
        .call(
          IdentityProfileEntity(
            disciplineIdentity: state.disciplineIdentity,
            focusIdentity: state.focusIdentity,
            growthIdentity: state.growthIdentity,
          ),
        );
  }
}
