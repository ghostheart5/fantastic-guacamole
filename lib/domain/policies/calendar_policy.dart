import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';

class CalendarPolicy {
  static bool isValidEntry(CalendarEntryEntity entry) {
    if (entry.title.trim().isEmpty) return false;
    if (!entry.end.isAfter(entry.start)) return false;
    return true;
  }
}
