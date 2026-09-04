part of 'domain_usecase_providers.dart';

final getNotesUseCaseProvider = Provider<GetNotes>((ref) {
  return GetNotes(ref.watch(domainNoteRepositoryProvider));
});

final createNoteUseCaseProvider = Provider<CreateNote>((ref) {
  return CreateNote(ref.watch(domainNoteRepositoryProvider));
});

final updateNoteUseCaseProvider = Provider<UpdateNote>((ref) {
  return UpdateNote(ref.watch(domainNoteRepositoryProvider));
});

final archiveNoteUseCaseProvider = Provider<ArchiveNote>((ref) {
  return ArchiveNote(ref.watch(domainNoteRepositoryProvider));
});

final deleteNoteUseCaseProvider = Provider<DeleteNote>((ref) {
  return DeleteNote(ref.watch(domainNoteRepositoryProvider));
});

final getMilestonesUseCaseProvider = Provider<GetMilestones>((ref) {
  return GetMilestones(ref.watch(domainMilestoneRepositoryProvider));
});

final createMilestoneUseCaseProvider = Provider<CreateMilestone>((ref) {
  return CreateMilestone(ref.watch(domainMilestoneRepositoryProvider));
});

final updateMilestoneUseCaseProvider = Provider<UpdateMilestone>((ref) {
  return UpdateMilestone(ref.watch(domainMilestoneRepositoryProvider));
});

final updateMilestoneProgressUseCaseProvider =
    Provider<UpdateMilestoneProgress>((ref) {
      return UpdateMilestoneProgress(
        ref.watch(domainMilestoneRepositoryProvider),
      );
    });

final completeMilestoneUseCaseProvider = Provider<CompleteMilestone>((ref) {
  return CompleteMilestone(ref.watch(domainMilestoneRepositoryProvider));
});

final archiveMilestoneUseCaseProvider = Provider<ArchiveMilestone>((ref) {
  return ArchiveMilestone(ref.watch(domainMilestoneRepositoryProvider));
});

final deleteMilestoneUseCaseProvider = Provider<DeleteMilestone>((ref) {
  return DeleteMilestone(ref.watch(domainMilestoneRepositoryProvider));
});

final generateSiDecisionUseCaseProvider = Provider<GenerateSiDecision>((ref) {
  return GenerateSiDecision(
    ref.read(domainTaskRepositoryProvider),
    ref.read(domainSiRepositoryProvider),
  );
});

final domainSiDecisionProvider = FutureProvider<Task?>((ref) async {
  final SiDecisionEntity decision = await ref
      .read(generateSiDecisionUseCaseProvider)
      .call();
  final String? selectedTaskId = decision.selectedTaskId;
  if (selectedTaskId == null || selectedTaskId.isEmpty) {
    return null;
  }

  final TaskEntity? task = await ref
      .read(domainTaskRepositoryProvider)
      .getTaskById(selectedTaskId);
  return task == null ? null : _taskFromEntity(task);
});

Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
    scheduledFor: task.scheduledFor,
    dueDate: task.dueDate,
    estimatedDuration: task.estimatedDuration ?? const Duration(minutes: 30),
    isCompleted: task.isCompleted,
    isCanceled: task.isCanceled,
    completedAt: task.completedAt,
    goalId: task.goalId,
    subtasks: task.subtasks,
    recurrenceRule: task.recurrenceRule,
  );
}

class _SiRepositoryAdapter implements ISiRepository {
  _SiRepositoryAdapter(this._ref);

  final Ref _ref;

  @override
  Future<SiStateEntity?> getCurrentState() async {
    final SIState state = _ref.read(siStateProvider);
    return SiStateEntity(
      energy: state.energy,
      attention: (state.energy * (1 - state.fatigue)).clamp(0.0, 1.0),
      fatigue: state.fatigue,
    );
  }

  @override
  Future<void> saveState(SiStateEntity state) async {
    _ref
        .read(siStateProvider.notifier)
        .replaceState(energy: state.energy, fatigue: state.fatigue);
  }
}
