import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/create_goal_category_usecase.dart';

class DeleteGoalCategoryUsecase {
  const DeleteGoalCategoryUsecase();

  GoalCategoryConfig call(GoalCategoryConfig category) {
    return GoalCategoryConfig(
      id: category.id,
      name: category.name,
      description: category.description,
      createdAt: category.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: DateTime.now(),
    );
  }
}
