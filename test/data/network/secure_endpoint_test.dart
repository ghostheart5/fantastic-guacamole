import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSecureHttpsEndpoint', () {
    test('returns a Uri for a valid HTTPS URL', () {
      final Uri? result = parseSecureHttpsEndpoint(
        'https://chronospark.app/functions/v1/ai',
      );
      expect(result, isNotNull);
      expect(result!.scheme, 'https');
      expect(result.host, 'chronospark.app');
    });

    test('accepts a URL with a path and query string', () {
      final Uri? result = parseSecureHttpsEndpoint(
        'https://example.supabase.co/functions/v1/verify-receipt?key=value',
      );
      expect(result, isNotNull);
    });

    test('returns null for an HTTP URL', () {
      expect(parseSecureHttpsEndpoint('http://chronospark.app/api'), isNull);
    });

    test('returns null for a URL with embedded user info', () {
      expect(
        parseSecureHttpsEndpoint('******example.com/api'),
        isNull,
      );
    });

    test('returns null for an empty string', () {
      expect(parseSecureHttpsEndpoint(''), isNull);
    });

    test('returns null for a whitespace-only string', () {
      expect(parseSecureHttpsEndpoint('   '), isNull);
    });

    test('returns null for a plain hostname without scheme', () {
      expect(parseSecureHttpsEndpoint('chronospark.app'), isNull);
    });

    test('returns null for a non-URL string', () {
      expect(parseSecureHttpsEndpoint('not-a-url'), isNull);
    });

    test('trims leading and trailing whitespace before parsing', () {
      final Uri? result = parseSecureHttpsEndpoint(
        '  https://chronospark.app/api  ',
      );
      expect(result, isNotNull);
      expect(result!.host, 'chronospark.app');
    });

    test('returns null for a URL with a missing host', () {
      // "https:///path" has scheme=https but an empty host.
      expect(parseSecureHttpsEndpoint('https:///path'), isNull);
    });
  });
}
