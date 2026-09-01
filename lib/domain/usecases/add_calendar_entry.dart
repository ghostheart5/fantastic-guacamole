import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/errors/domain_validation_exception.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';
import 'package:fantastic_guacamole/domain/policies/calendar_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Calendar/timeline
///
/// Persisted-calendar path. Gated by CalendarPolicy.isValidEntry.
class AddCalendarEntry {
  AddCalendarEntry(this.repository);

  final ICalendarRepository repository;

  Future<void> call(CalendarEntryEntity entry) async {
    if (!CalendarPolicy.isValidEntry(entry)) {
      throw const DomainValidationException(
        code: 'invalid_calendar_entry',
        message: 'Calendar entry fields do not satisfy the calendar policy.',
      );
    }
    await repository.saveEntry(entry);
  }
}
