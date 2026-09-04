part of 'domain_usecase_providers.dart';

final plannerMessagesProvider = Provider<List<PlannerMessage>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.read(getPlannerMessagesUseCaseProvider).call();
});

final siQueriesProvider = Provider<List<SiQuery>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.read(getSiQueriesExtendedUseCaseProvider).call();
});

final reflectionEntriesProvider = Provider<List<ReflectionEntry>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.read(getReflectionEntriesUseCaseProvider).call();
});

final analyticsMetricsProvider = Provider<List<AnalyticsMetric>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.read(getAnalyticsMetricsUseCaseProvider).call();
});

final appSettingsProvider = Provider<List<AppSetting>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.read(getExtendedAppSettingsUseCaseProvider).call();
});

final getTasksUseCaseProvider = Provider<GetTasks>((ref) {
  return GetTasks(ref.watch(domainTaskRepositoryProvider));
});

final getGoalsUseCaseProvider = Provider<GetGoals>((ref) {
  return GetGoals(ref.watch(domainGoalRepositoryProvider));
});

final getSignalsUseCaseProvider = Provider<GetSignals>((ref) {
  return GetSignals(ref.watch(domainSignalRepositoryProvider));
});

final addSignalUseCaseProvider = Provider<AddSignal>((ref) {
  return AddSignal(ref.watch(domainSignalRepositoryProvider));
});

final generateSignalFromEventUseCaseProvider =
    Provider<GenerateSignalFromEvent>((ref) {
      return GenerateSignalFromEvent(ref.watch(domainSignalRepositoryProvider));
    });

final getLogsUseCaseProvider = Provider<GetLogs>((ref) {
  return GetLogs(ref.watch(domainLogRepositoryProvider));
});

final addLogEntryUseCaseProvider = Provider<AddLogEntry>((ref) {
  return AddLogEntry(ref.watch(domainLogRepositoryProvider));
});

final getCurrentThemeUseCaseProvider = Provider<GetCurrentTheme>((ref) {
  return GetCurrentTheme(ref.read(domainThemeRepositoryProvider));
});

final saveThemeUseCaseProvider = Provider<SaveTheme>((ref) {
  return SaveTheme(ref.read(domainThemeRepositoryProvider));
});

final getAllThemesUseCaseProvider = Provider<GetAllThemes>((ref) {
  return GetAllThemes(ref.read(domainThemeRepositoryProvider));
});

final switchThemeUseCaseProvider = Provider<SwitchTheme>((ref) {
  return SwitchTheme(ref.read(domainThemeRepositoryProvider));
});

final getIdentityProfileUseCaseProvider = Provider<GetIdentityProfile>((ref) {
  return GetIdentityProfile(ref.read(domainIdentityRepositoryProvider));
});

final saveIdentityProfileUseCaseProvider = Provider<SaveIdentityProfile>((ref) {
  return SaveIdentityProfile(ref.read(domainIdentityRepositoryProvider));
});

final createGoalUseCaseProvider = Provider<CreateGoal>((ref) {
  return CreateGoal(ref.watch(domainGoalRepositoryProvider));
});

final updateGoalUseCaseProvider = Provider<UpdateGoal>((ref) {
  return UpdateGoal(ref.watch(domainGoalRepositoryProvider));
});

final deleteGoalUseCaseProvider = Provider<DeleteGoal>((ref) {
  return DeleteGoal(ref.watch(domainGoalRepositoryProvider));
});

final completeGoalUseCaseProvider = Provider<CompleteGoal>((ref) {
  return CompleteGoal(ref.watch(domainGoalRepositoryProvider));
});

final saveGoalsUseCaseProvider = Provider<SaveGoals>((ref) {
  return SaveGoals(ref.watch(domainGoalRepositoryProvider));
});

final getProjectsUseCaseProvider = Provider<GetProjects>((ref) {
  return GetProjects(ref.watch(domainProjectRepositoryProvider));
});

final createProjectUseCaseProvider = Provider<CreateProject>((ref) {
  return CreateProject(ref.watch(domainProjectRepositoryProvider));
});

final updateProjectUseCaseProvider = Provider<UpdateProject>((ref) {
  return UpdateProject(ref.watch(domainProjectRepositoryProvider));
});

final deleteProjectUseCaseProvider = Provider<DeleteProject>((ref) {
  return DeleteProject(ref.watch(domainProjectRepositoryProvider));
});

final saveProjectsUseCaseProvider = Provider<SaveProjects>((ref) {
  return SaveProjects(ref.watch(domainProjectRepositoryProvider));
});

final getRoutinesUseCaseProvider = Provider<GetRoutines>((ref) {
  return GetRoutines(ref.watch(domainRoutineRepositoryProvider));
});

final createRoutineUseCaseProvider = Provider<CreateRoutine>((ref) {
  return CreateRoutine(ref.watch(domainRoutineRepositoryProvider));
});

final updateRoutineUseCaseProvider = Provider<UpdateRoutine>((ref) {
  return UpdateRoutine(ref.watch(domainRoutineRepositoryProvider));
});

final deleteRoutineUseCaseProvider = Provider<DeleteRoutine>((ref) {
  return DeleteRoutine(ref.watch(domainRoutineRepositoryProvider));
});

final saveRoutinesUseCaseProvider = Provider<SaveRoutines>((ref) {
  return SaveRoutines(ref.watch(domainRoutineRepositoryProvider));
});

final getSubtasksUseCaseProvider = Provider<GetSubtasks>((ref) {
  return GetSubtasks(ref.watch(domainSubtaskRepositoryProvider));
});

final createSubtaskUseCaseProvider = Provider<CreateSubtask>((ref) {
  return CreateSubtask(ref.watch(domainSubtaskRepositoryProvider));
});

final updateSubtaskUseCaseProvider = Provider<UpdateSubtask>((ref) {
  return UpdateSubtask(ref.watch(domainSubtaskRepositoryProvider));
});

final deleteSubtaskUseCaseProvider = Provider<DeleteSubtask>((ref) {
  return DeleteSubtask(ref.watch(domainSubtaskRepositoryProvider));
});

final saveSubtasksUseCaseProvider = Provider<SaveSubtasks>((ref) {
  return SaveSubtasks(ref.watch(domainSubtaskRepositoryProvider));
});

final getMemoriesUseCaseProvider = Provider<GetMemories>((ref) {
  return GetMemories(ref.watch(domainMemoryRepositoryProvider));
});

final saveMemoryUseCaseProvider = Provider<SaveMemory>((ref) {
  return SaveMemory(ref.watch(domainMemoryRepositoryProvider));
});

final deleteMemoryUseCaseProvider = Provider<DeleteMemory>((ref) {
  return DeleteMemory(ref.watch(domainMemoryRepositoryProvider));
});

final saveMemoriesUseCaseProvider = Provider<SaveMemories>((ref) {
  return SaveMemories(ref.watch(domainMemoryRepositoryProvider));
});

final getPlanUseCaseProvider = Provider<GetPlan>((ref) {
  return GetPlan(ref.watch(domainPlanRepositoryProvider));
});

final createPlanUseCaseProvider = Provider<CreatePlan>((ref) {
  return CreatePlan(ref.watch(domainPlanRepositoryProvider));
});

final updatePlanUseCaseProvider = Provider<UpdatePlan>((ref) {
  return UpdatePlan(ref.watch(domainPlanRepositoryProvider));
});

// --- Smart Planner: shipping path ----------------------------------------
// These wrap the engine rules rather than reimplementing them, giving the
// shipping planner a domain surface. The persisted-plan use cases above stay a
// separate path with no consumer.

final generateAdaptivePlanUseCaseProvider = Provider<GenerateAdaptivePlan>((
  ref,
) {
  return GenerateAdaptivePlan(ref.read(calendarServiceProvider));
});

final analyzePlanContextUseCaseProvider = Provider<AnalyzePlanContext>((ref) {
  return const AnalyzePlanContext();
});

final recommendNextBlockUseCaseProvider = Provider<RecommendNextBlock>((ref) {
  return const RecommendNextBlock();
});

final scoreTasksUseCaseProvider = Provider<ScoreTasks>((ref) {
  return const ScoreTasks(TaskRanker());
});

// --- SI Console ------------------------------------------------------------

final extractSiSignalsUseCaseProvider = Provider<ExtractSiSignals>((ref) {
  return const ExtractSiSignals();
});

final assembleSiContextUseCaseProvider = Provider<AssembleSiContext>((ref) {
  return const AssembleSiContext(DefaultAssistantContextBuilder());
});

final assembleSiDecisionOutputUseCaseProvider =
    Provider<AssembleSiDecisionOutput>((ref) {
      return const AssembleSiDecisionOutput();
    });

// --- Habits ---------------------------------------------------------------
// Habits previously went straight from provider to repository, unlike every
// other CRUD surface. These give it the same domain path.
