import 'package:intl/intl.dart';

class TimeUtils {
  // -----------------------------
  // BASIC FORMATTERS
  // -----------------------------

  static String formatHHmm(DateTime time) {
    return DateFormat("HH:mm").format(time);
  }

  static String formatHmma(DateTime time) {
    return DateFormat("h:mm a").format(time);
  }

  static String formatFull(DateTime time) {
    return DateFormat("yyyy-MM-dd HH:mm:ss").format(time);
  }

  static String formatCompact(DateTime time) {
    return DateFormat("HHmm").format(time);
  }

  // -----------------------------
  // PARSING
  // -----------------------------

  static DateTime? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return DateFormat("HH:mm").parse(value);
    } catch (_) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
  }

  // -----------------------------
  // DURATION HELPERS
  // -----------------------------

  static Duration minutes(int m) => Duration(minutes: m);
  static Duration hours(int h) => Duration(hours: h);
  static Duration seconds(int s) => Duration(seconds: s);

  static int toMinutes(Duration d) => d.inMinutes;
  static int toHours(Duration d) => d.inHours;

  static String humanDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;

    if (h == 0) return "${m}m";
    if (m == 0) return "${h}h";
    return "${h}h ${m}m";
  }

  // -----------------------------
  // ADD / SUBTRACT TIME
  // -----------------------------

  static DateTime addMinutes(DateTime time, int minutes) {
    return time.add(Duration(minutes: minutes));
  }

  static DateTime subtractMinutes(DateTime time, int minutes) {
    return time.subtract(Duration(minutes: minutes));
  }

  static DateTime addHours(DateTime time, int hours) {
    return time.add(Duration(hours: hours));
  }

  static DateTime subtractHours(DateTime time, int hours) {
    return time.subtract(Duration(hours: hours));
  }

  // -----------------------------
  // TIME DIFFERENCE
  // -----------------------------

  static int minutesBetween(DateTime a, DateTime b) {
    return b.difference(a).inMinutes;
  }

  static int secondsBetween(DateTime a, DateTime b) {
    return b.difference(a).inSeconds;
  }

  static Duration durationBetween(DateTime a, DateTime b) {
    return b.difference(a);
  }

  // -----------------------------
  // ROUNDING TO NEAREST BLOCK
  // -----------------------------

  static DateTime roundToNearestMinutes(DateTime time, int block) {
    final int totalMinutes = time.hour * 60 + time.minute;
    final int rounded = ((totalMinutes / block).round() * block).clamp(0, 1439);
    return DateTime(
      time.year,
      time.month,
      time.day,
      rounded ~/ 60,
      rounded % 60,
    );
  }

  static DateTime floorToNearestMinutes(DateTime time, int block) {
    final int totalMinutes = time.hour * 60 + time.minute;
    final int floored = (totalMinutes ~/ block) * block;
    return DateTime(
      time.year,
      time.month,
      time.day,
      floored ~/ 60,
      floored % 60,
    );
  }

  static DateTime ceilToNearestMinutes(DateTime time, int block) {
    final int totalMinutes = time.hour * 60 + time.minute;
    final int ceiled = (((totalMinutes + block - 1) ~/ block) * block).clamp(
      0,
      1439,
    );
    return DateTime(time.year, time.month, time.day, ceiled ~/ 60, ceiled % 60);
  }

  // -----------------------------
  // CHRONOSPARK TIMELINE HELPERS
  // -----------------------------

  /// Converts a time into minutes since midnight.
  static int toDayMinutes(DateTime time) {
    return time.hour * 60 + time.minute;
  }

  /// Converts minutes since midnight back into a DateTime.
  static DateTime fromDayMinutes(DateTime base, int minutes) {
    return DateTime(
      base.year,
      base.month,
      base.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  /// Predicts end time of a task based on duration.
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

  /// Converts timeline pixel height to minutes.
  static int pxToMinutes(double px, double pxPerMinute) {
    return (px / pxPerMinute).round();
  }

  /// Converts minutes to timeline pixel height.
  static double minutesToPx(int minutes, double pxPerMinute) {
    return minutes * pxPerMinute;
  }

  // -----------------------------
  // NULL-SAFE HELPERS
  // -----------------------------

  static DateTime orNow(DateTime? time) => time ?? DateTime.now();

  static bool isNull(DateTime? time) => time == null;

  static bool isBefore(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.isBefore(b);
  }

  static bool isAfter(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.isAfter(b);
  }
}
