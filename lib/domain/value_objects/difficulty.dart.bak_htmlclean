class Difficulty {
  Difficulty(int value) : value = _validate(value);

  final int value;

  static int _validate(int value) {
    if (value < 1 || value > 5) {
      throw ArgumentError.value(value, 'value', 'Difficulty must be 1-5.');
    }
    return value;
  }
}
