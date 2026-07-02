import 'package:intl/intl.dart';

class DateUtilsCS {
  // -----------------------------
  // BASIC FORMATTERS
  // -----------------------------

  static String format(DateTime date, {String pattern = "yyyy-MM-dd"}) {
    return DateFormat(pattern).format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat("HH:mm").format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat("yyyy-MM-dd HH:mm").format(date);
  }

  static String formatHuman(DateTime date) {
    return DateFormat("MMM d, yyyy").format(date);
  }

  // -----------------------------
  // PARSING
  // -----------------------------

  static DateTime? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  // -----------------------------
  // DIFFERENCE CALCULATIONS
  // -----------------------------

  static int minutesBetween(DateTime a, DateTime b) {
    return b.difference(a).inMinutes;
  }

  static int hoursBetween(DateTime a, DateTime b) {
    return b.difference(a).inHours;
  }

  static int daysBetween(DateTime a, DateTime b) {
    return b.difference(a).inDays;
  }

  static Duration durationBetween(DateTime a, DateTime b) {
    return b.difference(a);
  }

  // -----------------------------
  // START / END OF DAY
  // -----------------------------

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  // -----------------------------
  // WEEK HELPERS
  // -----------------------------

  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  static DateTime endOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(
      date.year,
      date.month,
      date.day + (7 - weekday),
      23,
      59,
      59,
      999,
    );
  }

  // -----------------------------
  // MONTH HELPERS
  // -----------------------------

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime endOfMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }

  // -----------------------------
  // TIMELINE UTILITIES (ChronoSpark)
  // -----------------------------

  /// Predicts the end time of a task based on duration in minutes.
  static DateTime predictEnd(DateTime start, int durationMinutes) {
    return start.add(Duration(minutes: durationMinutes));
  }

  /// Returns true if two time ranges overlap.
  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  /// Returns a human-readable duration like "1h 20m".
  static String humanDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;

    if (h == 0) return "${m}m";
    if (m == 0) return "${h}h";
    return "${h}h ${m}m";
  }

  /// Converts minutes to a readable string.
  static String minutesToHuman(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (h == 0) return "${m}m";
    if (m == 0) return "${h}h";
    return "${h}h ${m}m";
  }

  // -----------------------------
  // SAFE NULL HANDLING
  // -----------------------------

  static bool isNullOrEmpty(DateTime? date) {
    return date == null;
  }

  static DateTime orNow(DateTime? date) {
    return date ?? DateTime.now();
  }
}
