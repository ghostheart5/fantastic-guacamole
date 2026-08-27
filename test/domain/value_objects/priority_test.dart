import 'package:fantastic_guacamole/domain/value_objects/priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Priority', () {
    test('accepts values from 1 to 5 inclusive', () {
      expect(Priority(1).value, 1);
      expect(Priority(5).value, 5);
    });

    test('rejects values outside 1 to 5', () {
      expect(() => Priority(0), throwsArgumentError);
      expect(() => Priority(6), throwsArgumentError);
    });
  });
}
