class XpValue {
  XpValue(int value) : value = _validate(value);

  final int value;

  static int _validate(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'XP cannot be negative.');
    }
    return value;
  }
}
