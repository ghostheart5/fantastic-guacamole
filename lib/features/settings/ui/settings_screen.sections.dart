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
        ],
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

  String _formatLabel(String raw) {
    final String normalized = raw.trim().toLowerCase();
    final List<String> words = normalized
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    return words
        .map((String word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

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
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
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
                  _formatLabel(label),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
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
    this.switchKey,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Switch(
            key: switchKey,
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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

class _MotionProfileTile extends StatelessWidget {
  const _MotionProfileTile({required this.value, required this.onChanged});

  final MotionProfile value;
  final ValueChanged<MotionProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    String labelFor(MotionProfile profile) {
      switch (profile) {
        case MotionProfile.calm:
          return 'Calm';
        case MotionProfile.standard:
          return 'Standard';
        case MotionProfile.expressive:
          return 'Expressive';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Motion profile',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MotionProfile.values
                .map((MotionProfile profile) {
                  final bool selected = value == profile;
                  return ChoiceChip(
                    label: Text(labelFor(profile)),
                    selected: selected,
                    onSelected: (_) => onChanged(profile),
                    selectedColor: AppColors.neonCyan.withValues(alpha: 0.16),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: selected
                          ? AppColors.neonCyan.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.16),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.neonCyan : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 4),
          const Text(
            'Calm reduces motion intensity. Expressive increases visual emphasis.',
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }
}
