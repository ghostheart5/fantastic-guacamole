part of 'domain_usecase_providers.dart';

final getTimelineEventsUseCaseProvider = Provider<GetTimelineEvents>((ref) {
  return GetTimelineEvents(ref.watch(domainTimelineRepositoryProvider));
});

final addTimelineEventUseCaseProvider = Provider<AddTimelineEvent>((ref) {
  return AddTimelineEvent(ref.watch(domainTimelineRepositoryProvider));
});

final removeTimelineEventUseCaseProvider = Provider<RemoveTimelineEvent>((ref) {
  return RemoveTimelineEvent(ref.watch(domainTimelineRepositoryProvider));
});

final saveTimelineEventsUseCaseProvider = Provider<SaveTimelineEvents>((ref) {
  return SaveTimelineEvents(ref.watch(domainTimelineRepositoryProvider));
});

final queryTimelineRangeUseCaseProvider = Provider<QueryTimelineRange>((ref) {
  return QueryTimelineRange(ref.watch(domainTimelineRepositoryProvider));
});

final scheduleTimelineEventUseCaseProvider = Provider<ScheduleTimelineEvent>((
  ref,
) {
  return ScheduleTimelineEvent(ref.watch(domainTimelineRepositoryProvider));
});

final rescheduleTimelineEventUseCaseProvider =
    Provider<RescheduleTimelineEvent>((ref) {
      return RescheduleTimelineEvent(
        ref.watch(domainTimelineRepositoryProvider),
      );
    });

final completeTimelineEventUseCaseProvider = Provider<CompleteTimelineEvent>((
  ref,
) {
  return CompleteTimelineEvent(ref.watch(domainTimelineRepositoryProvider));
});

final skipTimelineEventUseCaseProvider = Provider<SkipTimelineEvent>((ref) {
  return SkipTimelineEvent(ref.watch(domainTimelineRepositoryProvider));
});

final recoverTimelineEventUseCaseProvider = Provider<RecoverTimelineEvent>((
  ref,
) {
  return RecoverTimelineEvent(ref.watch(domainTimelineRepositoryProvider));
});

final previewAdaptivePlanUseCaseProvider = Provider<PreviewAdaptivePlan>((ref) {
  return PreviewAdaptivePlan(
    ref.read(generateAdaptivePlanUseCaseProvider),
    ref.watch(domainPlanRepositoryProvider),
  );
});

final applyPlanProposalUseCaseProvider = Provider<ApplyPlanProposal>((ref) {
  return ApplyPlanProposal(ref.watch(domainPlanRepositoryProvider));
});

final rejectPlanProposalUseCaseProvider = Provider<RejectPlanProposal>((ref) {
  return RejectPlanProposal(ref.watch(domainPlanRepositoryProvider));
});

final createTaskUseCaseProvider = Provider<CreateTask>((ref) {
  return CreateTask(
    ref.read(domainTaskRepositoryProvider),
    generateSiDecision: ref.read(generateSiDecisionUseCaseProvider),
  );
});

final completeTaskUseCaseProvider = Provider<CompleteTask>((ref) {
  return CompleteTask(
    ref.read(domainTaskRepositoryProvider),
    progressionRepo: ref.watch(domainProgressionRepositoryProvider),
    siRepo: ref.read(domainSiRepositoryProvider),
    durableMutation: (String taskId) async {
      final TaskOccurrenceResult result = await ref
          .read(taskOccurrenceCoordinatorProvider)
          .complete(taskId);
      switch (result.mutation) {
        case TaskOccurrenceMutation.applied:
          return CompletionMutationOutcome.applied;
        case TaskOccurrenceMutation.idempotent:
          return CompletionMutationOutcome.idempotent;
        case TaskOccurrenceMutation.conflict:
          return CompletionMutationOutcome.conflict;
      }
    },
  );
});

final updateTaskUseCaseProvider = Provider<UpdateTask>((ref) {
  return UpdateTask(ref.read(domainTaskRepositoryProvider));
});

final deleteTaskUseCaseProvider = Provider<DeleteTask>((ref) {
  return DeleteTask(ref.read(domainTaskRepositoryProvider));
});

final scheduleNotificationUseCaseProvider = Provider<ScheduleNotification>((
  ref,
) {
  return ScheduleNotification(
    ref.watch(domainNotificationRepositoryProvider),
    generateSiDecision: ref.read(generateSiDecisionUseCaseProvider),
  );
});

final cancelNotificationUseCaseProvider = Provider<CancelNotification>((ref) {
  return CancelNotification(ref.watch(domainNotificationRepositoryProvider));
});
