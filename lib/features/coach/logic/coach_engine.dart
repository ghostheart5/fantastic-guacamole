import 'package:fantastic_guacamole/features/coach/models/coach_state.dart';

class CoachEngine {
  const CoachEngine();

  CoachState buildRecommendation({
    required String focusTask,
    required String reason,
    required bool canStartFocus,
  }) {
    final String recommendation = focusTask.trim().isEmpty
        ? 'Let\'s create your first task.'
        : 'Start Deep Work on $focusTask';

    return CoachState(
      recommendation: recommendation,
      reason: reason,
      canStartFocus: canStartFocus,
    );
  }
}
