import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';

class AdaptiveLearning {
  const AdaptiveLearning(this.state);

  final LearningState state;

  LearningState onTaskComplete(int difficulty) {
    final LearningState next = _clamp(
      state.copyWith(
        effortWeight: state.effortWeight + 0.05,
        priorityWeight: state.priorityWeight + (difficulty >= 4 ? 0.03 : 0.02),
        completed: state.completed + 1,
      ),
    );

    Logger.log(
      'LEARNING',
      'COMPLETE -> effort=${next.effortWeight}, priority=${next.priorityWeight}',
    );

    return next;
  }

  LearningState onTaskSkipped(int difficulty) {
    final LearningState next = _clamp(
      state.copyWith(
        effortWeight: state.effortWeight - 0.05,
        priorityWeight: state.priorityWeight - (difficulty >= 4 ? 0.02 : 0.0),
        skipped: state.skipped + 1,
      ),
    );

    Logger.log('LEARNING', 'SKIPPED -> effort=${next.effortWeight}');

    return next;
  }

  LearningState _clamp(LearningState value) {
    return value.copyWith(
      effortWeight: value.effortWeight.clamp(0.5, 2.0),
      priorityWeight: value.priorityWeight.clamp(0.5, 2.0),
    );
  }
}
