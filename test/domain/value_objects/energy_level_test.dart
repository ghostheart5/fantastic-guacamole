import 'package:fantastic_guacamole/domain/value_objects/energy_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnergyLevel', () {
    test('accepts values in [0, 1]', () {
      expect(EnergyLevel(0).value, 0);
      expect(EnergyLevel(1).value, 1);
      expect(EnergyLevel(0.42).value, 0.42);
    });

    test('rejects values below 0 or above 1', () {
      expect(() => EnergyLevel(-0.01), throwsArgumentError);
      expect(() => EnergyLevel(1.01), throwsArgumentError);
    });
  });
}
