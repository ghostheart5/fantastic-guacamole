import 'package:intl/intl.dart';

class DateTimeFormats {
  DateTimeFormats._();

  static String timelineDay(DateTime value) {
    return DateFormat('EEEE, MMM d').format(value.toLocal());
  }

  static String timelineTime(DateTime value) {
    return DateFormat('h:mm a').format(value.toLocal());
  }

  static String localMonthDay(DateTime value) {
    return DateFormat('MMM d', 'en_US').format(value.toLocal());
  }

  static String relativeLocalDateTime(DateTime value, {DateTime? now}) {
    final DateTime local = value.toLocal();
    final DateTime reference = (now ?? DateTime.now()).toLocal();
    // Compare calendar dates, not elapsed local-midnight hours: DST days
    // can contain 23 or 25 hours.
    final int difference = DateTime.utc(local.year, local.month, local.day)
        .difference(
          DateTime.utc(reference.year, reference.month, reference.day),
        )
        .inDays;
    final String date = switch (difference) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => localMonthDay(local),
    };
    return '$date · ${timelineTime(local)}';
  }

  static String reportTimestamp(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
  }

  static String readableDateTime(DateTime value) {
    return DateFormat('MMM d, yyyy h:mm a').format(value);
  }

  static String dateShort(DateTime value) {
    return DateFormat('MMM d, y').format(value);
  }
}
