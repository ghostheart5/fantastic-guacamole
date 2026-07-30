import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart'
    show SIState;
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';

class SystemBoot {
  const SystemBoot();

  SISnapshot initialSnapshot({
    required SIState si,
    required LearningState learning,
  }) {
    return SISnapshot(
      timestamp: DateTime.now(),
      energy: si.energy,
      fatigue: si.fatigue,
      completed: learning.completed,
      skipped: learning.skipped,
      reasoning: 'System boot',
    );
  }
}
