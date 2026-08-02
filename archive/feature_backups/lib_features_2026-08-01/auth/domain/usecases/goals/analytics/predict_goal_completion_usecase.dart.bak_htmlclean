import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalCompletionPrediction {
  const GoalCompletionPrediction({
    required this.goal,
    required this.predictedDate,
    required this.confidence,
  });

  final GoalEntity goal;
  final DateTime? predictedDate;
  final double confidence;
}

class PredictGoalCompletionUsecase {
  const PredictGoalCompletionUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalCompletionPrediction> call() {
    final DateTime now = DateTime.now();

    return _repository
        .getGoals()
        .map((GoalEntity goal) {
          final DateTime? targetDate = goal.targetDate;
          final double confidence;

          if (targetDate == null) {
            confidence = 0.35;
          } else if (targetDate.isBefore(now)) {
            confidence = 0.25;
          } else if (targetDate.difference(now).inDays <= 7) {
            confidence = 0.65;
          } else {
            confidence = 0.75;
          }

          return GoalCompletionPrediction(
            goal: goal,
            predictedDate: targetDate,
            confidence: confidence,
          );
        })
        .toList(growable: false);
  }
}
