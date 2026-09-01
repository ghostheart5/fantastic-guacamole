/// CHRONOSPARK-CLASS: PLANNED | Feature: Typed domain primitives
abstract class DomainValueObject<T> {
  const DomainValueObject(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is DomainValueObject<T> &&
          other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => '$runtimeType($value)';
}
