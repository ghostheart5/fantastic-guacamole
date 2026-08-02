import 'dart:convert';

import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class BackupGoalsUsecase {
  const BackupGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  String call() {
    final goals = _repository.getGoals();

    return jsonEncode(
      goals.map((goal) => goal.toJson()).toList(growable: false),
    );
  }
}
