import 'package:fantastic_guacamole/state/models/profile_model.dart';
import 'package:fantastic_guacamole/state/models/profile_view_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';

class ProfileService {
  const ProfileService();

  ProfileViewState fromControllerState(ProfileState source) {
    final ProfileModel model = ProfileModel(
      name: source.name,
      level: source.level,
      xp: source.xp,
      streak: source.streak,
      longestStreak: source.longestStreak,
      soundEnabled: source.soundEnabled,
    );
    return ProfileViewState(profile: model, loading: false);
  }
}
