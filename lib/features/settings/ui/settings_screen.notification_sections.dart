part of 'settings_screen.dart';

/// Every reminder control in one place: whether reminders can arrive, the
/// main switch, each kind of reminder, task lead time and quiet hours.
class _NotificationSettingsArea extends ConsumerStatefulWidget {
  const _NotificationSettingsArea();

  @override
  ConsumerState<_NotificationSettingsArea> createState() =>
      _NotificationSettingsAreaState();
}

class _NotificationSettingsAreaState
    extends ConsumerState<_NotificationSettingsArea> {
  bool _remindersOn = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final bool on = ref
        .read(settingsUiActionsProvider)
        .loadAdvancedReminderPrefs()
        .remindersEnabled;
    setState(() => _remindersOn = on);
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _remindersOn = value;
      _saving = true;
    });
    bool applied;
    try {
      applied = await ref
          .read(settingsUiActionsProvider)
          .setRemindersEnabled(value);
    } on Object catch (error) {
      Logger.warn('Main reminder switch could not be applied ($error).');
      applied = false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (!applied) {
      // The choice is saved; only updating the device's reminders failed.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? journeyText(
                    context,
                    'Reminders are on, but they could not all be set up.',
                    'Los recordatorios están activados, pero no se pudieron programar todos.',
                  )
                : journeyText(
                    context,
                    'Reminders are off, but some could not be stopped yet.',
                    'Los recordatorios están desactivados, pero algunos aún no se pudieron detener.',
                  ),
          ),
          action: SnackBarAction(
            label: journeyText(context, 'Try again', 'Intentar de nuevo'),
            onPressed: () => unawaited(_toggle(value)),
          ),
        ),
      );
      return;
    }
    if (!value) return;
    // Turned back on: ask in context if notifications are off.
    await ensureNotificationPermission(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restoredSettingsRevisionProvider, (_, _) => _load());
    return Column(
      children: <Widget>[
        _Section(
          label: journeyText(context, 'REMINDERS', 'RECORDATORIOS'),
          accentColor: AppColors.neonCyan,
          child: Column(
            children: <Widget>[
              _ReminderHealthRow(remindersOn: _remindersOn),
              _NeonToggleTile(
                key: const Key('reminders-main-toggle'),
                title: journeyText(context, 'Reminders', 'Recordatorios'),
                value: _remindersOn,
                onChanged: _saving ? null : _toggle,
              ),
              _NeonStatusTile(
                title: journeyText(
                  context,
                  'What this switch does',
                  'Qué hace este interruptor',
                ),
                subtitle: journeyText(
                  context,
                  'Off stops every reminder on this device. Your choices below are kept for when you turn it back on.',
                  'Desactivado detiene todos los recordatorios en este dispositivo. Tus opciones de abajo se guardan para cuando lo vuelvas a activar.',
                ),
                subtitleMaxLines: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ReminderAutomationSection(enabled: _remindersOn),
        const SizedBox(height: 10),
        _ReflectionReminderSection(enabled: _remindersOn),
        const SizedBox(height: 10),
        _QuietHoursSection(enabled: _remindersOn),
      ],
    );
  }
}

/// Says whether reminders can arrive and, if not, why, with the matching
/// action. Agrees with the notice on Today and Goals.
class _ReminderHealthRow extends ConsumerWidget {
  const _ReminderHealthRow({required this.remindersOn});

  final bool remindersOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool deviceSupported = ref.watch(
      notificationPermissionSupportedProvider,
    );
    final ValueListenable<bool?> permission = ref.watch(
      notificationPermissionListenableProvider,
    );
    final ReminderOrchestratorService reminders = ref.watch(
      reminderOrchestratorServiceProvider,
    );
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        permission,
        reminders.lastReminderResult,
        reminders.lastHabitReminderResult,
      ]),
      builder: (BuildContext context, _) {
        final ReminderHealth health = reminderHealth(
          remindersOn: remindersOn,
          deviceSupported: deviceSupported,
          permissionGranted: permission.value,
          lastResults: <NotificationScheduleResult?>[
            reminders.lastReminderResult.value,
            reminders.lastHabitReminderResult.value,
          ],
        );
        final bool good = health == ReminderHealth.ready;
        final (String, Future<void> Function())? action = switch (health) {
          ReminderHealth.permissionOff => (
            journeyText(
              context,
              'Turn on notifications',
              'Activar notificaciones',
            ),
            () => _turnOnNotifications(context, ref),
          ),
          ReminderHealth.lastAttemptFailed => (
            journeyText(context, 'Try again', 'Intentar de nuevo'),
            () => ref
                .read(settingsUiActionsProvider)
                .refreshNotificationPermissionAndReminders(),
          ),
          _ => null,
        };
        return Padding(
          key: const Key('reminder-health-row'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                good
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: good ? AppColors.neonCyan : AppColors.memoryAmber,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reminderHealthMessage(
                        health,
                        spanish: ChronoSparkLocalizations.of(context).isSpanish,
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (action != null)
                      TextButton(
                        onPressed: () => unawaited(action.$2()),
                        child: Text(action.$1),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The same step as the notice: ask in context, or open device settings
  /// once the system has refused.
  Future<void> _turnOnNotifications(BuildContext context, WidgetRef ref) async {
    if (ref.read(notificationPermissionProvider).refusal ==
        NotificationPermissionRefusal.denied) {
      await openNotificationSystemSettings(context, ref);
      return;
    }
    await ensureNotificationPermission(context, ref, userInitiated: true);
  }
}

/// Holds reminders the app times itself until a quiet stretch ends.
class _QuietHoursSection extends ConsumerStatefulWidget {
  const _QuietHoursSection({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_QuietHoursSection> createState() => _QuietHoursSectionState();
}

class _QuietHoursSectionState extends ConsumerState<_QuietHoursSection> {
  QuietHours _quiet = const QuietHours();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final QuietHours quiet = ref
        .read(settingsUiActionsProvider)
        .loadAdvancedReminderPrefs()
        .quietHours;
    setState(() => _quiet = quiet);
  }

  Future<void> _save(QuietHours next) async {
    setState(() => _quiet = next);
    await ref.read(settingsUiActionsProvider).setQuietHours(next);
  }

  Future<void> _pick({required bool start}) async {
    final int minutes = start ? _quiet.startMinutes : _quiet.endMinutes;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    final int chosen = picked.hour * 60 + picked.minute;
    if (chosen == (start ? _quiet.endMinutes : _quiet.startMinutes)) {
      // The same start and end would hold nothing back.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journeyText(
              context,
              'Quiet hours need different start and end times.',
              'Las horas de silencio necesitan horas de inicio y fin distintas.',
            ),
          ),
        ),
      );
      return;
    }
    await _save(
      QuietHours(
        enabled: _quiet.enabled,
        startMinutes: start ? chosen : _quiet.startMinutes,
        endMinutes: start ? _quiet.endMinutes : chosen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restoredSettingsRevisionProvider, (_, _) => _load());
    String format(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
    final bool active =
        _quiet.enabled && _quiet.startMinutes != _quiet.endMinutes;
    return _Section(
      label: journeyText(context, 'QUIET HOURS', 'HORAS DE SILENCIO'),
      accentColor: AppColors.neonViolet,
      child: Column(
        children: <Widget>[
          _NeonToggleTile(
            key: const Key('quiet-hours-toggle'),
            title: journeyText(context, 'Quiet hours', 'Horas de silencio'),
            // Equal start and end hold nothing back, so they show as off.
            value: active,
            onChanged: widget.enabled
                ? (bool value) => _save(
                    _quiet.startMinutes == _quiet.endMinutes
                        ? QuietHours(enabled: value)
                        : QuietHours(
                            enabled: value,
                            startMinutes: _quiet.startMinutes,
                            endMinutes: _quiet.endMinutes,
                          ),
                  )
                : null,
          ),
          if (active) ...<Widget>[
            _ReminderTimeRow(
              label: journeyText(context, 'Starts', 'Empieza'),
              time: format(_quiet.startMinutes),
              semanticLabel: journeyText(
                context,
                'Change when quiet hours start, now ${format(_quiet.startMinutes)}',
                'Cambiar cuándo empiezan las horas de silencio; ahora ${format(_quiet.startMinutes)}',
              ),
              onTap: widget.enabled ? () => _pick(start: true) : null,
            ),
            _ReminderTimeRow(
              label: journeyText(context, 'Ends', 'Termina'),
              time: format(_quiet.endMinutes),
              semanticLabel: journeyText(
                context,
                'Change when quiet hours end, now ${format(_quiet.endMinutes)}',
                'Cambiar cuándo terminan las horas de silencio; ahora ${format(_quiet.endMinutes)}',
              ),
              onTap: widget.enabled ? () => _pick(start: false) : null,
            ),
          ],
          _NeonStatusTile(
            title: journeyText(
              context,
              'What quiet hours change',
              'Qué cambian las horas de silencio',
            ),
            subtitle: journeyText(
              context,
              'Task and goal reminders, whose time the app picks, wait until quiet hours end. Times you chose yourself (habits, daily planning, reflection) are not moved.',
              'Los recordatorios de tareas y metas, cuya hora elige la aplicación, esperan a que terminen las horas de silencio. Las horas que elegiste tú (hábitos, planificación diaria, reflexión) no se mueven.',
            ),
            subtitleMaxLines: null,
          ),
        ],
      ),
    );
  }
}

/// A labelled time that opens a picker when tapped (when [onTap] is set).
class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({
    required this.label,
    required this.time,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String time;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(
                color: AppColors.neonViolet,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    final VoidCallback? tap = onTap;
    if (tap == null) return row;
    return SmartPressable(semanticLabel: semanticLabel, onTap: tap, child: row);
  }
}

class _ReflectionReminderSection extends ConsumerStatefulWidget {
  const _ReflectionReminderSection({required this.enabled});

  /// False while the main reminder switch is off.
  final bool enabled;

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
    // The switch is the request: ask in context first, once. Saving no
    // longer asks the system itself.
    if (value) await ensureNotificationPermission(context, ref);
    if (!mounted) return;
    final bool enabled = await ref
        .read(settingsUiActionsProvider)
        .setReflectionReminderEnabled(enabled: value, time: _time);
    if (!mounted) {
      return;
    }
    setState(() => _enabled = enabled);
    if (value && !enabled) _showSchedulingFailure();
  }

  void _showSchedulingFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Reminder could not be scheduled. Check notification permission and try again.',
            'No se pudo programar el recordatorio. Revisa el permiso de notificaciones e inténtalo de nuevo.',
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).brightness == Brightness.dark
                ? AppColors.neonViolet
                : const Color(0xFF6251A3),
            onPrimary: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF071426)
                : Colors.white,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    final scheduled = await ref
        .read(settingsUiActionsProvider)
        .setReflectionReminderTime(time: picked);
    if (!mounted) return;
    if (!scheduled) {
      setState(() => _enabled = false);
      _showSchedulingFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restoredSettingsRevisionProvider, (_, _) => _load());
    return _Section(
      label: journeyText(context, 'DAILY REFLECTION', 'REFLEXIÓN DIARIA'),
      accentColor: AppColors.neonViolet,
      child: Column(
        children: [
          _NeonToggleTile(
            title: journeyText(
              context,
              'Reflection Reminder',
              'Recordatorio de reflexión',
            ),
            value: _enabled,
            onChanged: widget.enabled ? _toggle : null,
          ),
          if (_enabled)
            SmartPressable(
              semanticLabel: journeyText(
                context,
                'Change reflection reminder time, current ${_time.format(context)}',
                'Cambiar la hora del recordatorio de reflexión; ahora es ${_time.format(context)}',
              ),
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
                      Expanded(
                        child: Text(
                          journeyText(
                            context,
                            'Reminder Time',
                            'Hora del recordatorio',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
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
  const _ReminderAutomationSection({required this.enabled});

  /// False while the main reminder switch is off.
  final bool enabled;

  @override
  ConsumerState<_ReminderAutomationSection> createState() =>
      _ReminderAutomationSectionState();
}

class _ReminderAutomationSectionState
    extends ConsumerState<_ReminderAutomationSection> {
  bool _goalEnabled = true;
  bool _habitEnabled = true;
  bool _taskEnabled = true;
  bool _overdueNudges = false;
  int _leadMinutes = 0;
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
      _taskEnabled = prefs.taskRemindersEnabled;
      _overdueNudges = prefs.taskOverdueNudgesEnabled;
      _leadMinutes = prefs.taskReminderLeadMinutes;
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

  Future<void> _toggleTask(bool value) async {
    await ref.read(settingsUiActionsProvider).setTaskRemindersEnabled(value);
    if (!mounted) return;
    setState(() => _taskEnabled = value);
  }

  Future<void> _toggleOverdue(bool value) async {
    setState(() => _overdueNudges = value);
    await ref
        .read(settingsUiActionsProvider)
        .setTaskOverdueNudgesEnabled(value);
  }

  Future<void> _setLead(int minutes) async {
    setState(() => _leadMinutes = minutes);
    await ref
        .read(settingsUiActionsProvider)
        .setTaskReminderLeadMinutes(minutes);
  }

  String _leadLabel(int minutes) => switch (minutes) {
    0 => journeyText(context, 'At the time', 'A la hora'),
    60 => journeyText(context, '1 hour before', '1 hora antes'),
    _ => journeyText(
      context,
      '$minutes minutes before',
      '$minutes minutos antes',
    ),
  };

  Future<void> _toggleDailyPlanning(bool value) async {
    final NotificationScheduleResult result = await ref
        .read(settingsUiActionsProvider)
        .setDailyPlanningReminder(enabled: value, time: _dailyPlanningTime);
    if (!mounted) return;
    setState(() => _dailyPlanningEnabled = value);
    if (!value) return;
    // Saved first; then ask in context. A grant rebuilds the reminder.
    final bool granted = await ensureNotificationPermission(context, ref);
    if (!mounted) return;
    if (result == NotificationScheduleResult.failed ||
        (result == NotificationScheduleResult.permissionDenied && !granted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journeyText(
              context,
              'Daily planning reminder is on, but it could not be set. Check notification permission and try again.',
              'El recordatorio de planificación diaria está activado, pero no se pudo programar. Revisa el permiso de notificaciones e inténtalo de nuevo.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickDailyPlanningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyPlanningTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).brightness == Brightness.dark
                ? AppColors.neonCyan
                : const Color(0xFF00627A),
            onPrimary: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF071426)
                : Colors.white,
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
    ref.listen(restoredSettingsRevisionProvider, (_, _) => _load());
    return _Section(
      label: journeyText(
        context,
        'REMINDER AUTOMATION',
        'AUTOMATIZACIÓN DE RECORDATORIOS',
      ),
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          _NeonToggleTile(
            title: journeyText(
              context,
              'Goal Reminders',
              'Recordatorios de metas',
            ),
            value: _goalEnabled,
            onChanged: widget.enabled ? _toggleGoal : null,
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Goal Reminder Rule',
              'Regla de recordatorios de metas',
            ),
            subtitle: journeyText(
              context,
              'At 9 AM three days before, the day before, and the morning a goal is due. Plus one "almost there" reminder when most of its steps are done.',
              'A las 9:00 tres días antes, el día anterior y la mañana en que vence la meta. Además, un aviso de "ya casi" cuando la mayoría de sus pasos estén hechos.',
            ),
          ),
          _NeonToggleTile(
            title: journeyText(
              context,
              'Habit Reminders',
              'Recordatorios de ritmos',
            ),
            value: _habitEnabled,
            onChanged: widget.enabled ? _toggleHabit : null,
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Habit Reminder Rule',
              'Regla de recordatorios de ritmos',
            ),
            subtitle: journeyText(
              context,
              'Each habit reminds you at the time you set with Set reminder on that habit: daily, Mondays, or the first of each month. Habits without a time stay quiet. Completed or skipped periods wait until the next period.',
              'Cada hábito te avisa a la hora que le pongas con Poner recordatorio: cada día, los lunes o el primer día del mes. Los hábitos sin hora no avisan. Los períodos completados u omitidos esperan hasta el siguiente período.',
            ),
          ),
          _NeonToggleTile(
            key: const Key('task-reminders-toggle'),
            title: journeyText(
              context,
              'Task Reminders',
              'Recordatorios de tareas',
            ),
            value: _taskEnabled,
            onChanged: widget.enabled ? _toggleTask : null,
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Task Reminder Rule',
              'Regla de recordatorios de tareas',
            ),
            subtitle: journeyText(
              context,
              'At a task\'s start time. Without one, when it is due: at its time, or at 9 AM when the deadline has no time. Finished tasks stay quiet. Only the next 20 are set at once.',
              'A la hora de inicio de la tarea. Si no tiene, cuando vence: a su hora, o a las 9:00 si la fecha límite no tiene hora. Las tareas terminadas no avisan. Solo se programan las 20 siguientes a la vez.',
            ),
          ),
          if (_taskEnabled)
            _PreferenceDropdown<int>(
              key: ValueKey<String>(
                'task-lead-$_leadMinutes-${widget.enabled}',
              ),
              label: journeyText(
                context,
                'Task reminder time',
                'Hora del recordatorio de tareas',
              ),
              value: _leadMinutes,
              items: <int>{
                ...ReminderOrchestratorService.taskLeadChoices,
                _leadMinutes,
              }.toList()..sort(),
              itemLabel: _leadLabel,
              onChanged: widget.enabled ? _setLead : null,
            ),
          _NeonToggleTile(
            key: const Key('overdue-nudges-toggle'),
            title: journeyText(context, 'Overdue nudges', 'Avisos de vencidos'),
            value: _overdueNudges,
            onChanged: widget.enabled ? _toggleOverdue : null,
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Overdue Nudge Rule',
              'Regla de avisos de vencidos',
            ),
            subtitle: journeyText(
              context,
              'One reminder at 9 AM the day after a task or goal was due, if it is still open.',
              'Un recordatorio a las 9:00 del día siguiente al vencimiento de una tarea o meta, si sigue pendiente.',
            ),
          ),
          _NeonToggleTile(
            title: journeyText(
              context,
              'Daily Planning Reminder',
              'Recordatorio de planificación diaria',
            ),
            value: _dailyPlanningEnabled,
            onChanged: widget.enabled ? _toggleDailyPlanning : null,
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Daily Planning Rule',
              'Regla de planificación diaria',
            ),
            subtitle: journeyText(
              context,
              'Triggers once each day at the selected planning time.',
              'Se activa una vez al día a la hora de planificación elegida.',
            ),
          ),
          if (_dailyPlanningEnabled)
            SmartPressable(
              semanticLabel: journeyText(
                context,
                'Change daily planning time, current ${_dailyPlanningTime.format(context)}',
                'Cambiar la hora de planificación diaria; ahora es ${_dailyPlanningTime.format(context)}',
              ),
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
                      Expanded(
                        child: Text(
                          journeyText(
                            context,
                            'Daily Planning Time',
                            'Hora de planificación diaria',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
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
