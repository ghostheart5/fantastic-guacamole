import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_follow_up_request.dart';
import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_request.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';

class SmartCoachConversationService {
  const SmartCoachConversationService();

  SmartCoachRequest buildRequest({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    String? previousSavedNotes,
  }) {
    return SmartCoachRequest(
      energy: energy,
      emotion: emotion,
      notes: notes,
      history: history,
      previousSavedNotes: previousSavedNotes,
    );
  }

  SmartCoachFollowUpRequest buildFollowUpRequest({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) {
    return SmartCoachFollowUpRequest(
      input: input,
      energy: energy,
      emotion: emotion,
      reflection: reflection,
      history: history,
    );
  }
}
