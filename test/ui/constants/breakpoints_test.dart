import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidthClass.of', () {
    test('below the ultraCompact threshold is ultraCompact', () {
      expect(WidthClass.of(0), WidthClass.ultraCompact);
      expect(WidthClass.of(339), WidthClass.ultraCompact);
    });

    test('at and above ultraCompact but below compact is compact', () {
      expect(WidthClass.of(340), WidthClass.compact);
      expect(WidthClass.of(389), WidthClass.compact);
    });

    test('at and above the compact threshold is regular', () {
      expect(WidthClass.of(390), WidthClass.regular);
      expect(WidthClass.of(1200), WidthClass.regular);
    });
  });
}
