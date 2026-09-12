import 'dart:async';

import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const VoiceService service = VoiceService();
  const MethodChannel channel = MethodChannel('chronospark/tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<String> spoken = <String>[];
  final List<Completer<void>> utterances = <Completer<void>>[];
  Completer<void>? initialization;
  bool failPlayback = false;

  void finish() {
    for (final pending in utterances) {
      if (!pending.isCompleted) pending.complete();
    }
  }

  setUp(() {
    spoken.clear();
    utterances.clear();
    initialization = null;
    failPlayback = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') await initialization?.future;
      if (call.method == 'stop') finish();
      if (call.method == 'speak') {
        spoken.add((call.arguments as Map)['text'] as String);
        if (failPlayback) throw PlatformException(code: 'TTS_FAILED');
        final pending = Completer<void>();
        utterances.add(pending);
        await pending.future;
      }
      return null;
    });
  });

  tearDown(() async {
    initialization?.complete();
    await service.stop();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'stop during initialization prevents delayed speech from starting',
    () async {
      initialization = Completer<void>();
      final speech = service.speakChecked('Delayed response');
      await Future<void>.delayed(Duration.zero);
      expect(service.isSpeaking, isTrue);
      final stopping = service.stop();
      expect(service.isSpeaking, isFalse);
      initialization!.complete();
      initialization = null;
      await stopping;
      expect(
        await speech,
        isTrue,
        reason: 'Cancellation is not an engine failure',
      );
      expect(spoken, isEmpty);
    },
  );

  test('stop cancels current speech and every rapid pending request', () async {
    final first = service.speakChecked('First long response');
    await Future<void>.delayed(Duration.zero);
    expect(spoken, <String>['First long response']);
    final second = service.speakChecked('Second response');
    final third = service.speakChecked('Third response');
    await service.stop();
    await Future.wait(<Future<bool>>[first, second, third]);
    expect(spoken, <String>['First long response']);
    expect(service.isSpeaking, isFalse);
  });

  test(
    'a newer request replaces playback without waiting for its duration',
    () async {
      final first = service.speakChecked('First long response');
      await Future<void>.delayed(Duration.zero);
      final second = service.speakChecked('Selected replacement');
      await Future<void>.delayed(Duration.zero);
      expect(spoken, <String>['First long response', 'Selected replacement']);
      expect(await first, isTrue);
      expect(
        service.isSpeaking,
        isTrue,
        reason: 'Old completion cannot hide new playback',
      );
      finish();
      expect(await second, isTrue);
      expect(service.isSpeaking, isFalse);
    },
  );

  test(
    'stop followed immediately by speak preserves the new request',
    () async {
      final first = service.speakChecked('Old');
      await Future<void>.delayed(Duration.zero);
      final stopped = service.stop();
      final second = service.speakChecked('New');
      await stopped;
      await Future<void>.delayed(Duration.zero);
      expect(spoken, <String>['Old', 'New']);
      expect(service.isSpeaking, isTrue);
      finish();
      await Future.wait(<Future<bool>>[first, second]);
      expect(service.isSpeaking, isFalse);
    },
  );

  test('native playback error clears the visible playback state', () async {
    failPlayback = true;
    expect(await service.speakChecked('Cannot play'), isFalse);
    expect(service.isSpeaking, isFalse);
  });
}
