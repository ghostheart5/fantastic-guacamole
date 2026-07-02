class DurationVo {
  DurationVo(Duration value) : value = _validate(value);

  final Duration value;

  static Duration _validate(Duration value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'Duration cannot be negative.');
    }
    return value;
  }
}
