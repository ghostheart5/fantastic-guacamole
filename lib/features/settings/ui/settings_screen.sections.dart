part of 'settings_screen.dart';

class _ReflectionReminderSection extends ConsumerStatefulWidget {
  const _ReflectionReminderSection();

  @override
  ConsumerState<_ReflectionReminderSection> createState() =>
      _ReflectionReminderSectionState();
}

class _ReflectionReminderSectionState
    extends ConsumerState<_ReflectionReminderSection> {
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
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    await ref
        .read(settingsUiActionsProvider)
        .setReflectionReminderTime(time: picked);
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
          _NeonToggleTile(
            title: 'Reflection Reminder',
            value: _enabled,
            onChanged: _toggle,
          ),
          if (_enabled)
            GestureDetector(
              onTap: _pickTime,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reminder Time',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonViolet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.neonViolet.withValues(alpha: 0.4),
                          ),
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
            ),
        ],
      ),
    );
  }
}

class _ReminderAutomationSection extends ConsumerStatefulWidget {
  const _ReminderAutomationSection();

  @override
  ConsumerState<_ReminderAutomationSection> createState() =>
      _ReminderAutomationSectionState();
}

class _ReminderAutomationSectionState
    extends ConsumerState<_ReminderAutomationSection> {
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
    final prefs = ref
        .read(settingsUiActionsProvider)
        .loadAdvancedReminderPrefs();
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
        child: child ?? const SizedBox.shrink(),
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
          _NeonToggleTile(
            title: 'Goal Reminders',
            value: _goalEnabled,
            onChanged: _toggleGoal,
          ),
          const _NeonStatusTile(
            title: 'Goal Reminder Rule',
            subtitle: 'Schedules around target date (prefers 1 day before).',
          ),
          _NeonToggleTile(
            title: 'Habit Reminders',
            value: _habitEnabled,
            onChanged: _toggleHabit,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Planning Time',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.4),
                          ),
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
            ),
        ],
      ),
    );
  }
}

class _PersonalizationSection extends ConsumerWidget {
  const _PersonalizationSection();

  Future<void> _exportSiMemory(BuildContext context, WidgetRef ref) async {
    final Map<String, dynamic> state = await ref
        .read(siEngineServiceProvider)
        .exportAllStates();
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(state)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Assistant memory copied.')));
  }

  Future<void> _clearSiMemory(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Clear assistant memory?'),
            content: const Text(
              'This removes locally stored assistant memory. Tasks, goals, and timeline events are not changed.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(siEngineServiceProvider).clearAllMemory();
    ref.invalidate(siEngineStateProvider);
    ref.invalidate(smartPlannerEngineStateProvider);
    ref.invalidate(siMemoryProvider);
    ref.invalidate(smartPlannerMemoryProvider);
    ref.invalidate(aiResponseProvider);
    ref.invalidate(smartPlannerAiResponseProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Assistant memory cleared.')));
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    PersonalizationProfile next,
  ) async {
    await ref.read(personalizationProfileProvider.notifier).update(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Planning preferences updated.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PersonalizationProfile profile = ref.watch(
      personalizationProfileProvider,
    );
    final ObservedPlanningPatterns patterns = ref.watch(
      observedPlanningPatternsProvider,
    );
    final PersonalizationDecision decision = ref.watch(
      personalizationDecisionProvider('settings'),
    );

    return _Section(
      label: 'PLANNING PERSONALIZATION',
      accentColor: AppColors.neonCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'These choices tune guidance. You can change them at any time; learned patterns remain separate from your explicit preferences.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _PreferenceDropdown<String>(
            label: 'Planning style',
            value: profile.planningStyle.name,
            items: const <String>[
              'flexible',
              'timeBlocked',
              'energyMatched',
              'singleTask',
            ],
            onChanged: (String value) => _save(
              context,
              ref,
              profile.copyWith(
                planningStyle: PlanningStyle.values.byName(value),
              ),
            ),
          ),
          _PreferenceDropdown<String>(
            label: 'Priority strategy',
            value: profile.priorityStrategy.name,
            items: const <String>[
              'balanced',
              'deadlineFirst',
              'energyFirst',
              'goalFirst',
              'quickWins',
            ],
            onChanged: (String value) => _save(
              context,
              ref,
              profile.copyWith(
                priorityStrategy: PriorityStrategy.values.byName(value),
              ),
            ),
          ),
          _PreferenceDropdown<String>(
            label: 'Missed-task recovery',
            value: profile.recoveryPolicy.name,
            items: const <String>[
              'askFirst',
              'reschedule',
              'reduceScope',
              'recoveryQueue',
            ],
            onChanged: (String value) => _save(
              context,
              ref,
              profile.copyWith(
                recoveryPolicy: RecoveryPolicy.values.byName(value),
              ),
            ),
          ),
          _NeonToggleTile(
            title: 'Use emotional state in guidance',
            value: profile.useEmotionSignals,
            onChanged: (bool value) =>
                _save(context, ref, profile.copyWith(useEmotionSignals: value)),
          ),
          _NeonToggleTile(
            title: 'Use memories in guidance',
            value: profile.useMemoryContext,
            onChanged: (bool value) =>
                _save(context, ref, profile.copyWith(useMemoryContext: value)),
          ),
          _NeonToggleTile(
            title: 'Allow external AI assistance',
            value: profile.externalAiAllowed,
            onChanged: (bool value) =>
                _save(context, ref, profile.copyWith(externalAiAllowed: value)),
          ),
          _NeonStatusTile(
            title: 'Why suggestions appear',
            subtitle: decision.explanation,
          ),
          _NeonStatusTile(
            title: 'Learned evidence',
            subtitle:
                '${patterns.completed} completed · ${patterns.skipped} skipped · ${(patterns.completionRate * 100).round()}% completion rate',
          ),
          _NeonNavTile(
            title: 'Reset learned planning patterns',
            subtitle: 'Deletes inferred completion/skip evidence only.',
            onTap: () => unawaited(
              ref.read(observedPlanningPatternsProvider.notifier).reset(),
            ),
          ),
          _NeonNavTile(
            title: 'Export assistant memory',
            subtitle: 'Copies your locally stored assistant state.',
            onTap: () => unawaited(_exportSiMemory(context, ref)),
          ),
          _NeonNavTile(
            title: 'Clear assistant memory',
            subtitle: 'Removes assistant state without changing your tasks.',
            onTap: () => unawaited(_clearSiMemory(context, ref)),
          ),
        ],
      ),
    );
  }
}

class _PreferenceDropdown<T> extends StatelessWidget {
  const _PreferenceDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        dropdownColor: const Color(0xFF0B111C),
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.neonCyan.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        items: items
            .map(
              (T item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString().split('.').last),
              ),
            )
            .toList(growable: false),
        onChanged: (T? next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _AdaptiveGuidanceSection extends ConsumerWidget {
  const _AdaptiveGuidanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdaptiveGuidanceState> guidance = ref.watch(
      adaptiveGuidanceProvider,
    );
    return _Section(
      label: 'ADAPTIVE GUIDE',
      accentColor: AppColors.memoryAmber,
      child: guidance.when(
        loading: () => const _NeonStatusTile(
          title: 'Loading guide',
          subtitle: 'Reading account-scoped progress...',
        ),
        error: (Object error, StackTrace _) => _NeonStatusTile(
          title: 'Guide unavailable',
          subtitle: error.toString(),
        ),
        data: (AdaptiveGuidanceState state) {
          return Column(
            children: <Widget>[
              _NeonStatusTile(
                title: state.coreComplete
                    ? 'Contextual guidance active'
                    : 'Learning the core workflow',
                subtitle:
                    '${state.milestones.length} real outcomes observed · '
                    '${state.skippedLessons.length} prompts muted',
              ),
              _NeonNavTile(
                title: 'Restart Adaptive Guide',
                subtitle:
                    'Keeps real outcomes and reopens the next relevant contextual intervention.',
                onTap: () => unawaited(_restartGuide(context, ref)),
              ),
              _NeonNavTile(
                title: 'Replay First-Run Tutorial',
                subtitle:
                    'Reopens welcome, profile setup, Creator, and Timeline guidance.',
                onTap: () => unawaited(_replayOnboarding(context, ref)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restartGuide(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adaptiveGuidanceProvider.notifier).restartLessons();
      if (!context.mounted) {
        return;
      }
      context.go(ref.read(routeSurfaceProvider).nexus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adaptive guide restarted.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adaptive guide could not restart.')),
      );
    }
  }

  Future<void> _replayOnboarding(BuildContext context, WidgetRef ref) async {
    try {
      final routes = ref.read(routeSurfaceProvider);
      await ref.read(adaptiveGuidanceProvider.notifier).replayOnboarding();
      if (!context.mounted) {
        return;
      }
      context.go(routes.onboarding);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding could not be replayed.')),
      );
    }
  }
}

class _GlobalMetricsDebugSection extends ConsumerStatefulWidget {
  const _GlobalMetricsDebugSection();

  @override
  ConsumerState<_GlobalMetricsDebugSection> createState() =>
      _GlobalMetricsDebugSectionState();
}

class _GlobalMetricsDebugSectionState
    extends ConsumerState<_GlobalMetricsDebugSection> {
  AsyncValue<OptimizationDebugViewModel> _configAsync =
      const AsyncValue.loading();
  AsyncValue<List<Map<String, dynamic>>> _metricsRealtimeAsync =
      const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_reloadMetrics());
    });
  }

  void _applyAfterBuild(VoidCallback update) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(update);
    });
  }

  Future<void> _reloadMetrics({bool invalidate = false}) async {
    if (invalidate) {
      ref.invalidate(optimizationDebugViewModelProvider);
      ref.invalidate(supabaseMetricsRealtimeProvider);
    }

    _applyAfterBuild(() {
      _configAsync = const AsyncValue.loading();
      _metricsRealtimeAsync = const AsyncValue.loading();
    });

    try {
      final OptimizationDebugViewModel config = await ref.read(
        optimizationDebugViewModelProvider.future,
      );
      _applyAfterBuild(() {
        _configAsync = AsyncValue<OptimizationDebugViewModel>.data(config);
      });
    } on Object catch (error, stackTrace) {
      _applyAfterBuild(() {
        _configAsync = AsyncValue<OptimizationDebugViewModel>.error(
          error,
          stackTrace,
        );
      });
    }

    try {
      final List<Map<String, dynamic>> rows = await ref
          .read(supabaseMetricsRealtimeProvider.future)
          .timeout(const Duration(seconds: 3));
      _applyAfterBuild(() {
        _metricsRealtimeAsync = AsyncValue<List<Map<String, dynamic>>>.data(
          rows,
        );
      });
    } on Object catch (error, stackTrace) {
      _applyAfterBuild(() {
        _metricsRealtimeAsync = AsyncValue<List<Map<String, dynamic>>>.error(
          error,
          stackTrace,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'GLOBAL OPTIMIZER',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          _configAsync.when(
            data: (config) => Column(
              children: [
                _NeonStatusTile(
                  title: 'Execution Duration Multiplier',
                  subtitle: config.executionDurationMultiplier.toStringAsFixed(
                    2,
                  ),
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
            error: (e, _) => _NeonStatusTile(
              title: 'Optimizer Error',
              subtitle: e.toString(),
            ),
          ),
          _metricsRealtimeAsync.when(
            data: (rows) {
              final String latestDate = rows.isEmpty
                  ? 'n/a'
                  : rows.last['date']?.toString() ?? 'unknown';
              return Column(
                children: [
                  _NeonStatusTile(
                    title: 'Realtime Rows',
                    subtitle: '${rows.length} streamed',
                  ),
                  _NeonStatusTile(
                    title: 'Latest Row Date',
                    subtitle: latestDate,
                  ),
                ],
              );
            },
            loading: () => const _NeonStatusTile(
              title: 'Realtime Rows',
              subtitle: 'Connecting to Supabase stream...',
            ),
            error: (error, _) => _NeonStatusTile(
              title: 'Realtime Error',
              subtitle: error.toString(),
            ),
          ),
          _NeonNavTile(
            title: 'Refresh Global Metrics',
            subtitle: 'Fetches latest aggregate data from Supabase',
            onTap: () {
              unawaited(_reloadMetrics(invalidate: true));
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
            _NeonStatusTile(
              title: 'Status',
              subtitle: health.isHealthy ? 'Healthy' : 'Degraded',
            ),
            _NeonStatusTile(title: 'Health Badge', subtitle: health.badgeLabel),
            _NeonStatusTile(
              title: 'Configured / Initialized',
              subtitle: '${health.configured} / ${health.initialized}',
            ),
            _NeonStatusTile(
              title: 'Authenticated / Realtime',
              subtitle:
                  '${health.authenticated} / ${health.realtimeConfigured}',
            ),
            _NeonStatusTile(
              title: 'Database / Storage',
              subtitle:
                  '${health.databaseReachable} / ${health.storageReachable}',
            ),
            _NeonStatusTile(title: 'Detail', subtitle: health.message),
            _NeonNavTile(
              title: 'Recheck Backend Health',
              subtitle:
                  'Runs diagnostics for Supabase configuration and reachability',
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
        error: (error, _) => _NeonStatusTile(
          title: 'Backend Health Error',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}

class _CloudDataControlSection extends ConsumerWidget {
  const _CloudDataControlSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> syncAsync = ref.watch(cloudSyncPreferenceProvider);
    final bool enabled = syncAsync.asData?.value ?? false;
    final bool available = Env.enableCloudSync;
    return _Section(
      label: 'YOUR DATA',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          _NeonToggleTile(
            title: 'Cloud Backup',
            value: enabled && available,
            onChanged: (bool value) {
              if (!available) return;
              unawaited(
                ref
                    .read(cloudSyncPreferenceProvider.notifier)
                    .setEnabled(value),
              );
            },
          ),
          _NeonStatusTile(
            title: 'Storage scope',
            subtitle: !available
                ? 'This build is local-only.'
                : enabled
                ? 'Tasks, profile, and settings may be encrypted and synced to your account.'
                : 'Local-only. Nothing is sent to cloud backup.',
          ),
          const _NeonStatusTile(
            title: 'Guidance processing',
            subtitle:
                'Smart Planner and SI Console explain when a request stays local or uses an opted-in external service.',
          ),
        ],
      ),
    );
  }
}

class _AdaptiveGuidanceDebugSection extends ConsumerWidget {
  const _AdaptiveGuidanceDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdaptiveGuidanceState> guidance = ref.watch(
      adaptiveGuidanceProvider,
    );
    return _Section(
      label: 'ADAPTIVE GUIDE DIAGNOSTICS',
      accentColor: AppColors.neonViolet,
      child: guidance.when(
        loading: () => const _NeonStatusTile(
          title: 'State',
          subtitle: 'Loading account-scoped milestones...',
        ),
        error: (Object error, StackTrace _) =>
            _NeonStatusTile(title: 'State Error', subtitle: error.toString()),
        data: (AdaptiveGuidanceState state) => _NeonStatusTile(
          title: 'Observed progress',
          subtitle:
              'coreComplete=${state.coreComplete} · outcomes=${state.milestones.length} · '
              'skipped=${state.skippedLessons.length} · repeatedDeferral=${state.hasDeferralFriction}',
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    required this.accentColor,
  });
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
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: -2,
          ),
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
  const _NeonToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });
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
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle ?? '',
                        maxLines: 3,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
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
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
