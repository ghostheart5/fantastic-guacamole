class GoalCategoryConfig {
  const GoalCategoryConfig({
    required this.id,
    required this.name,
    required this.createdAt,
    this.description,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get deleted => deletedAt != null;
}

class CreateGoalCategoryUsecase {
  const CreateGoalCategoryUsecase();

  GoalCategoryConfig call({required String name, String? description}) {
    final DateTime now = DateTime.now();

    return GoalCategoryConfig(
      id: 'goal_category_${now.microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Goal Category' : name.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      createdAt: now,
    );
  }
}
