import 'package:intl/intl.dart';

extension DateExt on DateTime {
  // ------------------------------------------------------------------
  // Formatting
  // ------------------------------------------------------------------

  /// "1/25"
  String get short => '$month/$day';

  /// "Jan 25, 2025"
  String get human => DateFormat('MMM d, yyyy').format(this);

  /// "2025-01-25"
  String get iso => DateFormat('yyyy-MM-dd').format(this);

  /// "14:30"
  String get timeHHmm => DateFormat('HH:mm').format(this);

  /// "2:30 PM"
  String get timeHmma => DateFormat('h:mm a').format(this);

  /// "Sat, Jan 25"
  String get dayLabel => DateFormat('EEE, MMM d').format(this);

  // ------------------------------------------------------------------
  // Start / end boundaries
  // ------------------------------------------------------------------

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  DateTime get startOfWeek {
    return DateTime(year, month, day - (weekday - 1));
  }

  DateTime get endOfWeek {
    return DateTime(year, month, day + (7 - weekday), 23, 59, 59, 999);
  }

  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth =>
      DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));

  // ------------------------------------------------------------------
  // Comparisons
  // ------------------------------------------------------------------

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());
  bool get isTomorrow => isSameDay(DateTime.now().add(const Duration(days: 1)));
  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));

  bool get isPast => isBefore(DateTime.now());
  bool get isFuture => isAfter(DateTime.now());
  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  // ------------------------------------------------------------------
  // Differences
  // ------------------------------------------------------------------

  int daysUntil(DateTime other) =>
      other.startOfDay.difference(startOfDay).inDays;
  int get daysFromNow => daysUntil(DateTime.now());
}
