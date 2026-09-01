import 'package:fantastic_guacamole/domain/value_objects/domain_value_object.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Goals/tasks
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass.
final class TaskId extends DomainValueObject<String> {
  TaskId(String value) : super(_validate(value));

  static String _validate(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Task id cannot be empty.');
    }
    return value.trim();
  }
}
