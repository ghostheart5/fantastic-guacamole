import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDeepLinkMode', () {
    test('parses the three known values', () {
      expect(parseDeepLinkMode('recovery'), DeepLinkMode.recovery);
      expect(parseDeepLinkMode('verify-email'), DeepLinkMode.verifyEmail);
      expect(parseDeepLinkMode('auth-callback'), DeepLinkMode.authCallback);
    });

    test('trims surrounding whitespace before matching', () {
      expect(parseDeepLinkMode('  recovery  '), DeepLinkMode.recovery);
      expect(parseDeepLinkMode('\tverify-email\n'), DeepLinkMode.verifyEmail);
    });

    test('is case-sensitive: differently-cased known values are rejected', () {
      expect(parseDeepLinkMode('Recovery'), isNull);
      expect(parseDeepLinkMode('RECOVERY'), isNull);
      expect(parseDeepLinkMode('Verify-Email'), isNull);
    });

    test('returns null for empty, whitespace-only, and null input', () {
      expect(parseDeepLinkMode(null), isNull);
      expect(parseDeepLinkMode(''), isNull);
      expect(parseDeepLinkMode('   '), isNull);
    });

    test('returns null for unrecognized values without throwing', () {
      expect(parseDeepLinkMode('not-a-real-mode'), isNull);
      expect(parseDeepLinkMode('recoveryy'), isNull);
      expect(parseDeepLinkMode('recover'), isNull);
    });

    test('rejects adversarial input without throwing', () {
      expect(() => parseDeepLinkMode('a' * 10000), returnsNormally);
      expect(parseDeepLinkMode('a' * 10000), isNull);

      expect(parseDeepLinkMode("'; DROP TABLE users; --"), isNull);
      expect(parseDeepLinkMode('recovery%00verify-email'), isNull);
      expect(parseDeepLinkMode('日本語リカバリー'), isNull);
      expect(parseDeepLinkMode('<script>alert(1)</script>'), isNull);
    });
  });
}
