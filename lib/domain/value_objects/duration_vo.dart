/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass. Before adoption they need ==/hashCode and const
/// constructors.
class DurationVo {
  DurationVo(Duration value) : value = _validate(value);

  final Duration value;

  static Duration _validate(Duration value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'Duration cannot be negative.');
    }
    return value;
  }
}
