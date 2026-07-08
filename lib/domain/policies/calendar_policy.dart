import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';

class CalendarPolicy {
  static const bool supportsRecurringEntries = false;

  static bool isValidEntry(CalendarEntryEntity entry) {
    if (entry.title.trim().isEmpty) return false;
    if (!entry.end.isAfter(entry.start)) return false;
    return true;
  }

  static bool overlaps(CalendarEntryEntity a, CalendarEntryEntity b) {
    if (!isValidEntry(a) || !isValidEntry(b)) return false;
    return a.start.isBefore(b.end) && b.start.isBefore(a.end);
  }

  static bool canPlaceEntry({
    required CalendarEntryEntity candidate,
    required List<CalendarEntryEntity> dayEntries,
  }) {
    if (!isValidEntry(candidate)) return false;
    if (dayEntries.isEmpty) return true;

    for (final CalendarEntryEntity existing in dayEntries) {
      if (overlaps(existing, candidate)) {
        return false;
      }
    }
    return true;
  }
}
