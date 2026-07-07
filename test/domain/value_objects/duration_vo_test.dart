import 'package:fantastic_guacamole/domain/value_objects/duration_vo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DurationVo', () {
    test('accepts zero and positive durations', () {
      expect(DurationVo(Duration.zero).value, Duration.zero);
      expect(DurationVo(const Duration(minutes: 30)).value, const Duration(minutes: 30));
    });

    test('rejects negative durations', () {
      expect(() => DurationVo(const Duration(minutes: -1)), throwsArgumentError);
    });
  });
}
