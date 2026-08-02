import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/create_goal_category_usecase.dart';

class UpdateGoalCategoryUsecase {
  const UpdateGoalCategoryUsecase();

  GoalCategoryConfig call({
    required GoalCategoryConfig category,
    String? name,
    String? description,
  }) {
    return GoalCategoryConfig(
      id: category.id,
      name: name?.trim().isEmpty ?? true ? category.name : name!.trim(),
      description: description?.trim().isEmpty ?? true
          ? category.description
          : description!.trim(),
      createdAt: category.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: category.deletedAt,
    );
  }
}
