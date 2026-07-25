import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/template_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class SaveGoalAsTemplateUsecase {
  const SaveGoalAsTemplateUsecase(this._repository);

  final IGoalRepository _repository;

  TemplateEntity? call(String goalId) {
    GoalEntity? goal;

    for (final GoalEntity item in _repository.getGoals()) {
      if (item.id == goalId.trim()) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return null;
    }

    return TemplateEntity(
      id: 'goal_template_${goal.id}',
      name: goal.title,
      description: goal.description,
      createdAt: DateTime.now(),
      blockIds: <String>[goal.id],
    );
  }
}
