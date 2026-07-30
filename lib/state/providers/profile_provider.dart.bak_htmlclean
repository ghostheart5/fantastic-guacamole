import 'package:fantastic_guacamole/state/services/profile_service.dart';
import 'package:fantastic_guacamole/state/models/profile_view_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileFeatureServiceProvider = Provider<ProfileService>(
  (Ref ref) => const ProfileService(),
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
    _ref.read(profileProvider.notifier).toggleSound(value);
  }

  void updateName(String name) {
    _ref.read(profileProvider.notifier).updateName(name);
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
