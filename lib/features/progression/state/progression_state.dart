import 'package:fantastic_guacamole/features/progression/models/user_progress.dart';

class ProgressionState {
  const ProgressionState({
    required this.progress,
    required this.loading,
    this.error,
  });

  final UserProgress progress;
  final bool loading;
  final String? error;

  factory ProgressionState.initial() {
    return const ProgressionState(
      progress: UserProgress(
        xp: 0,
        level: 1,
        streak: 0,
        longestStreak: 0,
        xpPerLevel: 50,
      ),
      loading: false,
      error: null,
    );
  }
}
