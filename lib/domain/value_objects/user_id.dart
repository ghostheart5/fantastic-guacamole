class UserId {
  UserId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'User id cannot be empty.');
    }
    return value;
  }
}
