import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';

class FakeCalendarRepository implements ICalendarRepository {
  FakeCalendarRepository([List<CalendarEntryEntity>? seed])
    : _entries = <String, CalendarEntryEntity>{
        for (final CalendarEntryEntity entry
            in (seed ?? const <CalendarEntryEntity>[]))
          entry.id: entry,
      };

  final Map<String, CalendarEntryEntity> _entries;

  @override
  Future<List<CalendarEntryEntity>> getEntries() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> removeEntry(String id) async {
    _entries.remove(id);
  }

  @override
  Future<void> saveEntry(CalendarEntryEntity entry) async {
    _entries[entry.id] = entry;
  }
}
