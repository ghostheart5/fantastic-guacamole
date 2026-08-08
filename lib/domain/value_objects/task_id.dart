/// CHRONOSPARK-CLASS: PLANNED | Feature: Goals/tasks
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass. Before adoption they need ==/hashCode and const
/// constructors.
class TaskId {
  TaskId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Task id cannot be empty.');
    }
    return value;
  }
}
