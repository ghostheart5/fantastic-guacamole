import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/si_snapshot.dart';

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
