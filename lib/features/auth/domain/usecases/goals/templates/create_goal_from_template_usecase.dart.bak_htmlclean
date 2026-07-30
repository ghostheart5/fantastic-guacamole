import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/template_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class CreateGoalFromTemplateUsecase {
  const CreateGoalFromTemplateUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call(
    TemplateEntity template, {
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = GoalEntity(
      id: 'goal_${DateTime.now().microsecondsSinceEpoch}',
      title: template.name,
      description: template.description,
      createdAt: DateTime.now(),
      targetDate: targetDate,
    );

    await _repository.saveGoal(goal);

    return goal;
  }
}
