import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creatorActionsProvider = Provider<CreatorActions>(
  (ref) =>
      CreatorActions(repo: ref.read(domainTaskRepositoryProvider), ref: ref),
);

class CreatorActions {
  const CreatorActions({required this.repo, required this.ref});

  final ITaskRepository repo;
  final Ref ref;

  Future<void> createTask(DynamicFormData data) async {
    final entity = TaskEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: data.title,
      description: data.description,
      createdAt: DateTime.now(),
      priority: data.priority,
      difficulty: 3,
      energyRequired: 3,
      scheduledFor: data.scheduledFor,
    );
    await repo.saveTask(entity);
    ref.invalidate(tasksProvider);
  }
}
