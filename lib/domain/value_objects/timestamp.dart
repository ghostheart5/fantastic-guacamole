/// CHRONOSPARK-CLASS: PLANNED | Feature: Cross-cutting
///
/// Typed-primitive layer for the domain. Entities still use raw primitives, so
/// these are not yet adopted; they are kept as the intended target for a future
/// typed-domain pass. Before adoption they need ==/hashCode and const
/// constructors.
class Timestamp {
  Timestamp(this.value);

  final DateTime value;
}
