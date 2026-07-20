class EmailAddress {
  const EmailAddress._(this.value);

  factory EmailAddress(String value) {
    final String normalized = value.trim().toLowerCase();
    if (!normalized.contains('@') || normalized.startsWith('@') || normalized.endsWith('@')) {
      throw const FormatException('A valid email address is required.');
    }
    if (normalized.split('@').length != 2) {
      throw const FormatException('A valid email address is required.');
    }
    return EmailAddress._(normalized);
  }

  final String value;

  bool get isValid => value.isNotEmpty && value.contains('@');

  @override
  bool operator ==(Object other) => other is EmailAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
