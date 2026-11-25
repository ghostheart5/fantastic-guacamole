import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/planning/habit_reminder_days.dart';
import 'package:flutter/material.dart';

/// Chooses the weekdays a weekly habit reminds on. Null [selected] shows
/// Monday, the day used before days could be chosen. At least one day stays
/// chosen.
class HabitWeekdayChooser extends StatelessWidget {
  const HabitWeekdayChooser({
    super.key,
    required this.selected,
    required this.spanish,
    required this.onChanged,
    this.enabled = true,
  });

  final List<int>? selected;
  final bool spanish;
  final bool enabled;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<int> days = selected ?? const <int>[DateTime.monday];
    // Turns [day] on or off; the last chosen day stays on.
    void toggle(int day, bool on) {
      final Set<int> next = <int>{...days};
      if (on) {
        next.add(day);
      } else if (next.length > 1) {
        next.remove(day);
      }
      onChanged(next.toList()..sort());
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (int day = DateTime.monday; day <= DateTime.sunday; day++)
          // The full day name is read out instead of the short one, so the
          // node also carries the chip's tap and selected state.
          Semantics(
            label: HabitReminderDays.weekdayName(day, spanish: spanish),
            excludeSemantics: true,
            button: true,
            enabled: enabled,
            selected: days.contains(day),
            onTap: enabled ? () => toggle(day, !days.contains(day)) : null,
            child: FilterChip(
              key: ValueKey<String>('habit-reminder-weekday-$day'),
              label: Text(
                HabitReminderDays.shortWeekdayName(day, spanish: spanish),
              ),
              selected: days.contains(day),
              showCheckmark: false,
              onSelected: enabled ? (bool on) => toggle(day, on) : null,
            ),
          ),
      ],
    );
  }
}

/// Chooses the day a monthly habit reminds on: the 1st to the 28th, or the
/// last day of the month. Null [selected] shows the 1st.
class HabitMonthDayChooser extends StatelessWidget {
  const HabitMonthDayChooser({
    super.key,
    required this.selected,
    required this.spanish,
    required this.onChanged,
    this.enabled = true,
  });

  final int? selected;
  final bool spanish;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      key: const ValueKey<String>('habit-reminder-month-day'),
      value: HabitEntity.normalizeReminderDayOfMonth(selected) ?? 1,
      isExpanded: true,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(color: Theme.of(context).colorScheme.onSurface),
      onChanged: !enabled
          ? null
          : (int? value) {
              if (value != null) onChanged(value);
            },
      items: <DropdownMenuItem<int>>[
        for (final int day in HabitReminderDays.monthDays)
          DropdownMenuItem<int>(
            value: day,
            child: Text(
              HabitReminderDays.dayOfMonthName(day, spanish: spanish),
            ),
          ),
      ],
    );
  }
}
