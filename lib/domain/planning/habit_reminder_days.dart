// CHRONOSPARK-CLASS: SHIPPING | Feature: Habit reminder days
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';

/// Words for the days a habit reminder arrives on, in English or Spanish.
/// Pure, so screens and reminder text can share it in either language.
abstract final class HabitReminderDays {
  static const List<String> _english = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _spanish = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const List<String> _englishShort = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _spanishShort = <String>[
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];

  /// The day of the month to offer in pickers, in order.
  static final List<int> monthDays = List<int>.unmodifiable(<int>[
    for (int day = 1; day <= 28; day++) day,
    HabitEntity.lastDayOfMonth,
  ]);

  /// "Wednesday" / "miércoles" for an ISO weekday (1 = Monday).
  static String weekdayName(int weekday, {required bool spanish}) =>
      (spanish ? _spanish : _english)[weekday - 1];

  /// "Wed" / "mié" for an ISO weekday.
  static String shortWeekdayName(int weekday, {required bool spanish}) =>
      (spanish ? _spanishShort : _englishShort)[weekday - 1];

  /// "15th" / "Día 15", or "Last day" / "Último día".
  static String dayOfMonthName(int day, {required bool spanish}) {
    if (day == HabitEntity.lastDayOfMonth) {
      return spanish ? 'Último día' : 'Last day';
    }
    return spanish ? 'Día $day' : _ordinal(day);
  }

  /// When the reminder arrives, after its time: "every day", "every Monday
  /// and Thursday", "on the 15th of each month" (and the Spanish forms).
  /// Without chosen days a weekly habit reminds on Monday and a monthly one
  /// on the 1st.
  static String describe({
    required HabitCadence cadence,
    List<int>? weekdays,
    int? dayOfMonth,
    required bool spanish,
  }) {
    switch (cadence) {
      case HabitCadence.daily:
        return spanish ? 'cada día' : 'every day';
      case HabitCadence.weekly:
        final List<int> days =
            HabitEntity.normalizeReminderWeekdays(weekdays) ??
            const <int>[DateTime.monday];
        if (days.length == 7) return spanish ? 'cada día' : 'every day';
        final String names = _joined(
          days.map((int day) => weekdayName(day, spanish: spanish)).toList(),
          spanish ? 'y' : 'and',
        );
        return spanish ? 'cada $names' : 'every $names';
      case HabitCadence.monthly:
        final int day =
            HabitEntity.normalizeReminderDayOfMonth(dayOfMonth) ?? 1;
        if (day == HabitEntity.lastDayOfMonth) {
          return spanish
              ? 'el último día de cada mes'
              : 'on the last day of each month';
        }
        return spanish
            ? 'el día $day de cada mes'
            : 'on the ${_ordinal(day)} of each month';
    }
  }

  static String _joined(List<String> words, String and) {
    if (words.length == 1) return words.single;
    return '${words.sublist(0, words.length - 1).join(', ')} $and '
        '${words.last}';
  }

  static String _ordinal(int day) {
    final int lastTwo = day % 100;
    final String suffix = lastTwo >= 11 && lastTwo <= 13
        ? 'th'
        : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$day$suffix';
  }
}
