part of 'settings_screen.dart';

class _ReflectionReminderSection extends ConsumerStatefulWidget {
  const _ReflectionReminderSection();

  @override
  ConsumerState<_ReflectionReminderSection> createState() => _ReflectionReminderSectionState();
}

class _DailyReflectionTutorialPanel extends ConsumerWidget {
  const _DailyReflectionTutorialPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);
    final TutorialStepContent step = TutorialContent.steps.firstWhere(
      (TutorialStepContent content) => content.id == 'daily_reflection',
      orElse: () => TutorialContent.steps.first,
    );

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (progress) {
        if (progress.isStepCompleted(step.id)) {
          return const SizedBox.shrink();
        }

        if (progress.isStepDismissed(step.id)) {
          return Align(
            alignment: Alignment.centerLeft,
            child: ShowMeAgainButton(stepId: step.id, label: 'Show Reflection Tutorial Again'),
          );
        }

        return MicroTutorialCard(
          step: step,
          onComplete: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
          onDismiss: () {
            ref.read(tutorialProgressProvider.notifier).markIntroSeen();
          },
        );
      },
    );
  }
}

class _ReflectionReminderSectionState extends ConsumerState<_ReflectionReminderSection> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ReflectionReminderPrefs prefs = ref
        .read(settingsUiActionsProvider)
        .loadReflectionReminderPrefs();
    setState(() {
      _enabled = prefs.enabled;
      _time = prefs.time;
    });
  }

  Future<void> _toggle(bool value) async {
    final bool enabled = await ref
        .read(settingsUiActionsProvider)
        .setReflectionReminderEnabled(enabled: value, time: _time);
    if (!mounted) {
      return;
    }
    setState(() => _enabled = enabled);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.neonViolet,
            onPrimary: Colors.white,
            surface: Color(0xFF0B111C),
            onSurface: Colors.white70,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    await ref.read(settingsUiActionsProvider).setReflectionReminderTime(time: picked);
    if (_enabled) {
      await ref
          .read(settingsUiActionsProvider)
          .setReflectionReminderEnabled(enabled: true, time: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'DAILY REFLECTION',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          _NeonToggleTile(title: 'Reflection Reminder', value: _enabled, onChanged: _toggle),
          if (_enabled)
            GestureDetector(
              onTap: _pickTime,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Time',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _time.format(context),
                        style: const TextStyle(
                          color: AppColors.neonViolet,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReminderAutomationSection extends ConsumerStatefulWidget {
  const _ReminderAutomationSection();

  @override
  ConsumerState<_ReminderAutomationSection> createState() => _ReminderAutomationSectionState();
}

class _ReminderAutomationSectionState extends ConsumerState<_ReminderAutomationSection> {
  bool _goalEnabled = true;
  bool _habitEnabled = true;
  bool _dailyPlanningEnabled = true;
  TimeOfDay _dailyPlanningTime = const TimeOfDay(hour: 7, minute: 30);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final prefs = ref.read(settingsUiActionsProvider).loadAdvancedReminderPrefs();
    setState(() {
      _goalEnabled = prefs.goalRemindersEnabled;
      _habitEnabled = prefs.habitRemindersEnabled;
      _dailyPlanningEnabled = prefs.dailyPlanningEnabled;
      _dailyPlanningTime = TimeOfDay(
        hour: prefs.dailyPlanningHour,
        minute: prefs.dailyPlanningMinute,
      );
    });
  }

  Future<void> _toggleGoal(bool value) async {
    await ref.read(settingsUiActionsProvider).setGoalRemindersEnabled(value);
    if (!mounted) return;
    setState(() => _goalEnabled = value);
  }

  Future<void> _toggleHabit(bool value) async {
    await ref.read(settingsUiActionsProvider).setHabitRemindersEnabled(value);
    if (!mounted) return;
    setState(() => _habitEnabled = value);
  }

  Future<void> _toggleDailyPlanning(bool value) async {
    await ref
        .read(settingsUiActionsProvider)
        .setDailyPlanningReminder(enabled: value, time: _dailyPlanningTime);
    if (!mounted) return;
    setState(() => _dailyPlanningEnabled = value);
  }

  Future<void> _pickDailyPlanningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyPlanningTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.neonCyan,
            onPrimary: Colors.white,
            surface: Color(0xFF0B111C),
            onSurface: Colors.white70,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _dailyPlanningTime = picked);
    await ref
        .read(settingsUiActionsProvider)
        .setDailyPlanningReminder(enabled: _dailyPlanningEnabled, time: picked);
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'REMINDER AUTOMATION',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          _NeonToggleTile(title: 'Goal Reminders', value: _goalEnabled, onChanged: _toggleGoal),
          const _NeonStatusTile(
            title: 'Goal Reminder Rule',
            subtitle: 'Schedules around target date (prefers 1 day before).',
          ),
          TutorialTarget(
            id: 'settings.habit_toggle',
            child: _NeonToggleTile(
              title: 'Habit Reminders',
              value: _habitEnabled,
              onChanged: _toggleHabit,
            ),
          ),
          const _NeonStatusTile(
            title: 'Habit Reminder Rule',
            subtitle: 'Schedules daily cadence for the first active habit.',
          ),
          _NeonToggleTile(
            title: 'Daily Planning Reminder',
            value: _dailyPlanningEnabled,
            onChanged: _toggleDailyPlanning,
          ),
          const _NeonStatusTile(
            title: 'Daily Planning Rule',
            subtitle: 'Triggers once each day at the selected planning time.',
          ),
          if (_dailyPlanningEnabled)
            GestureDetector(
              onTap: _pickDailyPlanningTime,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Planning Time',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _dailyPlanningTime.format(context),
                        style: const TextStyle(
                          color: AppColors.neonCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChronoSparkAcademySection extends StatelessWidget {
  const _ChronoSparkAcademySection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'CHRONOSPARK ACADEMY',
      accentColor: AppColors.memoryAmber,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Interactive lessons are always available here.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
          ...TutorialContent.academyTracks.map(
            (AcademyTrack track) => _NeonStatusTile(
              title: track.title,
              subtitle: track.lessons.map((AcademyLesson lesson) => lesson.title).join(' · '),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'FIRST WEEK GUIDED JOURNEY',
                style: TextStyle(
                  color: AppColors.memoryAmber,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ...TutorialContent.firstWeekJourney.map(
            (FirstWeekJourneyDay day) => _NeonStatusTile(title: day.day, subtitle: day.goal),
          ),
        ],
      ),
    );
  }
}

class _GlobalMetricsDebugSection extends ConsumerWidget {
  const _GlobalMetricsDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(optimizationConfigProvider);
    final metricsRealtimeAsync = ref.watch(supabaseMetricsRealtimeProvider);
    return _Section(
      label: 'GLOBAL OPTIMIZER',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          configAsync.when(
            data: (config) => Column(
              children: [
                _NeonStatusTile(
                  title: 'Focus Duration Multiplier',
                  subtitle: config.focusDurationMultiplier.toStringAsFixed(2),
                ),
                _NeonStatusTile(
                  title: 'Task Difficulty Scale',
                  subtitle: config.taskDifficultyScale.toStringAsFixed(2),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _NeonStatusTile(title: 'Optimizer Error', subtitle: e.toString()),
          ),
          metricsRealtimeAsync.when(
            data: (rows) {
              final String latestDate = rows.isEmpty
                  ? 'n/a'
                  : rows.last['date']?.toString() ?? 'unknown';
              return Column(
                children: [
                  _NeonStatusTile(title: 'Realtime Rows', subtitle: '${rows.length} streamed'),
                  _NeonStatusTile(title: 'Latest Row Date', subtitle: latestDate),
                ],
              );
            },
            loading: () => const _NeonStatusTile(
              title: 'Realtime Rows',
              subtitle: 'Connecting to Supabase stream...',
            ),
            error: (error, _) =>
                _NeonStatusTile(title: 'Realtime Error', subtitle: error.toString()),
          ),
          _NeonNavTile(
            title: 'Refresh Global Metrics',
            subtitle: 'Fetches latest aggregate data from Supabase',
            onTap: () {
              ref.invalidate(optimizationConfigProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _SupabaseBackendHealthSection extends ConsumerWidget {
  const _SupabaseBackendHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(supabaseBackendHealthProvider);
    return _Section(
      label: 'SUPABASE BACKEND',
      accentColor: AppColors.memoryAmber,
      child: healthAsync.when(
        data: (health) => Column(
          children: [
            _NeonStatusTile(title: 'Status', subtitle: health.isHealthy ? 'Healthy' : 'Degraded'),
            _NeonStatusTile(
              title: 'Configured / Initialized',
              subtitle: '${health.configured} / ${health.initialized}',
            ),
            _NeonStatusTile(
              title: 'Authenticated / Realtime',
              subtitle: '${health.authenticated} / ${health.realtimeConfigured}',
            ),
            _NeonStatusTile(
              title: 'Database / Storage',
              subtitle: '${health.databaseReachable} / ${health.storageReachable}',
            ),
            _NeonStatusTile(title: 'Detail', subtitle: health.message),
            _NeonNavTile(
              title: 'Recheck Backend Health',
              subtitle: 'Runs diagnostics for Supabase configuration and reachability',
              onTap: () => ref.invalidate(supabaseBackendHealthProvider),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) =>
            _NeonStatusTile(title: 'Backend Health Error', subtitle: error.toString()),
      ),
    );
  }
}

class _TutorialLifecycleDebugSection extends ConsumerWidget {
  const _TutorialLifecycleDebugSection();

  static const List<String> _tutorialAssets = <String>[
    'assets/tutorials/home.json',
    'assets/tutorials/tasks.json',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(tutorialProgressProvider);

    return _Section(
      label: 'TUTORIAL LIFECYCLE',
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          progressAsync.when(
            data: (progress) => _NeonStatusTile(
              title: 'Status',
              subtitle:
                  'started=${progress.started} · introSeen=${progress.hasSeenIntro} · '
                  'version=${progress.contentVersion} · completed=${progress.completedStepIds.length} · '
                  'skipped=${progress.dismissedStepIds.length} · forever=${progress.skippedForeverStepIds.length}',
            ),
            loading: () =>
                const _NeonStatusTile(title: 'Status', subtitle: 'Loading tutorial state...'),
            error: (e, _) => _NeonStatusTile(title: 'Status Error', subtitle: e.toString()),
          ),
          _NeonNavTile(
            title: 'Start Tutorial',
            subtitle: 'Launches the in-app overlay tutorial flow from Home',
            onTap: () => unawaited(_startTutorial(context, ref)),
          ),
          _NeonNavTile(
            title: 'Update Content Version',
            subtitle: 'Applies version migration/reset semantics for tutorial state',
            onTap: () => unawaited(
              ref.read(tutorialProgressProvider.notifier).updateTutorialContentVersion(),
            ),
          ),
          _NeonNavTile(
            title: 'Show First Step Again',
            subtitle: 'Reveals ${TutorialContent.steps.first.id} if hidden or skipped forever',
            onTap: () => unawaited(
              ref.read(tutorialResetServiceProvider).showAgain(TutorialContent.steps.first.id),
            ),
          ),
          _NeonNavTile(
            title: 'Reset Tutorial Progress',
            subtitle: 'Clears completion, skip, and start state for tutorial lifecycle',
            onTap: () => unawaited(ref.read(tutorialResetServiceProvider).resetAll()),
          ),
          _NeonNavTile(
            title: 'Replay Onboarding',
            subtitle: 'Marks onboarding incomplete so onboarding flow can be replayed',
            onTap: () => unawaited(ref.read(tutorialResetServiceProvider).replayOnboarding()),
          ),
        ],
      ),
    );
  }

  Future<void> _startTutorial(BuildContext context, WidgetRef ref) async {
    final progress = ref.read(tutorialProgressProvider).asData?.value;
    final tutorialController = ref.read(tutorialControllerProvider);

    // Ensure definitions are loaded in case this action runs before AppRoot did.
    await tutorialController.loadAssets(_tutorialAssets);
    await ref.read(tutorialProgressProvider.notifier).startTutorial();
    ref.read(appFlowProvider.notifier).toCoach();

    // Start after navigation settles so target widgets are mounted.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tutorialController.start('home_onboarding', restart: true);

    if (!context.mounted) {
      return;
    }
    final int completedCount = progress?.completedStepIds.length ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          completedCount > 0
              ? 'Tutorial restarted on Smart Coach.'
              : 'Tutorial started on Smart Coach.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, required this.accentColor});
  final String label;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NeonToggleTile extends StatelessWidget {
  const _NeonToggleTile({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.neonCyan,
            activeTrackColor: AppColors.neonCyan.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white12,
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }
}

class _NeonNavTile extends StatelessWidget {
  const _NeonNavTile({required this.title, required this.onTap, this.subtitle});
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (subtitle != null)
                    Text(
                      subtitle ?? '',
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NeonStatusTile extends StatelessWidget {
  const _NeonStatusTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  subtitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
