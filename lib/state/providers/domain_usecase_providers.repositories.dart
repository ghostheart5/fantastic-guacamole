part of 'domain_usecase_providers.dart';

final domainTaskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return ref.watch(taskRepositoryProvider);
});

final domainNotificationRepositoryProvider = Provider<INotificationRepository>((
  ref,
) {
  return ref.watch(notificationsRepositoryProvider);
});

final domainGoalRepositoryProvider = Provider<IGoalRepository>((ref) {
  return ref.watch(goalRepositoryProvider);
});

final domainSignalRepositoryProvider = Provider<ISignalRepository>((ref) {
  return ref.watch(signalRepositoryProvider);
});

final domainLogRepositoryProvider = Provider<ILogRepository>((ref) {
  return ref.watch(logRepositoryProvider);
});

final domainMemoryRepositoryProvider = Provider<IMemoryRepository>((ref) {
  return ref.watch(memoryRepositoryProvider);
});

final domainNoteRepositoryProvider = Provider<INoteRepository>((ref) {
  return ref.watch(noteRepositoryProvider);
});

final domainMilestoneRepositoryProvider = Provider<IMilestoneRepository>((ref) {
  return ref.watch(milestoneRepositoryProvider);
});

final domainPlanRepositoryProvider = Provider<IPlanRepository>((ref) {
  return ref.watch(planRepositoryProvider);
});

final domainProjectRepositoryProvider = Provider<IProjectRepository>((ref) {
  return ref.watch(projectRepositoryProvider);
});

final domainProfileRepositoryProvider = Provider<IProfileRepository>((ref) {
  return ref.watch(profileRepositoryProvider);
});

final domainProgressionRepositoryProvider = Provider<IProgressionRepository>((
  ref,
) {
  return ref.watch(progressionRepositoryProvider);
});

final domainRoutineRepositoryProvider = Provider<IRoutineRepository>((ref) {
  return ref.watch(routineRepositoryProvider);
});

final domainSubtaskRepositoryProvider = Provider<ISubtaskRepository>((ref) {
  return ref.watch(subtaskRepositoryProvider);
});

final domainTimelineRepositoryProvider = Provider<ITimelineRepository>((ref) {
  return ref.watch(timelineRepositoryProvider);
});

final domainThemeRepositoryProvider = Provider<IThemeRepository>((ref) {
  return ref.watch(themeRepositoryProvider);
});

final domainIdentityRepositoryProvider = Provider<IIdentityRepository>((ref) {
  return ref.watch(identityRepositoryProvider);
});

final domainSiRepositoryProvider = Provider<ISiRepository>((ref) {
  return _SiRepositoryAdapter(ref);
});

// --- Interface bindings that were previously exposed only as concrete types.
// Without these the use cases below could not be constructed at all.

final domainCalendarRepositoryProvider = Provider<ICalendarRepository>((ref) {
  return ref.watch(calendarRepositoryProvider);
});

final domainSettingsRepositoryProvider = Provider<ISettingsRepository>((ref) {
  return ref.watch(settingsRepositoryProvider);
});

final domainWorkspaceRepositoryProvider = Provider<IWorkspaceRepository>((ref) {
  return ref.watch(workspaceRepositoryProvider);
});

final domainLearningRepositoryProvider = Provider<ILearningRepository>((ref) {
  return LearningRepository(
    ref.read(secureStoreProvider),
    scope: ref.watch(accountStorageScopeProvider),
  );
});

final extendedDomainRepositoryProvider = Provider<IExtendedDomainRepository>((
  ref,
) {
  final scope = ref.watch(accountStorageScopeProvider);
  return ExtendedDomainService(
    AccountScopedSharedPrefsStore(
      delegate: ref.read(sharedPrefsStoreProvider),
      scope: scope,
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
    isCurrent: () =>
        ref.mounted && identical(ref.read(accountStorageScopeProvider), scope),
  );
});

final getPlannerMessagesUseCaseProvider = Provider<GetPlannerMessages>((ref) {
  return GetPlannerMessages(ref.watch(extendedDomainRepositoryProvider));
});

final savePlannerMessageUseCaseProvider = Provider<SavePlannerMessage>((ref) {
  return SavePlannerMessage(ref.watch(extendedDomainRepositoryProvider));
});

final getSiQueriesExtendedUseCaseProvider = Provider<GetSiQueriesExtended>((
  ref,
) {
  return GetSiQueriesExtended(ref.watch(extendedDomainRepositoryProvider));
});

final saveSiQueryExtendedUseCaseProvider = Provider<SaveSiQueryExtended>((ref) {
  return SaveSiQueryExtended(ref.watch(extendedDomainRepositoryProvider));
});

final getReflectionEntriesUseCaseProvider = Provider<GetReflectionEntries>((
  ref,
) {
  return GetReflectionEntries(ref.watch(extendedDomainRepositoryProvider));
});

final saveReflectionEntryUseCaseProvider = Provider<SaveReflectionEntry>((ref) {
  return SaveReflectionEntry(ref.watch(extendedDomainRepositoryProvider));
});

final getAnalyticsMetricsUseCaseProvider = Provider<GetAnalyticsMetrics>((ref) {
  return GetAnalyticsMetrics(ref.watch(extendedDomainRepositoryProvider));
});

final saveAnalyticsMetricUseCaseProvider = Provider<SaveAnalyticsMetric>((ref) {
  return SaveAnalyticsMetric(ref.watch(extendedDomainRepositoryProvider));
});

final getExtendedAppSettingsUseCaseProvider = Provider<GetExtendedAppSettings>((
  ref,
) {
  return GetExtendedAppSettings(ref.watch(extendedDomainRepositoryProvider));
});

final saveExtendedAppSettingUseCaseProvider = Provider<SaveExtendedAppSetting>((
  ref,
) {
  return SaveExtendedAppSetting(ref.watch(extendedDomainRepositoryProvider));
});

final extendedDomainBootstrapProvider = FutureProvider<void>((ref) async {
  final scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return;
  final IExtendedDomainRepository repository = ref.watch(
    extendedDomainRepositoryProvider,
  );
  bool isCurrent() =>
      ref.mounted && identical(ref.read(accountStorageScopeProvider), scope);

  await repository.initialize();
  if (!isCurrent()) return;

  // Keep every seed bound to this repository. Looking up a use-case provider
  // after an await could resolve the next account's repository instead.
  if (repository.getPlannerMessages().isEmpty) {
    await SavePlannerMessage(repository)(
      const PlannerMessage(
        id: 'bootstrap.planner.welcome',
        label: 'Welcome to Smart Planner',
      ),
    );
    if (!isCurrent()) return;
  }

  if (repository.getSiQueries().isEmpty) {
    await SaveSiQueryExtended(repository)(
      const SiQuery(
        id: 'bootstrap.si.query.health',
        label: 'System health check',
      ),
    );
    if (!isCurrent()) return;
  }

  if (repository.getReflectionEntries().isEmpty) {
    await SaveReflectionEntry(repository)(
      const ReflectionEntry(
        id: 'bootstrap.reflection.entry.day0',
        label: 'Getting started reflection',
      ),
    );
    if (!isCurrent()) return;
  }

  if (repository.getAnalyticsMetrics().isEmpty) {
    await SaveAnalyticsMetric(repository)(
      const AnalyticsMetric(
        id: 'bootstrap.analytics.productivity',
        label: 'Productivity baseline',
      ),
    );
    if (!isCurrent()) return;
  }

  if (repository.getSettings().isEmpty) {
    await SaveExtendedAppSetting(repository)(
      const AppSetting(
        id: 'bootstrap.settings.planner.enabled',
        label: 'Planner enabled',
      ),
    );
  }
});
