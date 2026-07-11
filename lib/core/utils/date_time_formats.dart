import 'package:intl/intl.dart';

class DateTimeFormats {
  DateTimeFormats._();

  static String timelineDay(DateTime value) {
    return DateFormat('EEEE, MMM d').format(value);
  }

  static String timelineTime(DateTime value) {
    return DateFormat('h:mm a').format(value);
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
