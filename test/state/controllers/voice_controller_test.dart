import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/system/voice/speech_recognition_service.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeSpeechRecognitionService speech;
  late _FakeVoicePermissionService permission;
  late _RecordingVoiceService voice;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        speechRecognitionServiceProvider.overrideWithValue(speech),
        voicePermissionServiceProvider.overrideWithValue(permission),
        voiceServiceProvider.overrideWithValue(voice),
      ],
    );
  }

  setUp(() {
    speech = _FakeSpeechRecognitionService();
    permission = _FakeVoicePermissionService(granted: true);
    voice = _RecordingVoiceService();
  });

  tearDown(() {
    container.dispose();
  });

  test('permission denied surfaces an error and stays not listening', () async {
    permission.granted = false;
    container = buildContainer();
    final controller = container.read(voiceControllerProvider.notifier);

    await controller.startListening();

    final VoiceState state = container.read(voiceControllerProvider);
    expect(state.isListening, isFalse);
    expect(state.isAvailable, isFalse);
    expect(state.error, isNotNull);
    expect(speech.listenCallCount, 0);
  });

  test(
    'unavailable speech engine surfaces an error and stays not listening',
    () async {
      speech.available = false;
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);

      await controller.startListening();

      final VoiceState state = container.read(voiceControllerProvider);
      expect(state.isListening, isFalse);
      expect(state.isAvailable, isFalse);
      expect(state.error, isNotNull);
      expect(speech.listenCallCount, 0);
    },
  );

  test(
    'happy path listens, populates recognizedText, and stop preserves it',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);

      await controller.startListening();
      expect(container.read(voiceControllerProvider).isListening, isTrue);
      expect(container.read(voiceControllerProvider).error, isNull);

      speech.emitResult('start execution mode', isFinal: true);
      expect(
        container.read(voiceControllerProvider).recognizedText,
        'start execution mode',
      );

      await controller.stopListening();
      final VoiceState afterStop = container.read(voiceControllerProvider);
      expect(afterStop.isListening, isFalse);
      expect(afterStop.recognizedText, 'start execution mode');

      controller.clearRecognizedText();
      expect(container.read(voiceControllerProvider).recognizedText, isEmpty);
    },
  );

  test(
    'the plugin stopping on its own flips isListening back to false',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);

      await controller.startListening();
      expect(container.read(voiceControllerProvider).isListening, isTrue);

      speech.emitDone();

      expect(container.read(voiceControllerProvider).isListening, isFalse);
    },
  );

  test(
    'startListening stops any active TTS before listening (mutual exclusion)',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);

      await controller.startListening();

      expect(voice.stopCallCount, 1);
    },
  );

  test('startListening while already listening is a no-op', () async {
    container = buildContainer();
    final controller = container.read(voiceControllerProvider.notifier);

    await controller.startListening();
    expect(speech.listenCallCount, 1);

    await controller.startListening();
    expect(speech.listenCallCount, 1);
    expect(voice.stopCallCount, 1);
  });
}

class _FakeSpeechRecognitionService implements SpeechRecognitionService {
  bool available = true;
  int listenCallCount = 0;
  bool _listening = false;
  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onDone;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    listenCallCount++;
    _listening = true;
    _onResult = onResult;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async {
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }

  void emitResult(String text, {bool isFinal = false}) {
    _onResult?.call(text, isFinal);
  }

  void emitDone() {
    _listening = false;
    _onDone?.call();
  }
}

class _FakeVoicePermissionService extends VoicePermissionService {
  _FakeVoicePermissionService({required this.granted});

  bool granted;

  @override
  Future<bool> requestPermission() async => granted;
}

class _RecordingVoiceService extends VoiceService {
  int stopCallCount = 0;

  @override
  Future<void> stop() async {
    stopCallCount++;
  }
}
