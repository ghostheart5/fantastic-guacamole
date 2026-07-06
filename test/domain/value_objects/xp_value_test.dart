import 'package:fantastic_guacamole/domain/value_objects/xp_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XpValue', () {
    test('accepts zero and positive XP', () {
      expect(XpValue(0).value, 0);
      expect(XpValue(250).value, 250);
    });

    test('rejects negative XP', () {
      expect(() => XpValue(-1), throwsArgumentError);
    });
  });
}
