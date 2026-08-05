import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluginAudioInterruptionService degrades safely without a platform channel', () {
    test('start completes without throwing when no callback fires', () async {
      final PluginAudioInterruptionService service =
          PluginAudioInterruptionService();
      bool interrupted = false;
      bool noisy = false;

      await service.start(
        onInterruptionBegin: () async {
          interrupted = true;
        },
        onBecomingNoisy: () async {
          noisy = true;
        },
      );

      expect(interrupted, isFalse);
      expect(noisy, isFalse);
    });

    test('stop completes without throwing even if start never ran', () async {
      final PluginAudioInterruptionService service =
          PluginAudioInterruptionService();
      await service.stop();
    });

    test('stop after start completes without throwing', () async {
      final PluginAudioInterruptionService service =
          PluginAudioInterruptionService();
      await service.start(
        onInterruptionBegin: () async {},
        onBecomingNoisy: () async {},
      );
      await service.stop();
    });
  });
}
