/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass. Before adoption they need ==/hashCode and const
/// constructors.
class XpValue {
  XpValue(int value) : value = _validate(value);

  final int value;

  static int _validate(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'XP cannot be negative.');
    }
    return value;
  }
}
