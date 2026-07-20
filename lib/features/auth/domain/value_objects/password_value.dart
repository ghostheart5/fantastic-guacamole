class PasswordValue {
  const PasswordValue._(this.value);

  factory PasswordValue(String value) {
    final String trimmed = value.trim();
    if (trimmed.length < 8) {
      throw const FormatException('Password must be at least 8 characters long.');
    }
    return PasswordValue._(trimmed);
  }

  final String value;

  bool get isStrong {
    final String current = value;
    return current.length >= 8 &&
        current.contains(RegExp(r'[A-Z]')) &&
        current.contains(RegExp(r'[a-z]')) &&
        current.contains(RegExp(r'[0-9]'));
  }

  @override
  bool operator ==(Object other) => other is PasswordValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PasswordValue(length: ${value.length})';
}
