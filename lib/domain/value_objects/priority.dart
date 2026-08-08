/// CHRONOSPARK-CLASS: PLANNED | Feature: Goals/tasks
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass. Before adoption they need ==/hashCode and const
/// constructors.
class Priority {
  Priority(int value) : value = _validate(value);

  final int value;

  static int _validate(int value) {
    if (value < 1 || value > 5) {
      throw ArgumentError.value(value, 'value', 'Priority must be 1-5.');
    }
    return value;
  }
}
