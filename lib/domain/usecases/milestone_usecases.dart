// CHRONOSPARK-CLASS: SHIPPING | Feature: Milestones
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_milestone_repository.dart';

class GetMilestones {
  const GetMilestones(this._repository);

  final IMilestoneRepository _repository;

  Future<List<MilestoneEntity>> call() => _repository.getMilestones();
}

class CreateMilestone {
  const CreateMilestone(this._repository);

  final IMilestoneRepository _repository;

  Future<MilestoneEntity?> call({
    required String title,
    String? description,
    String? goalId,
    String? projectId,
    String? habitId,
    MilestoneCategory category = MilestoneCategory.other,
    MilestonePriority priority = MilestonePriority.medium,
    DateTime? targetDate,
    String? reward,
    String? note,
    DateTime? reminderAt,
    List<String> dependencies = const <String>[],
    String? id,
    DateTime? now,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final DateTime timestamp = now ?? DateTime.now();
    final MilestoneEntity milestone = MilestoneEntity(
      id: id ?? timestamp.microsecondsSinceEpoch.toString(),
      goalId: goalId,
      projectId: projectId,
      habitId: habitId,
      title: trimmed,
      description: description?.trim(),
      category: category,
      priority: priority,
      targetDate: targetDate,
      reward: reward?.trim(),
      note: note?.trim(),
      reminderAt: reminderAt,
      dependencies: List<String>.unmodifiable(dependencies),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final List<MilestoneEntity> current = await _repository.getMilestones();
    await _repository.saveMilestones(<MilestoneEntity>[milestone, ...current]);
    return milestone;
  }
}

class UpdateMilestone {
  const UpdateMilestone(this._repository);

  final IMilestoneRepository _repository;

  Future<MilestoneEntity?> call(
    MilestoneEntity updated, {
    DateTime? now,
  }) async {
    final List<MilestoneEntity> current = await _repository.getMilestones();
    if (!current.any((MilestoneEntity item) => item.id == updated.id)) {
      return null;
    }
    final MilestoneEntity persisted = updated.copyWith(
      updatedAt: now ?? DateTime.now(),
    );
    await _repository.saveMilestones(<MilestoneEntity>[
      for (final MilestoneEntity item in current)
        if (item.id == persisted.id) persisted else item,
    ]);
    return persisted;
  }
}

class UpdateMilestoneProgress {
  const UpdateMilestoneProgress(this._repository);

  final IMilestoneRepository _repository;

  Future<MilestoneEntity?> call(
    String id,
    double completionPercent, {
    DateTime? now,
  }) async {
    final List<MilestoneEntity> current = await _repository.getMilestones();
    final int index = current.indexWhere(
      (MilestoneEntity item) => item.id == id,
    );
    if (index < 0) return null;
    final DateTime timestamp = now ?? DateTime.now();
    final double clamped = completionPercent.clamp(0, 100);
    final MilestoneEntity existing = current[index];
    final MilestoneEntity updated = existing.copyWith(
      completionPercent: clamped,
      status: clamped >= 100
          ? MilestoneStatus.completed
          : existing.isOverdue
          ? MilestoneStatus.overdue
          : MilestoneStatus.inProgress,
      completedAt: clamped >= 100 ? timestamp : existing.completedAt,
      updatedAt: timestamp,
    );
    final List<MilestoneEntity> next = current.toList(growable: true);
    next[index] = updated;
    await _repository.saveMilestones(next);
    return updated;
  }
}

class CompleteMilestone {
  const CompleteMilestone(this._repository);

  final IMilestoneRepository _repository;

  Future<MilestoneEntity?> call(
    String id, {
    String? reflection,
    DateTime? now,
  }) async {
    final List<MilestoneEntity> current = await _repository.getMilestones();
    final int index = current.indexWhere(
      (MilestoneEntity item) => item.id == id,
    );
    if (index < 0) return null;
    final DateTime timestamp = now ?? DateTime.now();
    final MilestoneEntity completed = current[index].copyWith(
      status: MilestoneStatus.completed,
      completionPercent: 100,
      reflection: reflection?.trim() ?? current[index].reflection,
      completedAt: timestamp,
      updatedAt: timestamp,
    );
    final List<MilestoneEntity> next = current.toList(growable: true);
    next[index] = completed;
    await _repository.saveMilestones(next);
    return completed;
  }
}

class ArchiveMilestone {
  const ArchiveMilestone(this._repository);

  final IMilestoneRepository _repository;

  Future<MilestoneEntity?> call(String id, {DateTime? now}) async {
    final List<MilestoneEntity> current = await _repository.getMilestones();
    final int index = current.indexWhere(
      (MilestoneEntity item) => item.id == id,
    );
    if (index < 0) return null;
    final DateTime timestamp = now ?? DateTime.now();
    final MilestoneEntity archived = current[index].copyWith(
      status: MilestoneStatus.archived,
      archivedAt: timestamp,
      updatedAt: timestamp,
    );
    final List<MilestoneEntity> next = current.toList(growable: true);
    next[index] = archived;
    await _repository.saveMilestones(next);
    return archived;
  }
}

class DeleteMilestone {
  const DeleteMilestone(this._repository);

  final IMilestoneRepository _repository;

  Future<bool> call(String id) async {
    final List<MilestoneEntity> current = await _repository.getMilestones();
    final List<MilestoneEntity> next = current
        .where((MilestoneEntity item) => item.id != id)
        .toList(growable: false);
    if (next.length == current.length) return false;
    await _repository.saveMilestones(next);
    return true;
  }
}
