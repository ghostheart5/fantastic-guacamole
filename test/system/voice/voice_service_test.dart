import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceService degrades safely without a platform channel', () {
    const VoiceService service = VoiceService();
    const MethodChannel ttsChannel = MethodChannel('chronospark/tts');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ttsChannel, null);
    });

    test('stop and pause are no-ops before first speech output', () async {
      final List<String> calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ttsChannel, (MethodCall call) async {
            calls.add(call.method);
            return null;
          });

      await service.stop();
      await service.pause();

      expect(calls, isEmpty);
      expect(service.isSpeaking, isFalse);
    });

    test(
      'speak completes without throwing and leaves isSpeaking false',
      () async {
        await service.speak('hello there');
        expect(service.isSpeaking, isFalse);
      },
    );

    test('speak with blank text is a no-op', () async {
      await service.speak('   ');
      expect(service.isSpeaking, isFalse);
    });

    test('stop completes without throwing', () async {
      await service.stop();
      expect(service.isSpeaking, isFalse);
    });

    test('pause completes without throwing', () async {
      await service.pause();
      expect(service.isSpeaking, isFalse);
    });

    test(
      'speakSummary and speakAccessibilityHint complete without throwing',
      () async {
        await service.speakSummary(
          title: 'Today',
          points: <String>['Finish the report', 'Call the team'],
        );
        await service.speakAccessibilityHint(
          surface: 'Nexus',
          controls: <String>['Mic button', 'Send button'],
        );
        expect(service.isSpeaking, isFalse);
      },
    );

    test(
      'setLanguage/setVolume/setRate/setPitch complete without throwing',
      () async {
        await service.setLanguage('en-US');
        await service.setVolume(0.8);
        await service.setRate(0.5);
        await service.setPitch(1.0);
        expect(service.isSpeaking, isFalse);
      },
    );
  });
}
