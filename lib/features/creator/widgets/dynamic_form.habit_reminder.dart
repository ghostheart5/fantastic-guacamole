part of 'dynamic_form.dart';

/// The optional reminder row of the habit form: "Any time" (no reminder, the
/// default) or a time, with the weekdays (weekly) or the day (monthly) it
/// arrives on.
class _HabitReminderRow extends StatelessWidget {
  const _HabitReminderRow({
    required this.cadence,
    required this.minutes,
    required this.weekdays,
    required this.dayOfMonth,
    required this.enabled,
    required this.onMinutes,
    required this.onWeekdays,
    required this.onDayOfMonth,
  });

  /// Morning, midday and evening presets, as minutes after midnight.
  static const List<int> presets = <int>[8 * 60, 12 * 60, 20 * 60];

  final HabitCadence cadence;
  final int? minutes;
  final List<int>? weekdays;
  final int? dayOfMonth;
  final bool enabled;
  final ValueChanged<int?> onMinutes;
  final ValueChanged<List<int>> onWeekdays;
  final ValueChanged<int> onDayOfMonth;

  String _time(BuildContext context, int value) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: value ~/ 60, minute: value % 60));

  Future<void> _pickOther(BuildContext context) async {
    final int start = minutes ?? 18 * 60;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
    );
    if (picked != null) onMinutes(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final bool es = ChronoSparkLocalizations.of(context).isSpanish;
    final int? chosen = minutes;
    final bool other = chosen != null && !presets.contains(chosen);
    String presetName(int value) => switch (value) {
      480 => es ? 'Mañana' : 'Morning',
      720 => es ? 'Mediodía' : 'Midday',
      _ => es ? 'Noche' : 'Evening',
    };
    Widget chip(Key key, String label, bool selected, VoidCallback onTap) =>
        ChoiceChip(
          key: key,
          label: Text(label),
          selected: selected,
          onSelected: enabled ? (_) => onTap() : null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 18),
        _FieldLabel(text: es ? 'Recordatorio' : 'Reminder'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            chip(
              const Key('creator-habit-reminder-any'),
              es ? 'A cualquier hora' : 'Any time',
              chosen == null,
              () => onMinutes(null),
            ),
            for (final int preset in presets)
              chip(
                Key('creator-habit-reminder-$preset'),
                '${presetName(preset)} ${_time(context, preset)}',
                chosen == preset,
                () => onMinutes(preset),
              ),
            chip(
              const Key('creator-habit-reminder-other'),
              other
                  ? _time(context, chosen)
                  : (es ? 'Otra hora…' : 'Other time…'),
              other,
              () => _pickOther(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          chosen == null
              ? (es
                    ? 'Sin recordatorio. Elige una hora para recibir uno.'
                    : 'No reminder. Choose a time to get one.')
              : '${es ? 'Recordatorio a las' : 'Reminder at'} '
                    '${_time(context, chosen)} '
                    '${HabitReminderDays.describe(cadence: cadence, weekdays: weekdays, dayOfMonth: dayOfMonth, spanish: es)}',
          key: const Key('creator-habit-reminder-summary'),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        if (chosen != null && cadence == HabitCadence.weekly) ...<Widget>[
          const SizedBox(height: 10),
          HabitWeekdayChooser(
            selected: weekdays,
            spanish: es,
            enabled: enabled,
            onChanged: onWeekdays,
          ),
        ],
        if (chosen != null && cadence == HabitCadence.monthly) ...<Widget>[
          const SizedBox(height: 10),
          _DropdownShell(
            accent: AppColors.memoryAmber,
            child: HabitMonthDayChooser(
              selected: dayOfMonth,
              spanish: es,
              enabled: enabled,
              onChanged: onDayOfMonth,
            ),
          ),
        ],
      ],
    );
  }
}
