import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_follow_up_request.dart';
import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_request.dart';
import 'package:fantastic_guacamole/features/home/ui/services/smart_coach_conversation_service.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';

class SmartCoachConversationController {
  const SmartCoachConversationController({
    this.service = const SmartCoachConversationService(),
  });

  final SmartCoachConversationService service;

  SmartCoachRequest buildCoachingRequest({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    String? previousSavedNotes,
  }) {
    return service.buildRequest(
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
    return service.buildFollowUpRequest(
      input: input,
      energy: energy,
      emotion: emotion,
      reflection: reflection,
      history: history,
    );
  }
}
