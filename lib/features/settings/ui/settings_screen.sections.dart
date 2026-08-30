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
          if (LaunchContainment.externalAiEnabled)
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

class _PersonContextSection extends ConsumerWidget {
  const _PersonContextSection();

  static const Set<PersonContextKind> _aboutYouKinds = <PersonContextKind>{
    PersonContextKind.role,
    PersonContextKind.value,
    PersonContextKind.lifeArea,
    PersonContextKind.preferredSupportStyle,
    PersonContextKind.boundary,
    PersonContextKind.importantRelationship,
  };

  static const Set<PersonContextKind> _rightNowKinds = <PersonContextKind>{
    PersonContextKind.currentPriority,
    PersonContextKind.presentCapacity,
    PersonContextKind.commitment,
  };

  String _kindLabel(PersonContextKind kind) => switch (kind) {
    PersonContextKind.role => 'Role',
    PersonContextKind.value => 'Value',
    PersonContextKind.currentPriority => 'Current priority',
    PersonContextKind.lifeArea => 'Life area',
    PersonContextKind.presentCapacity => 'Capacity right now',
    PersonContextKind.preferredSupportStyle => 'Preferred support style',
    PersonContextKind.boundary => 'Boundary',
    PersonContextKind.importantRelationship => 'Important relationship',
    PersonContextKind.commitment => 'Commitment',
    PersonContextKind.outcomeHistory => 'Confirmed outcome',
  };

  String _surfaceLabel(PersonContextSurface surface) => switch (surface) {
    PersonContextSurface.smartPlanner => 'Smart Planner',
    PersonContextSurface.siConsole => 'SI Console',
    PersonContextSurface.nexus => 'Nexus',
    PersonContextSurface.trajectory => 'Trajectory',
    PersonContextSurface.creator => 'Creator',
    PersonContextSurface.settings => 'Settings',
  };

  PersonContextPurpose _purposeFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.role ||
    PersonContextKind.value ||
    PersonContextKind.lifeArea ||
    PersonContextKind.currentPriority ||
    PersonContextKind.presentCapacity ||
    PersonContextKind.commitment => PersonContextPurpose.decisionSupport,
    PersonContextKind.preferredSupportStyle ||
    PersonContextKind.boundary ||
    PersonContextKind.importantRelationship =>
      PersonContextPurpose.planningGuidance,
    PersonContextKind.outcomeHistory => PersonContextPurpose.outcomeLearning,
  };

  Duration _freshnessFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.presentCapacity => const Duration(hours: 24),
    PersonContextKind.currentPriority ||
    PersonContextKind.commitment => const Duration(days: 30),
    PersonContextKind.outcomeHistory => const Duration(days: 90),
    _ => const Duration(days: 180),
  };

  Duration _expiryFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.presentCapacity => const Duration(hours: 24),
    PersonContextKind.currentPriority ||
    PersonContextKind.commitment => const Duration(days: 90),
    _ => const Duration(days: 366),
  };

  PersonContextDeletionBehavior _deletionFor(PersonContextKind kind) =>
      kind == PersonContextKind.presentCapacity
      ? PersonContextDeletionBehavior.expiresAutomatically
      : PersonContextDeletionBehavior.userRemovable;

  String _date(DateTime value) =>
      value.toLocal().toIso8601String().split('T').first;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final TextEditingController textController = TextEditingController();
    PersonContextKind kind = PersonContextKind.currentPriority;
    final Set<PersonContextSurface> selected = <PersonContextSurface>{};
    final _PersonContextDraft? draft = await showDialog<_PersonContextDraft>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final String grouping = _aboutYouKinds.contains(kind)
              ? 'About you'
              : 'Right now';
          return AlertDialog(
            title: const Text('Add person context'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Nothing is inferred. ChronoSpark will use only the exact text you choose to save.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Before you opt in: Person Context is stored only on this device, excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PersonContextKind>(
                      key: const Key('person-context-kind'),
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items:
                          <PersonContextKind>[
                                ..._aboutYouKinds,
                                ..._rightNowKinds,
                              ]
                              .map(
                                (PersonContextKind value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_kindLabel(value)),
                                ),
                              )
                              .toList(growable: false),
                      onChanged: (PersonContextKind? value) {
                        if (value != null) {
                          setState(() {
                            kind = value;
                            selected.retainAll(
                              allowedPersonContextSurfacesFor(
                                _purposeFor(value),
                              ),
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('$grouping · ${_purposeFor(kind).name}'),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('person-context-value'),
                      controller: textController,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: PersonContextSignal.maxValueLength,
                      decoration: const InputDecoration(
                        labelText: 'Exact text to remember',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Where may ChronoSpark use this?'),
                    const Text(
                      'Settings review is administrative and does not require behavioral consent.',
                    ),
                    ...allowedPersonContextSurfacesFor(_purposeFor(kind)).map(
                      (PersonContextSurface surface) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_surfaceLabel(surface)),
                        value: selected.contains(surface),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked ?? false) {
                              selected.add(surface);
                            } else {
                              selected.remove(surface);
                            }
                          });
                        },
                      ),
                    ),
                    Text(
                      'Fresh for ${_freshnessFor(kind).inHours <= 24 ? '${_freshnessFor(kind).inHours} hours' : '${_freshnessFor(kind).inDays} days'} · expires after ${_expiryFor(kind).inHours <= 24 ? '${_expiryFor(kind).inHours} hours' : '${_expiryFor(kind).inDays} days'}',
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('person-context-confirm-add'),
                onPressed: () {
                  final String text = textController.text.trim();
                  if (text.isEmpty || selected.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    _PersonContextDraft(
                      kind: kind,
                      value: text,
                      surfaces: selected,
                    ),
                  );
                },
                child: const Text('Save with consent'),
              ),
            ],
          );
        },
      ),
    );
    textController.dispose();
    if (draft == null) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    final int existingCount =
        ref.read(personContextSpineProvider).value?.signals.length ?? 0;
    final PersonContextSignal signal = PersonContextSignal(
      id: '${draft.kind.name}-${now.microsecondsSinceEpoch}-$existingCount',
      kind: draft.kind,
      value: draft.value,
      source: PersonContextSource.userAuthored,
      consent: PersonContextConsent.granted,
      consentedAt: now,
      purpose: _purposeFor(draft.kind),
      surfaceScopes: draft.surfaces,
      recordedAt: now,
      freshUntil: now.add(_freshnessFor(draft.kind)),
      expiresAt: now.add(_expiryFor(draft.kind)),
      exportBehavior: PersonContextExportBehavior.include,
      deletionBehavior: _deletionFor(draft.kind),
    );
    try {
      await ref.read(personContextActionsProvider).upsert(signal);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person context saved with consent.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final TextEditingController valueController = TextEditingController(
      text: signal.value,
    );
    final TextEditingController reasonController = TextEditingController();
    final _PersonContextCorrectionDraft? draft =
        await showDialog<_PersonContextCorrectionDraft>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Correct person context'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: valueController,
                    maxLength: PersonContextSignal.maxValueLength,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Exact text'),
                  ),
                  TextField(
                    controller: reasonController,
                    maxLength: PersonContextCorrection.maxReasonLength,
                    decoration: const InputDecoration(
                      labelText: 'Why are you correcting it?',
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final String value = valueController.text.trim();
                  final String reason = reasonController.text.trim();
                  if (value.isEmpty || reason.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    _PersonContextCorrectionDraft(value: value, reason: reason),
                  );
                },
                child: const Text('Save correction'),
              ),
            ],
          ),
        );
    valueController.dispose();
    reasonController.dispose();
    if (draft == null) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    await ref
        .read(personContextActionsProvider)
        .correct(
          signalId: signal.id,
          value: draft.value,
          correctedAt: now,
          reason: draft.reason,
          freshUntil: now.add(_freshnessFor(signal.kind)),
          expiresAt: now.add(_expiryFor(signal.kind)),
        );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete this person context?'),
            content: Text(
              '“${signal.value}” will be permanently removed. Tasks, goals, and Timeline items are unchanged.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(personContextActionsProvider).remove(signal.id);
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Withdraw consent?'),
            content: Text(
              'ChronoSpark will immediately stop using “${signal.value}”. The timestamped record remains available for review, export, correction, or deletion.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Withdraw consent'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    await ref
        .read(personContextActionsProvider)
        .withdrawConsent(signalId: signal.id, withdrawnAt: now);
  }

  Future<void> _review(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final AsyncValue<PersonContextSpine?> spineAsync = ref.watch(
            personContextSpineProvider,
          );
          return AlertDialog(
            title: const Text('Review person context'),
            content: SizedBox(
              width: 620,
              child: spineAsync.when(
                loading: () => const Text('Loading consented context…'),
                error: (_, _) => const Text(
                  'Recoverable context data needs attention and is not available for review.',
                ),
                data: (PersonContextSpine? spine) {
                  final List<PersonContextSignal>? signals = spine?.signals;
                  if (signals == null) {
                    return const Text(
                      'Person context is unavailable for this account.',
                    );
                  }
                  if (signals.isEmpty) {
                    return const Text(
                      'Not provided. ChronoSpark will not invent personal context.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: signals.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      final PersonContextSignal signal = signals[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(signal.value),
                        subtitle: Text(
                          '${_kindLabel(signal.kind)} · ${signal.source.name}\n'
                          'Purpose: ${signal.purpose.name} · Consent: ${signal.consent.name}\n'
                          'Surfaces: ${signal.surfaceScopes.map(_surfaceLabel).join(', ')}\n'
                          'Fresh until: ${_date(signal.freshUntil)} · Expires: ${_date(signal.expiresAt)}\n'
                          'Corrections: ${signal.corrections.length} · Export: ${signal.exportBehavior.name} · Deletion: ${signal.deletionBehavior.name}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (signal.consent == PersonContextConsent.granted)
                              IconButton(
                                tooltip: 'Withdraw consent',
                                onPressed: () => unawaited(
                                  _withdraw(dialogContext, ref, signal),
                                ),
                                icon: const Icon(Icons.block_outlined),
                              ),
                            IconButton(
                              tooltip: 'Correct',
                              onPressed: () => unawaited(
                                _correct(dialogContext, ref, signal),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => unawaited(
                                _remove(dialogContext, ref, signal),
                              ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final Map<String, dynamic> export = await ref
          .read(personContextActionsProvider)
          .export();
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person context export copied.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    if (count == 0) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete all person context?'),
            content: Text(
              'This permanently removes $count user-authored context item${count == 1 ? '' : 's'}. Tasks, goals, and Timeline items are unchanged.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete all'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(personContextActionsProvider).clear();
  }

  Future<void> _clearCorruptData(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Permanently clear corrupt Person Context?'),
            content: const Text(
              'This permanently clears only recoverable or corrupt Person Context payloads stored on this device. Tasks, goals, and Timeline items are unaffected. This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('person-context-confirm-clear-corrupt'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Permanently clear'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(personContextActionsProvider).clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrupt Person Context data cleared.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PersonContextSpine?> spineAsync = ref.watch(
      personContextSpineProvider,
    );
    return _Section(
      label: 'PERSON CONTEXT',
      accentColor: AppColors.neonViolet,
      child: spineAsync.when(
        loading: () => const _NeonStatusTile(
          title: 'Person context',
          subtitle: 'Loading consented context…',
        ),
        error: (Object error, _) {
          if (error is PersonContextCorruptionException) {
            return Column(
              children: <Widget>[
                const _NeonStatusTile(
                  title: 'Person context unavailable',
                  subtitle:
                      'Recoverable context data needs attention. It is not being treated as empty or used for guidance.',
                ),
                _NeonNavTile(
                  title: 'Clear corrupt Person Context data',
                  subtitle:
                      'Permanently clears only recoverable or corrupt Person Context payloads.',
                  onTap: () => unawaited(_clearCorruptData(context, ref)),
                ),
              ],
            );
          }
          return Column(
            children: <Widget>[
              const _NeonStatusTile(
                title: 'Person context temporarily unavailable',
                subtitle:
                    'Stored context was not changed or treated as empty. Retry after the account or device storage is ready.',
              ),
              _NeonNavTile(
                title: 'Retry person context',
                subtitle: 'Attempts a fresh read without deleting anything.',
                onTap: () => ref.invalidate(personContextSpineProvider),
              ),
            ],
          );
        },
        data: (PersonContextSpine? spine) {
          if (spine == null) {
            return const _NeonStatusTile(
              title: 'Person context unavailable',
              subtitle:
                  'A verified signed-in account is required. No personal context will be invented.',
            );
          }
          final List<PersonContextSignal> aboutYou = spine.signals
              .where((signal) => _aboutYouKinds.contains(signal.kind))
              .toList(growable: false);
          final List<PersonContextSignal> rightNow = spine.signals
              .where((signal) => _rightNowKinds.contains(signal.kind))
              .toList(growable: false);
          final int outcomes = spine.signals
              .where(
                (signal) => signal.kind == PersonContextKind.outcomeHistory,
              )
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  'Optional and co-authored. ChronoSpark uses only the exact context you save, only for the purposes and surfaces you choose. Unknown stays unknown.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Stored only on this device. Person Context is excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              _NeonStatusTile(
                title: 'About you',
                subtitle: aboutYou.isEmpty
                    ? 'Not provided'
                    : '${aboutYou.length} reviewable item${aboutYou.length == 1 ? '' : 's'}',
              ),
              _NeonStatusTile(
                title: 'Right now',
                subtitle: rightNow.isEmpty
                    ? 'Not provided'
                    : '${rightNow.length} freshness-limited item${rightNow.length == 1 ? '' : 's'}',
              ),
              _NeonStatusTile(
                title: 'Confirmed outcomes',
                subtitle: outcomes == 0
                    ? 'No outcome history recorded'
                    : '$outcomes reviewable outcome${outcomes == 1 ? '' : 's'}',
              ),
              _NeonNavTile(
                title: 'Add person context',
                subtitle: 'Choose exact text, purpose, surfaces, and expiry.',
                onTap: () => unawaited(_add(context, ref)),
              ),
              _NeonNavTile(
                title: 'Review and correct',
                subtitle:
                    'Inspect source, consent, scope, freshness, history, and controls.',
                onTap: () => unawaited(_review(context)),
              ),
              _NeonNavTile(
                title: 'Export person context',
                subtitle: 'Copies only items marked for export.',
                onTap: () => unawaited(_export(context, ref)),
              ),
              _NeonNavTile(
                title: 'Delete all person context',
                subtitle:
                    'Permanently removes all ${spine.signals.length} context items.',
                onTap: () =>
                    unawaited(_deleteAll(context, ref, spine.signals.length)),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _PersonContextDraft {
  const _PersonContextDraft({
    required this.kind,
    required this.value,
    required this.surfaces,
  });

  final PersonContextKind kind;
  final String value;
  final Set<PersonContextSurface> surfaces;
}

final class _PersonContextCorrectionDraft {
  const _PersonContextCorrectionDraft({
    required this.value,
    required this.reason,
  });

  final String value;
  final String reason;
}

class _MemoryGovernanceSection extends ConsumerWidget {
  const _MemoryGovernanceSection();

  String _date(DateTime? value) {
    if (value == null) return 'Not set';
    return value.toLocal().toIso8601String().split('T').first;
  }

  Future<void> _exportReceipts(BuildContext context, WidgetRef ref) async {
    final Map<String, dynamic> export = ref
        .read(memoryGovernanceControllerProvider)
        .exportReceipts();
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Memory receipts copied.')));
  }

  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    MemoryEntity memory,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: memory.text,
    );
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Correct remembered preference'),
        content: TextField(
          key: const Key('memory-correction-field'),
          controller: controller,
          maxLength: 280,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            helperText: 'Only this exact preference text will be replaced.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) return;
    try {
      await ref
          .read(memoryGovernanceControllerProvider)
          .correctPreference(id: memory.id, text: next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preference corrected.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    MemoryEntity memory,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete this memory?'),
            content: Text(
              '“${memory.text}” will be permanently removed and cannot be retrieved again.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(memoryGovernanceControllerProvider).deleteMemory(memory.id);
  }

  Future<void> _reviewReceipts(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final List<MemoryEntity> memories = ref.watch(memoriesProvider);
          return AlertDialog(
            title: const Text('Memory receipts'),
            content: SizedBox(
              width: 560,
              child: memories.isEmpty
                  ? const Text(
                      'No durable memories. “Use only this time” remains the default.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: memories.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (BuildContext context, int index) {
                        final MemoryEntity memory = memories[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(memory.text),
                          subtitle: Text(
                            'Why: ${memory.whyStored}\n'
                            'Source: ${memory.sourceSurface.label} · Expires: ${_date(memory.expiresAt)}\n'
                            'Consent: ${memory.consentStatus.name} · Controls: view, correct, export, delete',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Correct',
                                onPressed: () => unawaited(
                                  _correct(dialogContext, ref, memory),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => unawaited(
                                  _deleteOne(dialogContext, ref, memory),
                                ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    if (count == 0) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete all durable memories?'),
            content: Text(
              'This permanently removes $count consented memory receipt${count == 1 ? '' : 's'}. Tasks, goals, and Timeline data are unchanged.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete all'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(memoryGovernanceControllerProvider).deleteAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All durable memories deleted.')),
    );
  }

  Future<void> _clearAssistantContext(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Clear short-lived assistant context?'),
            content: const Text(
              'This clears short-lived Smart Planner and SI Console context. It does not delete tasks, goals, Timeline data, or governed memory receipts.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear context'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Short-lived assistant context cleared.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MemoryEntity> memories = ref.watch(memoriesProvider);
    return _Section(
      label: 'MEMORY GOVERNANCE',
      accentColor: AppColors.memoryAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Use only this time is the default. Durable memory requires an explicit confirmation, stays in the source surface, expires automatically, and always creates a receipt. Raw emotional and crisis disclosures are not retained. SI durable interpretive memory is disabled.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _NeonStatusTile(
            title: 'Active memory receipts',
            subtitle:
                '${memories.length} · account-scoped · surface-scoped · expiring',
          ),
          const _NeonStatusTile(
            title: 'SI Console durable memory',
            subtitle:
                'Disabled — SI cannot save or retrieve interpretive memory.',
          ),
          _NeonNavTile(
            title: 'Review memory receipts',
            subtitle: 'View exact text, purpose, source, expiry, and controls.',
            onTap: () => unawaited(_reviewReceipts(context)),
          ),
          _NeonNavTile(
            title: 'Export memory receipts',
            subtitle: 'Copies governed receipts only — never raw transcripts.',
            onTap: () => unawaited(_exportReceipts(context, ref)),
          ),
          _NeonNavTile(
            title: 'Delete all durable memories',
            subtitle:
                'Permanently removes all ${memories.length} active receipts.',
            onTap: () => unawaited(_deleteAll(context, ref, memories.length)),
          ),
          _NeonNavTile(
            title: 'Clear short-lived assistant context',
            subtitle: 'Clears surface-local context separately.',
            onTap: () => unawaited(_clearAssistantContext(context, ref)),
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

class _AssistantReleaseSection extends ConsumerWidget {
  const _AssistantReleaseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> optIn = ref.watch(assistantBetaOptInProvider);
    final AsyncValue<AssistantReleaseConfig> config = ref.watch(
      assistantReleaseConfigProvider,
    );
    final AsyncValue<AssistantReleaseDecision> plannerDecision = ref.watch(
      assistantReleaseDecisionProvider(
        AssistantReleaseCapability.smartPlannerV2,
      ),
    );
    final AssistantReleaseConfig? loadedConfig = config.asData?.value;
    return _Section(
      label: 'ASSISTANT RELEASE CONTROL',
      accentColor: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'New assistant behavior is assigned deterministically. Joining beta is optional; leaving removes beta eligibility. Planner, SI, memory, and critic each have an independent emergency rollback.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _NeonToggleTile(
            title: 'Join opt-in assistant beta',
            value: optIn.asData?.value ?? false,
            onChanged: optIn.isLoading
                ? null
                : (bool value) => unawaited(
                    ref
                        .read(assistantBetaOptInProvider.notifier)
                        .setEnabled(value),
                  ),
          ),
          _NeonStatusTile(
            title: 'Release stage',
            subtitle: loadedConfig == null
                ? 'Loading fail-closed release configuration...'
                : loadedConfig.configurationValid
                ? loadedConfig.stage.name
                : 'Disabled: ${loadedConfig.configurationIssue}',
          ),
          _NeonStatusTile(
            title: 'Your Planner cohort',
            subtitle: plannerDecision.when(
              data: (AssistantReleaseDecision decision) =>
                  '${decision.cohort.name} · ${decision.enabled ? 'enabled' : 'not enabled'}',
              loading: () => 'Resolving without exposing account identity...',
              error: (Object _, StackTrace _) =>
                  'Disabled because release state could not be verified.',
            ),
          ),
          _NeonStatusTile(
            title: 'Privacy-safe shadow evaluation',
            subtitle: loadedConfig?.shadowEvaluationEnabled == true
                ? 'Enabled for digests and finding codes only; cannot publish or write.'
                : 'Disabled',
          ),
          for (final AssistantReleaseCapability capability
              in AssistantReleaseCapability.values)
            _NeonStatusTile(
              title: _assistantCapabilityLabel(capability),
              subtitle: loadedConfig?.isRolledBack(capability) == true
                  ? 'Emergency rollback active'
                  : 'Independent rollback ready',
            ),
        ],
      ),
    );
  }
}

String _assistantCapabilityLabel(AssistantReleaseCapability capability) {
  return switch (capability) {
    AssistantReleaseCapability.smartPlannerV2 => 'Smart Planner V2',
    AssistantReleaseCapability.siConsoleV2 => 'SI Console V2',
    AssistantReleaseCapability.governedMemory => 'Governed memory',
    AssistantReleaseCapability.safetyCritic => 'Safety critic',
  };
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
          if (available)
            _NeonNavTile(
              title: 'Backup recovery key',
              subtitle:
                  'Reveal or restore the key needed on a replacement device.',
              onTap: () => _showBackupRecoveryKeyDialog(context, ref),
            )
          else
            const _NeonStatusTile(
              title: 'Backup recovery key',
              subtitle:
                  'Available when cloud backup is enabled for this build.',
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

Future<void> _showBackupRecoveryKeyDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final String? action = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Backup recovery key'),
      content: const Text(
        'This key lets you decrypt your encrypted cloud backup on a replacement device. Keep it in a password manager. ChronoSpark cannot recover it for you.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop('import'),
          child: const Text('Restore key'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop('reveal'),
          child: const Text('Reveal key'),
        ),
      ],
    ),
  );
  if (!context.mounted || action == null) {
    return;
  }
  if (action == 'reveal') {
    await _revealBackupRecoveryKey(context, ref);
    return;
  }
  await _importBackupRecoveryKey(context, ref);
}

Future<void> _revealBackupRecoveryKey(
  BuildContext context,
  WidgetRef ref,
) async {
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Reveal recovery key?'),
          content: const Text(
            'Anyone who sees this key can decrypt your cloud backups. Only continue somewhere private.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reveal'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) {
    return;
  }

  final String key = await ref
      .read(settingsUiActionsProvider)
      .exportBackupRecoveryKey();
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Store this recovery key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Copy it to a password manager. Do not share it.'),
          const SizedBox(height: 16),
          SelectableText(
            key,
            key: const Key('backup-recovery-key-value'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: key));
            if (!dialogContext.mounted) {
              return;
            }
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Recovery key copied.')),
            );
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> _importBackupRecoveryKey(
  BuildContext context,
  WidgetRef ref,
) async {
  final TextEditingController controller = TextEditingController();
  final String? recoveryKey = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Restore backup key'),
      content: TextField(
        key: const Key('backup-recovery-key-input'),
        controller: controller,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Recovery key',
          hintText: 'Paste the key from your previous device',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (!context.mounted || recoveryKey == null || recoveryKey.trim().isEmpty) {
    return;
  }

  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Replace this device key?'),
          content: const Text(
            'This replaces this device\'s cloud-backup key. Use the original key again if you need to decrypt backups created with it.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace key'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    await ref
        .read(settingsUiActionsProvider)
        .importBackupRecoveryKey(recoveryKey);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery key saved. You can now restore your backup.'),
      ),
    );
  } on FormatException {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That recovery key is not valid.')),
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
        borderRadius: BorderRadius.circular(8),
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
                    letterSpacing: 0,
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

class _PlanAndCreditsCard extends StatelessWidget {
  const _PlanAndCreditsCard({
    required this.planStatus,
    required this.planDetail,
    required this.creditLabel,
    required this.creditValue,
    required this.creditDetail,
    required this.onOpenPlan,
    required this.onOpenCredits,
  });

  final String planStatus;
  final String planDetail;
  final String creditLabel;
  final String creditValue;
  final String creditDetail;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenCredits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.neonViolet.withValues(alpha: .18),
            const Color(0xEE071326),
            AppColors.neonCyan.withValues(alpha: .13),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonViolet.withValues(alpha: .42)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: .1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PLAN & CREDITS',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Access and usage',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _SettingsAccessEntry(
            key: const Key('settings_manage_plan'),
            icon: Icons.workspace_premium_rounded,
            accent: AppColors.memoryAmber,
            eyebrow: 'SUBSCRIPTION',
            title: planStatus,
            subtitle: planDetail,
            actionLabel: 'Manage plan',
            onTap: onOpenPlan,
          ),
          const SizedBox(height: 9),
          _SettingsAccessEntry(
            key: const Key('settings_view_credits'),
            icon: Icons.auto_awesome_rounded,
            accent: AppColors.neonCyan,
            eyebrow: creditLabel.toUpperCase(),
            title: creditValue,
            subtitle: creditDetail,
            actionLabel: 'View credits',
            onTap: onOpenCredits,
          ),
        ],
      ),
    );
  }
}

class _SettingsAccessEntry extends StatelessWidget {
  const _SettingsAccessEntry({
    super.key,
    required this.icon,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: .3)),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: accent,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF95A3BF),
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: <Widget>[
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
                  const SizedBox(height: 3),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCategory extends StatelessWidget {
  const _SettingsCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE8050D1A),
      borderRadius: BorderRadius.circular(8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: accent.withValues(alpha: .35)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: accent.withValues(alpha: .2)),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8C99B5),
              fontSize: 10,
              height: 1.3,
            ),
          ),
          iconColor: accent,
          collapsedIconColor: const Color(0xFF8390AA),
          children: <Widget>[child],
        ),
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
  final ValueChanged<bool>? onChanged;

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
