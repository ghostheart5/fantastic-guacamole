import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Calendar/timeline
///
/// Bound to CalendarRepository; UI renders CalendarService output today.
abstract class ICalendarRepository {
  Future<List<CalendarEntryEntity>> getEntries();
  Future<void> saveEntry(CalendarEntryEntity entry);
  Future<void> removeEntry(String id);
}
