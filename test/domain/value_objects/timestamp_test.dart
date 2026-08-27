import 'package:fantastic_guacamole/domain/value_objects/timestamp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timestamp', () {
    test('stores the provided DateTime value', () {
      final date = DateTime.utc(2026, 7, 5, 12, 34, 56);

      final timestamp = Timestamp(date);

      expect(timestamp.value, date);
    });
  });
}
