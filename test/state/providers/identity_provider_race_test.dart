import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'focus completion waits for identity hydration before applying deltas',
    () async {
      final _DelayedIdentityRepository repository =
          _DelayedIdentityRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainIdentityRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(identityStateProvider).disciplineIdentity, 0.1);
      final Future<void> completion = container
          .read(identityStateProvider.notifier)
          .onFocusComplete(
            completionRecorded: true,
            taskCompleted: true,
            streakMaintained: true,
          );
      await pumpEventQueue();
      expect(repository.saved, isNull);

      repository.completeHydration(
        const IdentityProfileEntity(
          disciplineIdentity: 0.8,
          focusIdentity: 0.6,
          growthIdentity: 0.4,
        ),
      );
      await completion;

      expect(
        container.read(identityStateProvider).disciplineIdentity,
        closeTo(0.82, 0.0001),
      );
      expect(
        container.read(identityStateProvider).focusIdentity,
        closeTo(0.63, 0.0001),
      );
      expect(
        container.read(identityStateProvider).growthIdentity,
        closeTo(0.42, 0.0001),
      );
      expect(repository.saved?.disciplineIdentity, closeTo(0.82, 0.0001));
    },
  );
}

class _DelayedIdentityRepository implements IIdentityRepository {
  final Completer<IdentityProfileEntity?> _hydration =
      Completer<IdentityProfileEntity?>();
  IdentityProfileEntity? saved;

  void completeHydration(IdentityProfileEntity value) {
    _hydration.complete(value);
  }

  @override
  Future<IdentityProfileEntity?> getIdentityProfile() => _hydration.future;

  @override
  Future<void> saveIdentityProfile(IdentityProfileEntity profile) async {
    saved = profile;
  }

  @override
  Future<String?> getIdentityId() async => null;

  @override
  Future<void> saveIdentityId(String id) async {}
}
