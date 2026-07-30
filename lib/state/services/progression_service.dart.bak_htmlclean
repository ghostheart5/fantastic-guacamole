import 'package:fantastic_guacamole/state/models/user_progress.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';

class ProgressionService {
  const ProgressionService();

  ProgressionState fromProfile(ProfileState profile) {
    final UserProgress progress = UserProgress(
      xp: profile.xp,
      level: profile.level,
      streak: profile.streak,
      longestStreak: profile.longestStreak,
    );
    return ProgressionState(progress: progress, loading: false);
  }
}
