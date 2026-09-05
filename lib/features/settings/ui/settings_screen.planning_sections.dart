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
            SmartPressable(
              semanticLabel:
                  'Change reflection reminder time, current ${_time.format(context)}',
              onTap: _pickTime,
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
                      const Expanded(
                        child: Text(
                          'Reminder Time',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
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
            SmartPressable(
              semanticLabel:
                  'Change daily planning time, current ${_dailyPlanningTime.format(context)}',
              onTap: _pickDailyPlanningTime,
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
                      const Expanded(
                        child: Text(
                          'Daily Planning Time',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
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
            title: 'Allow saved preferences in future guidance',
            value: profile.useMemoryContext,
            onChanged: (bool value) =>
                _save(context, ref, profile.copyWith(useMemoryContext: value)),
          ),
          if (Env.externalAiEnabled)
            _NeonToggleTile(
              title: 'Allow external AI assistance',
              value: profile.externalAiAllowed,
              onChanged: (bool value) => _save(
                context,
                ref,
                profile.copyWith(externalAiAllowed: value),
              ),
            )
          else
            const _NeonStatusTile(
              title: 'External AI assistance',
              subtitle:
                  'Unavailable while privacy, safety, and cost gates are completed.',
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
        ],
      ),
    );
  }
}

class _LearningLedgerSection extends ConsumerWidget {
  const _LearningLedgerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DecisionOutcomeEntity>> outcomesAsync = ref.watch(
      decisionOutcomesProvider,
    );
    final bool paused = ref.watch(learningPausedProvider).asData?.value ?? true;
    final LearningLedgerSummary summary = ref.watch(
      learningLedgerSummaryProvider,
    );
    final List<DecisionOutcomeEntity> outcomes =
        outcomesAsync.asData?.value ?? const <DecisionOutcomeEntity>[];
    final List<DecisionOutcomeEntity> recent = outcomes.reversed
        .take(8)
        .toList(growable: false);

    return _Section(
      label: 'WHAT CHANGED FROM YOUR FEEDBACK',
      accentColor: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'ChronoSpark learns only bounded support preferences from the outcomes below. These are not facts about you, and low-confidence patterns do not change recommendations.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          _NeonToggleTile(
            key: const Key('learning-feedback-toggle'),
            title: 'Use feedback for learning',
            value: !paused,
            onChanged: outcomesAsync.isLoading
                ? null
                : (bool enabled) => unawaited(
                    ref
                        .read(decisionOutcomeActionsProvider)
                        .setPaused(!enabled),
                  ),
          ),
          _NeonStatusTile(
            title: 'Reviewable observations',
            subtitle: outcomesAsync.when(
              loading: () => 'Loading the account-scoped ledger...',
              error: (_, _) => 'Ledger unavailable. No learning is applied.',
              data: (List<DecisionOutcomeEntity> values) =>
                  '${values.length} saved locally · maximum 256 · recent evidence decays with a 30-day half-life.',
            ),
          ),
          if (outcomesAsync.hasValue && summary.patterns.isEmpty)
            const _NeonStatusTile(
              title: 'Learned preferences',
              subtitle:
                  'None yet. At least three recent outcomes are required before a pattern may influence guidance.',
            )
          else if (outcomesAsync.hasValue)
            ...summary.patterns
                .take(3)
                .map(
                  (LearnedPreferencePattern pattern) => _NeonStatusTile(
                    title:
                        '${_learningLabel(pattern.surface)} · ${pattern.situation}',
                    subtitle:
                        '${pattern.confidence.name} confidence · ${pattern.explanation}',
                  ),
                ),
          if (recent.isNotEmpty) ...<Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'RECENT RAW OBSERVATIONS',
                style: TextStyle(
                  color: AppColors.neonViolet,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...recent.map(
              (DecisionOutcomeEntity outcome) => ListTile(
                key: ValueKey<String>('learning-ledger-${outcome.id}'),
                title: Text(
                  '${_learningLabel(outcome.surface)} · ${outcome.kind.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  _learningObservationDetail(outcome),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Correct or remove this observation',
                  onSelected: (String value) => unawaited(
                    _applyLearningLedgerAction(context, ref, outcome, value),
                  ),
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'helped',
                          child: Text('Correct: it helped'),
                        ),
                        PopupMenuItem<String>(
                          value: 'not_helpful',
                          child: Text('Correct: not helpful'),
                        ),
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Text('Undo / remove'),
                        ),
                      ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: outcomes.isEmpty
                      ? null
                      : () async {
                          final String export = ref
                              .read(decisionOutcomeActionsProvider)
                              .exportJson(outcomes);
                          await Clipboard.setData(ClipboardData(text: export));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Learning ledger copied as JSON.'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: outcomes.isEmpty
                      ? null
                      : () => unawaited(
                          _confirmClearLearningLedger(context, ref),
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete all'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _learningLabel(String value) => value
    .split('_')
    .where((String part) => part.isNotEmpty)
    .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _learningObservationDetail(DecisionOutcomeEntity outcome) {
  final List<String> details = <String>[
    outcome.situation ??
        (outcome.subjectId == null ? 'general guidance' : 'task guidance'),
    if (outcome.optionChosen != null) 'option ${outcome.optionChosen}',
    if (outcome.optionSizeMinutes != null)
      '${outcome.optionSizeMinutes} minutes',
    if (outcome.deferralReason != null) 'deferred: ${outcome.deferralReason}',
    if (outcome.completionResult != null) outcome.completionResult!,
    if (outcome.correction != null) 'corrected to ${outcome.correction}',
    if (outcome.recommendationHelped != null)
      outcome.recommendationHelped! ? 'helped' : 'did not help',
  ];
  return details.join(' · ');
}

Future<void> _applyLearningLedgerAction(
  BuildContext context,
  WidgetRef ref,
  DecisionOutcomeEntity outcome,
  String action,
) async {
  final DecisionOutcomeActions actions = ref.read(
    decisionOutcomeActionsProvider,
  );
  if (action == 'remove') {
    await actions.remove(outcome);
  } else {
    final bool helped = action == 'helped';
    await actions.correctOutcome(
      original: outcome,
      replacementKind: helped
          ? DecisionOutcomeKind.accepted
          : DecisionOutcomeKind.rejected,
      reason: helped
          ? 'User corrected this observation to helpful in the learning ledger.'
          : 'User corrected this observation to not helpful in the learning ledger.',
    );
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        action == 'remove'
            ? 'Observation removed and its learning undone.'
            : 'Observation corrected. The learned preference was updated.',
      ),
    ),
  );
}

Future<void> _confirmClearLearningLedger(
  BuildContext context,
  WidgetRef ref,
) async {
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Delete all learning observations?'),
          content: const Text(
            'This permanently removes the decision-outcome ledger and reverses the preference learning created from it. Tasks, goals, Person Context, and user-authored facts are not changed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-delete-learning-ledger'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete ledger'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return;
  await ref.read(decisionOutcomeActionsProvider).clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Learning ledger deleted.')));
}
