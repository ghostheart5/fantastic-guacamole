import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';

abstract class ICalendarRepository {
  Future<List<CalendarEntryEntity>> getEntries();
  Future<void> saveEntry(CalendarEntryEntity entry);
  Future<void> removeEntry(String id);
}
