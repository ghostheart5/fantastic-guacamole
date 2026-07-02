import 'package:fantastic_guacamole/features/profile/logic/profile_presistence.dart';
import 'package:fantastic_guacamole/features/profile/services/profile_service.dart';
import 'package:fantastic_guacamole/features/profile/state/profile_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileFeatureServiceProvider = Provider<ProfileService>(
  (Ref ref) => const ProfileService(),
);

final profilePersistenceProvider = Provider<ProfilePersistence>(
  (Ref ref) => const ProfilePersistence(),
);

final profileViewStateProvider = Provider<ProfileViewState>((Ref ref) {
  final source = ref.watch(profileProvider);
  final service = ref.watch(profileFeatureServiceProvider);
  return service.fromControllerState(source);
});

class ProfileActions {
  const ProfileActions(this._ref);

  final Ref _ref;

  void toggleSound(bool value) {
    final persistence = _ref.read(profilePersistenceProvider);
    final notifier = _ref.read(profileProvider.notifier);
    persistence.toggleSound(notifier, value);
  }

  void updateName(String name) {
    final persistence = _ref.read(profilePersistenceProvider);
    final notifier = _ref.read(profileProvider.notifier);
    persistence.updateName(notifier, name);
  }

  void openProgression() {
    _ref.read(appFlowProvider.notifier).toProgression();
  }

  void openSettings() {
    _ref.read(appFlowProvider.notifier).toSettings();
  }
}

final profileActionsProvider = Provider<ProfileActions>(
  (Ref ref) => ProfileActions(ref),
);
