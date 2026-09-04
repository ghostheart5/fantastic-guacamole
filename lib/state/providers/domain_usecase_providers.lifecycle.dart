part of 'domain_usecase_providers.dart';

final domainHabitRepositoryProvider = Provider<IHabitRepository>((ref) {
  return ref.watch(habitRepositoryProvider);
});

final getHabitsUseCaseProvider = Provider<GetHabits>((ref) {
  return GetHabits(ref.watch(domainHabitRepositoryProvider));
});

final createHabitUseCaseProvider = Provider<CreateHabit>((ref) {
  return CreateHabit(ref.watch(domainHabitRepositoryProvider));
});

final toggleHabitUseCaseProvider = Provider<ToggleHabit>((ref) {
  return ToggleHabit(ref.watch(domainHabitRepositoryProvider));
});

final updateHabitUseCaseProvider = Provider<UpdateHabit>((ref) {
  return UpdateHabit(ref.watch(domainHabitRepositoryProvider));
});

final deleteHabitUseCaseProvider = Provider<DeleteHabit>((ref) {
  return DeleteHabit(ref.watch(domainHabitRepositoryProvider));
});

final saveHabitsUseCaseProvider = Provider<SaveHabits>((ref) {
  return SaveHabits(ref.watch(domainHabitRepositoryProvider));
});

final getProfileUseCaseProvider = Provider<GetProfile>((ref) {
  return GetProfile(ref.watch(domainProfileRepositoryProvider));
});

final getProgressionUseCaseProvider = Provider<GetProgression>((ref) {
  return GetProgression(ref.watch(domainProgressionRepositoryProvider));
});

final updateStreakUseCaseProvider = Provider<UpdateStreak>((ref) {
  return UpdateStreak(ref.watch(domainProgressionRepositoryProvider));
});

final updateXpUseCaseProvider = Provider<UpdateXp>((ref) {
  return UpdateXp(ref.watch(domainProgressionRepositoryProvider));
});

final updateLevelUseCaseProvider = Provider<UpdateLevel>((ref) {
  return UpdateLevel(ref.watch(domainProgressionRepositoryProvider));
});

/// The single persisted XP-award path. Prefer this over [updateXpUseCaseProvider],
/// which sets XP absolutely and exists for restore/import only.
final awardXpUseCaseProvider = Provider<AwardXp>((ref) {
  return AwardXp(ref.watch(domainProgressionRepositoryProvider));
});

/// Level/progress read model derived from [ProgressionPolicy].
final getUserLevelUseCaseProvider = Provider<GetUserLevel>((ref) {
  return GetUserLevel();
});

// --- Settings and workspace.

final getSettingsUseCaseProvider = Provider<GetSettings>((ref) {
  return GetSettings(ref.read(domainSettingsRepositoryProvider));
});

final updateSettingsUseCaseProvider = Provider<UpdateSettings>((ref) {
  return UpdateSettings(ref.read(domainSettingsRepositoryProvider));
});

final getWorkspaceUseCaseProvider = Provider<GetWorkspace>((ref) {
  return GetWorkspace(ref.watch(domainWorkspaceRepositoryProvider));
});

final switchWorkspaceUseCaseProvider = Provider<SwitchWorkspace>((ref) {
  return SwitchWorkspace(ref.watch(domainWorkspaceRepositoryProvider));
});

// --- Calendar (domain path).

final getCalendarEntriesUseCaseProvider = Provider<GetCalendarEntries>((ref) {
  return GetCalendarEntries(ref.watch(domainCalendarRepositoryProvider));
});

final addCalendarEntryUseCaseProvider = Provider<AddCalendarEntry>((ref) {
  return AddCalendarEntry(ref.watch(domainCalendarRepositoryProvider));
});

final removeCalendarEntryUseCaseProvider = Provider<RemoveCalendarEntry>((ref) {
  return RemoveCalendarEntry(ref.watch(domainCalendarRepositoryProvider));
});

// --- SI state.

final hydrateSiStateUseCaseProvider = Provider<HydrateSiState>((ref) {
  return HydrateSiState(ref.read(domainSiRepositoryProvider));
});

final updateSiStateUseCaseProvider = Provider<UpdateSiState>((ref) {
  return UpdateSiState(ref.read(domainSiRepositoryProvider));
});

// --- Learning loop.
//
// SHIPPING: task completion, task skip, and decision-outcome recording invoke
// the bound learning path. UpdateLearningState remains registered for explicit
// callers but is not currently reached by a production surface.

final applyLearningFeedbackUseCaseProvider = Provider<ApplyLearningFeedback>((
  ref,
) {
  return ApplyLearningFeedback(
    ref.read(domainLearningRepositoryProvider),
    siRepo: ref.read(domainSiRepositoryProvider),
  );
});

final updateLearningStateUseCaseProvider = Provider<UpdateLearningState>((ref) {
  return UpdateLearningState(ref.read(domainLearningRepositoryProvider));
});

final skipTaskUseCaseProvider = Provider<SkipTask>((ref) {
  return SkipTask(
    ref.read(domainTaskRepositoryProvider),
    ref.read(domainLearningRepositoryProvider),
    siRepo: ref.read(domainSiRepositoryProvider),
  );
});
