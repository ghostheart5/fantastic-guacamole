import 'package:fantastic_guacamole/features/progression/models/user_progress.dart';
import 'package:fantastic_guacamole/features/progression/state/progression_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';

class ProgressionService {
  const ProgressionService({this.xpPerLevel = 50});

  final int xpPerLevel;

  ProgressionState fromProfile(ProfileState profile) {
    final UserProgress progress = UserProgress(
      xp: profile.xp,
      level: profile.level,
      streak: profile.streak,
      longestStreak: profile.longestStreak,
      xpPerLevel: xpPerLevel,
    );
    return ProgressionState(progress: progress, loading: false);
  }
}
