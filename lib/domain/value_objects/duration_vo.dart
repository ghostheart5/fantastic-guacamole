import 'package:fantastic_guacamole/domain/value_objects/domain_value_object.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Planning/work blocks
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass.
final class DurationVo extends DomainValueObject<Duration> {
  DurationVo(Duration value) : super(_validate(value));

  static Duration _validate(Duration value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'Duration cannot be negative.');
    }
    return value;
  }
}
