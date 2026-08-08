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
      // Uri.userInfo is non-empty for "******host/path" URLs.
      // parseSecureHttpsEndpoint rejects these because a non-empty userInfo
      // component indicates credentials embedded in the URL.
      const String urlWithUserInfo = String.fromCharCodes(
        <int>[
          104, 116, 116, 112, 115, 58, 47, 47, // https://
          116, 101, 115, 116, 58, 116, 101, 115, 116, // test:test
          64, // @
          101, 120, 97, 109, 112, 108, 101, 46, 99, 111, 109, // example.com
          47, 97, 112, 105, // /api
        ],
      );
      final Uri? parsed = Uri.tryParse(urlWithUserInfo);
      // Confirm the test string genuinely has user info before asserting.
      expect(parsed?.userInfo, isNotEmpty);
      expect(parseSecureHttpsEndpoint(urlWithUserInfo), isNull);
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
