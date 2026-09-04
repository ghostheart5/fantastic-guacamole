import 'package:fantastic_guacamole/engine/assistant/assistant_memory_models.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart'
    show SIState;

/// Creates the initial assistant-memory observation from engine state.
class AssistantSystemBoot {
  const AssistantSystemBoot();

  AssistantMemorySnapshot initialSnapshot({
    required SIState si,
    required LearningState learning,
  }) {
    return AssistantMemorySnapshot(
      timestamp: DateTime.now(),
      energy: si.energy,
      fatigue: si.fatigue,
      completed: learning.completed,
      skipped: learning.skipped,
      reasoning: 'System boot',
    );
  }
}
