class EnergyLevel {
  EnergyLevel(double value) : value = _validate(value);

  final double value;

  static double _validate(double value) {
    if (value < 0 || value > 1) {
      throw ArgumentError.value(
        value,
        'value',
        'Energy must be between 0 and 1.',
      );
    }
    return value;
  }
}
