import 'dart:convert';

import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ExportGoalsUsecase {
  const ExportGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  String call() {
    final goals = _repository.getGoals();

    return const JsonEncoder.withIndent(
      '  ',
    ).convert(goals.map((goal) => goal.toJson()).toList(growable: false));
  }
}
