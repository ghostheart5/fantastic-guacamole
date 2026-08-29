import 'package:fantastic_guacamole/domain/value_objects/domain_value_object.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: SI Console
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass.
final class EnergyLevel extends DomainValueObject<double> {
  EnergyLevel(double value) : super(_validate(value));

  static double _validate(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(
        value,
        'value',
        'Energy must be between 0 and 1.',
      );
    }
    return value;
  }
}
