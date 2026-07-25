import 'package:fantastic_guacamole/state/state/emotional_state.dart';

class SmartCoachRequest {
  const SmartCoachRequest({
    required this.energy,
    required this.emotion,
    required this.notes,
    required this.history,
    this.previousSavedNotes,
  });

  final double energy;
  final EmotionalState emotion;
  final String notes;
  final List<Map<String, String>> history;
  final String? previousSavedNotes;
}
