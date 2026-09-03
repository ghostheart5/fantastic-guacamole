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
  return ref.read(themeRepositoryProvider);
});

final domainIdentityRepositoryProvider = Provider<IIdentityRepository>((ref) {
  return ref.read(identityRepositoryProvider);
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
  return ref.read(settingsRepositoryProvider);
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
  return ExtendedDomainService(
    AccountScopedSharedPrefsStore(
      delegate: ref.read(sharedPrefsStoreProvider),
      scope: ref.watch(accountStorageScopeProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
  );
});

final getPlannerMessagesUseCaseProvider = Provider<GetPlannerMessages>((ref) {
  return GetPlannerMessages(ref.read(extendedDomainRepositoryProvider));
});

final savePlannerMessageUseCaseProvider = Provider<SavePlannerMessage>((ref) {
  return SavePlannerMessage(ref.read(extendedDomainRepositoryProvider));
});

final getSiQueriesExtendedUseCaseProvider = Provider<GetSiQueriesExtended>((
  ref,
) {
  return GetSiQueriesExtended(ref.read(extendedDomainRepositoryProvider));
});

final saveSiQueryExtendedUseCaseProvider = Provider<SaveSiQueryExtended>((ref) {
  return SaveSiQueryExtended(ref.read(extendedDomainRepositoryProvider));
});

final getReflectionEntriesUseCaseProvider = Provider<GetReflectionEntries>((
  ref,
) {
  return GetReflectionEntries(ref.read(extendedDomainRepositoryProvider));
});

final saveReflectionEntryUseCaseProvider = Provider<SaveReflectionEntry>((ref) {
  return SaveReflectionEntry(ref.read(extendedDomainRepositoryProvider));
});

final getAnalyticsMetricsUseCaseProvider = Provider<GetAnalyticsMetrics>((ref) {
  return GetAnalyticsMetrics(ref.read(extendedDomainRepositoryProvider));
});

final saveAnalyticsMetricUseCaseProvider = Provider<SaveAnalyticsMetric>((ref) {
  return SaveAnalyticsMetric(ref.read(extendedDomainRepositoryProvider));
});

final getExtendedAppSettingsUseCaseProvider = Provider<GetExtendedAppSettings>((
  ref,
) {
  return GetExtendedAppSettings(ref.read(extendedDomainRepositoryProvider));
});

final saveExtendedAppSettingUseCaseProvider = Provider<SaveExtendedAppSetting>((
  ref,
) {
  return SaveExtendedAppSetting(ref.read(extendedDomainRepositoryProvider));
});

final extendedDomainBootstrapProvider = FutureProvider<void>((ref) async {
  final IExtendedDomainRepository repository = ref.read(
    extendedDomainRepositoryProvider,
  );
  await repository.initialize();

  if (repository.getPlannerMessages().isEmpty) {
    await ref
        .read(savePlannerMessageUseCaseProvider)
        .call(
          const PlannerMessage(
            id: 'bootstrap.planner.welcome',
            label: 'Welcome to Smart Planner',
          ),
        );
  }

  if (repository.getSiQueries().isEmpty) {
    await ref
        .read(saveSiQueryExtendedUseCaseProvider)
        .call(
          const SiQuery(
            id: 'bootstrap.si.query.health',
            label: 'System health check',
          ),
        );
  }

  if (repository.getReflectionEntries().isEmpty) {
    await ref
        .read(saveReflectionEntryUseCaseProvider)
        .call(
          const ReflectionEntry(
            id: 'bootstrap.reflection.entry.day0',
            label: 'Getting started reflection',
          ),
        );
  }

  if (repository.getAnalyticsMetrics().isEmpty) {
    await ref
        .read(saveAnalyticsMetricUseCaseProvider)
        .call(
          const AnalyticsMetric(
            id: 'bootstrap.analytics.productivity',
            label: 'Productivity baseline',
          ),
        );
  }

  if (repository.getSettings().isEmpty) {
    await ref
        .read(saveExtendedAppSettingUseCaseProvider)
        .call(
          const AppSetting(
            id: 'bootstrap.settings.planner.enabled',
            label: 'Planner enabled',
          ),
        );
  }
});
