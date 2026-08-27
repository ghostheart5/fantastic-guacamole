import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/engine/si/offline/identity_engine.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final identityStateProvider = NotifierProvider<IdentityNotifier, IdentityState>(
  IdentityNotifier.new,
);

class IdentityNotifier extends Notifier<IdentityState> {
  static const _engine = IdentityEngine();
  Future<void>? _hydration;

  @override
  IdentityState build() {
    _hydration ??= Future<void>.microtask(_hydrate);
    return const IdentityState(
      disciplineIdentity: 0.1,
      executionIdentity: 0.1,
      growthIdentity: 0.1,
    );
  }

  Future<void> _hydrate() async {
    try {
      final IdentityProfileEntity? profile = await ref
          .read(getIdentityProfileUseCaseProvider)
          .call();
      if (profile == null || !ref.mounted) {
        return;
      }
      state = IdentityState(
        disciplineIdentity: profile.disciplineIdentity,
        executionIdentity: profile.executionIdentity,
        growthIdentity: profile.growthIdentity,
      );
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'IdentityHydration',
        'Failed to restore the identity profile; keeping safe defaults.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> onExecutionComplete({
    required bool completionRecorded,
    required bool taskCompleted,
    required bool streakMaintained,
  }) async {
    await (_hydration ??= Future<void>.microtask(_hydrate));
    if (!ref.mounted) return;
    state = _engine.update(
      current: state,
      completionRecorded: completionRecorded,
      taskCompleted: taskCompleted,
      streakMaintained: streakMaintained,
    );
    await _persist();
  }

  String get reinforcementMessage => _engine.reinforceIdentity(state, '');

  String get archetype {
    if (state.disciplineIdentity >= state.executionIdentity &&
        state.disciplineIdentity >= state.growthIdentity) {
      return 'The Executor';
    }
    if (state.executionIdentity >= state.growthIdentity) {
      return 'The Strategist';
    }
    return 'The Seeker';
  }

  Future<void> _persist() async {
    await ref
        .read(saveIdentityProfileUseCaseProvider)
        .call(
          IdentityProfileEntity(
            disciplineIdentity: state.disciplineIdentity,
            executionIdentity: state.executionIdentity,
            growthIdentity: state.growthIdentity,
          ),
        );
  }
}
