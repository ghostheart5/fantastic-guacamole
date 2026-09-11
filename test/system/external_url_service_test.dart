import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'mail drafts preserve spaces, literal plus and diagnostic lines',
    () async {
      String? launched;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          launched = (call.arguments as Map)['url'] as String;
          return true;
        }
        return false;
      });
      const body = 'Issue summary: café & tea\nVersion: 4.1.0+2026083029';
      expect(
        await const ExternalUrlService().open(
          Uri(
            scheme: 'mailto',
            path: 'support@example.com',
            queryParameters: {
              'subject': 'ChronoSpark support request',
              'body': body,
            },
          ),
        ),
        isTrue,
      );
      expect(launched, contains('subject=ChronoSpark%20support%20request'));
      expect(launched, contains('%2B2026083029'));
      expect(Uri.parse(launched!).queryParameters['body'], body);
    },
  );

  test('opens Terms even when package visibility reports no handler', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'canLaunch') return false;
      if (call.method == 'launch') return true;
      return false;
    });
    expect(
      await const ExternalUrlService().open(
        Uri.parse('https://ghostheart5.github.io/fantastic-guacamole/terms/'),
      ),
      isTrue,
    );
    expect(calls, contains('launch'));
  });

  test(
    'real launch failure still permits the local document fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
      });
      expect(
        await const ExternalUrlService().open(Uri.parse('https://example.com')),
        isFalse,
      );
    },
  );
}
