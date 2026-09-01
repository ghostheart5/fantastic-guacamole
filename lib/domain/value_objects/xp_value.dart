import 'package:fantastic_guacamole/domain/value_objects/domain_value_object.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass.
final class XpValue extends DomainValueObject<int> {
  XpValue(int value) : super(_validate(value));

  static int _validate(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'XP cannot be negative.');
    }
    return value;
  }
}
