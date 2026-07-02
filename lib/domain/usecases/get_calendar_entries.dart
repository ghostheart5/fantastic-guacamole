import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';

class GetCalendarEntries {
  GetCalendarEntries(this.repository);

  final ICalendarRepository repository;

  Future<List<CalendarEntryEntity>> call() {
    return repository.getEntries();
  }
}
