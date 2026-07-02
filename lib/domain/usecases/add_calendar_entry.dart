import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';
import 'package:fantastic_guacamole/domain/policies/calendar_policy.dart';

class AddCalendarEntry {
  AddCalendarEntry(this.repository);

  final ICalendarRepository repository;

  Future<void> call(CalendarEntryEntity entry) async {
    if (!CalendarPolicy.isValidEntry(entry)) {
      throw Exception('Invalid calendar entry');
    }
    await repository.saveEntry(entry);
  }
}
