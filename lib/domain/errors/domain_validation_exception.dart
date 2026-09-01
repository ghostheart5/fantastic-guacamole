/// CHRONOSPARK-CLASS: SHIPPING | Feature: Cross-cutting validation
final class DomainValidationException implements Exception {
  const DomainValidationException({
    required this.code,
    required this.message,
    this.field,
  });

  final String code;
  final String message;
  final String? field;

  @override
  String toString() {
    final String fieldSuffix = field == null ? '' : ', field: $field';
    return 'DomainValidationException($code$fieldSuffix): $message';
  }
}
