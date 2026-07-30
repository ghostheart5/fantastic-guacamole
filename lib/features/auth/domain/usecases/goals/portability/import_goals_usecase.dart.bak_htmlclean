import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ImportGoalsUsecase {
  const ImportGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  Future<List<GoalEntity>> call(String jsonPayload) async {
    final dynamic decoded = jsonDecode(jsonPayload);

    final List<GoalEntity> goals = (decoded as List<dynamic>)
        .map((item) => GoalEntity.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    await _repository.saveGoals(goals);

    return goals;
  }
}
