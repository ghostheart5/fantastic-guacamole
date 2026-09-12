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
        if (spoken.last.length > 4000) {
          throw PlatformException(code: 'TTS_INPUT_TOO_LONG');
        }
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

  test(
    'long evidence reports play completely within native input limits',
    () async {
      final text = List.generate(
        240,
        (i) => 'Evidence $i supports this next step.',
      ).join(' ');
      bool completed = false;
      final speech = service.speakChecked(text).then((result) {
        completed = true;
        return result;
      });
      await Future<void>.delayed(Duration.zero);
      expect(spoken.length, 1);
      expect(service.isSpeaking, isTrue);
      for (int i = 0; i < 20 && !completed; i++) {
        finish();
        await Future<void>.delayed(Duration.zero);
      }
      expect(completed, isTrue);
      expect(await speech, isTrue);
      expect(spoken.length, greaterThan(1));
      expect(spoken.every((part) => part.length <= 4000), isTrue);
      expect(spoken.join(), text);
      expect(service.isSpeaking, isFalse);
    },
  );

  test('long speech preserves Unicode at a native request boundary', () async {
    final text = '${'a' * 3499}\u{1F600}${'b' * 4000}';
    final speech = service.speakChecked(text);
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      finish();
    }
    expect(await speech, isTrue);
    expect(spoken.join(), text);
    for (final part in spoken) {
      expect(
        part.runes.any((rune) => rune >= 0xD800 && rune <= 0xDFFF),
        isFalse,
      );
    }
  });

  test('stop discards every remaining piece of a long response', () async {
    final speech = service.speakChecked('Evidence. ' * 1000);
    await Future<void>.delayed(Duration.zero);
    expect(spoken.length, 1);
    await service.stop();
    expect(await speech, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(spoken.length, 1);
    expect(service.isSpeaking, isFalse);
  });

  test(
    'replacement drops the old report tail while keeping the new speech',
    () async {
      final old = service.speakChecked('Previous evidence. ' * 500);
      await Future<void>.delayed(Duration.zero);
      final replacement = service.speakChecked('New selected response');
      await Future<void>.delayed(Duration.zero);
      expect(await old, isTrue);
      expect(spoken.length, 2);
      expect(spoken.last, 'New selected response');
      expect(service.isSpeaking, isTrue);
      finish();
      expect(await replacement, isTrue);
      expect(spoken.length, 2);
    },
  );

  test('a failed later piece stops the report and clears playback', () async {
    final speech = service.speakChecked('Evidence. ' * 1000);
    await Future<void>.delayed(Duration.zero);
    failPlayback = true;
    finish();
    expect(await speech, isFalse);
    expect(spoken.length, 2);
    expect(service.isSpeaking, isFalse);
  });
}
