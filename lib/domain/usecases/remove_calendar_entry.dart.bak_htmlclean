import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';

class RemoveCalendarEntry {
  RemoveCalendarEntry(this.repository);

  final ICalendarRepository repository;

  Future<void> call(String id) {
    return repository.removeEntry(id);
  }
}
