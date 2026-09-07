import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

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
