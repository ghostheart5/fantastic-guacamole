class StreakValue {
  StreakValue(int value) : value = _validate(value);

  final int value;

  static int _validate(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Streak cannot be negative.');
    }
    return value;
  }
}
