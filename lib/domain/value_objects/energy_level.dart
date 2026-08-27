/// CHRONOSPARK-CLASS: PLANNED | Feature: SI Console
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass. Before adoption they need ==/hashCode and const
/// constructors.
class EnergyLevel {
  EnergyLevel(double value) : value = _validate(value);

  final double value;

  static double _validate(double value) {
    if (value < 0 || value > 1) {
      throw ArgumentError.value(
        value,
        'value',
        'Energy must be between 0 and 1.',
      );
    }
    return value;
  }
}
