import 'dart:async';

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
  bool containerDisposed = false;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        speechRecognitionServiceProvider.overrideWithValue(speech),
        voicePermissionServiceProvider.overrideWithValue(permission),
        voiceServiceProvider.overrideWithValue(voice),
        voiceInputEnabledProvider.overrideWithValue(true),
      ],
    );
  }

  setUp(() {
    speech = _FakeSpeechRecognitionService();
    permission = _FakeVoicePermissionService(granted: true);
    voice = _RecordingVoiceService();
    containerDisposed = false;
  });

  tearDown(() {
    if (!containerDisposed) container.dispose();
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

  for (final boundary in _StartBoundary.values) {
    for (final shutdown in _Shutdown.values) {
      test(
        '${shutdown.name} during ${boundary.name} prevents late capture',
        () async {
          final gate = Completer<void>();
          switch (boundary) {
            case _StartBoundary.tts:
              voice.stopGate = gate.future;
            case _StartBoundary.permission:
              permission.gate = gate.future;
            case _StartBoundary.initialization:
              speech.initializeGate = gate.future;
          }
          container = buildContainer();
          final controller = container.read(voiceControllerProvider.notifier);
          final revision = controller.lifecycleRevision;
          final observed = <VoiceState>[];
          container.listen(voiceControllerProvider, (_, next) {
            observed.add(next);
          });
          final starting = controller.startListening();
          await switch (boundary) {
            _StartBoundary.tts => voice.stopEntered.future,
            _StartBoundary.permission => permission.entered.future,
            _StartBoundary.initialization => speech.initializeEntered.future,
          };

          switch (shutdown) {
            case _Shutdown.stop:
              await controller.stopListening();
            case _Shutdown.dispose:
              container.dispose();
              containerDisposed = true;
              expect(controller.lifecycleRevision, isNot(revision));
            case _Shutdown.invalidate:
              container.invalidate(voiceControllerProvider);
              final replacement = container.read(
                voiceControllerProvider.notifier,
              );
              expect(replacement.lifecycleRevision, isNot(revision));
              expect(
                container.read(voiceControllerProvider).isListening,
                isFalse,
              );
          }
          final observedBeforeRelease = observed.length;
          gate.complete();
          await starting;

          expect(speech.listenCallCount, 0);
          expect(speech.isListening, isFalse);
          expect(
            observed.length,
            observedBeforeRelease,
            reason: 'The canceled startup must not emit stale state.',
          );
          expect(
            permission.requestCallCount,
            boundary == _StartBoundary.tts ? 0 : 1,
          );
          expect(
            speech.initializeCallCount,
            boundary == _StartBoundary.initialization ? 1 : 0,
          );
          if (!containerDisposed) {
            final state = container.read(voiceControllerProvider);
            expect(state.isListening, isFalse);
            expect(state.recognizedText, isEmpty);
            expect(state.error, isNull);
          }
        },
      );
    }

    test('rapid starts during ${boundary.name} request capture once', () async {
      final gate = Completer<void>();
      switch (boundary) {
        case _StartBoundary.tts:
          voice.stopGate = gate.future;
        case _StartBoundary.permission:
          permission.gate = gate.future;
        case _StartBoundary.initialization:
          speech.initializeGate = gate.future;
      }
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      final first = controller.startListening();
      await switch (boundary) {
        _StartBoundary.tts => voice.stopEntered.future,
        _StartBoundary.permission => permission.entered.future,
        _StartBoundary.initialization => speech.initializeEntered.future,
      };

      await Future.wait([
        controller.startListening(),
        controller.startListening(),
      ]);
      gate.complete();
      await first;

      expect(voice.stopCallCount, 1);
      expect(permission.requestCallCount, 1);
      expect(speech.initializeCallCount, 1);
      expect(speech.listenCallCount, 1);
      expect(container.read(voiceControllerProvider).isListening, isTrue);
    });
  }

  test(
    'stop drains a pending native listen and cancels its late activation',
    () async {
      final gate = Completer<void>();
      speech.listenGate = gate.future;
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      final starting = controller.startListening();
      await speech.listenEntered.future;

      final stopping = controller.stopListening();
      await controller.startListening();
      expect(permission.requestCallCount, 1);
      expect(container.read(voiceControllerProvider).isListening, isFalse);
      speech.emitResult('discard late private transcript');
      expect(container.read(voiceControllerProvider).recognizedText, isEmpty);

      gate.complete();
      await Future.wait([starting, stopping]);
      expect(speech.stopCallCount, 1);
      expect(speech.cancelCallCount, 1);
      expect(speech.isListening, isFalse);

      speech.listenGate = null;
      await controller.startListening();
      speech.emitResult('review this new transcript');
      expect(speech.listenCallCount, 2);
      expect(
        container.read(voiceControllerProvider).recognizedText,
        'review this new transcript',
      );
    },
  );

  test(
    'invalidation drains native startup before an explicit fresh start',
    () async {
      final gate = Completer<void>();
      speech.listenGate = gate.future;
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      final revision = controller.lifecycleRevision;
      final starting = controller.startListening();
      await speech.listenEntered.future;

      container.invalidate(voiceControllerProvider);
      final replacement = container.read(voiceControllerProvider.notifier);
      expect(replacement.lifecycleRevision, isNot(revision));
      await replacement.startListening();
      expect(permission.requestCallCount, 1);
      speech.emitResult('previous account transcript');
      expect(container.read(voiceControllerProvider).recognizedText, isEmpty);

      gate.complete();
      await starting;
      await replacement.stopListening();
      expect(speech.isListening, isFalse);
      speech.listenGate = null;
      await replacement.startListening();
      speech.emitResult('new account transcript');
      speech.sessions.first.onResult('stale previous account', true);
      speech.sessions.first.onDone();
      expect(container.read(voiceControllerProvider).isListening, isTrue);
      expect(
        container.read(voiceControllerProvider).recognizedText,
        'new account transcript',
      );
      expect(speech.listenCallCount, 2);
    },
  );

  test(
    'a replacement container waits for the shared native service cleanup',
    () async {
      final gate = Completer<void>();
      speech.listenGate = gate.future;
      container = buildContainer();
      final old = container.read(voiceControllerProvider.notifier);
      final starting = old.startListening();
      await speech.listenEntered.future;
      container.dispose();
      container = buildContainer();
      final replacement = container.read(voiceControllerProvider.notifier);

      await replacement.startListening();
      expect(permission.requestCallCount, 1);
      gate.complete();
      await starting;
      await replacement.stopListening();
      expect(speech.isListening, isFalse);

      speech.listenGate = null;
      await replacement.startListening();
      expect(speech.listenCallCount, 2);
      speech.sessions.first.onResult('disposed account', true);
      speech.sessions.first.onDone();
      expect(container.read(voiceControllerProvider).recognizedText, isEmpty);
      expect(container.read(voiceControllerProvider).isListening, isTrue);
    },
  );

  test(
    'asynchronous stop blocks restart until the native stop settles',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      await controller.startListening();
      speech.emitResult('keep for explicit review');
      final gate = Completer<void>();
      speech.stopGate = gate.future;

      final stopping = controller.stopListening();
      await controller.startListening();
      speech.emitResult('late result must be ignored');
      expect(speech.listenCallCount, 1);
      expect(container.read(voiceControllerProvider).isListening, isFalse);
      expect(
        container.read(voiceControllerProvider).recognizedText,
        'keep for explicit review',
      );

      gate.complete();
      await stopping;
      await controller.startListening();
      expect(speech.listenCallCount, 2);
      expect(container.read(voiceControllerProvider).recognizedText, isEmpty);
    },
  );

  test(
    'callbacks retained from a stopped session cannot mutate a new session',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      await controller.startListening();
      final oldSession = speech.sessions.single;
      speech.emitResult('old reviewed text');
      await controller.stopListening();
      oldSession.onResult('late old result', true);
      oldSession.onDone();
      expect(
        container.read(voiceControllerProvider).recognizedText,
        'old reviewed text',
      );

      await controller.startListening();
      speech.emitResult('current reviewed text');
      oldSession.onResult('late old account text', true);
      oldSession.onDone();
      expect(
        container.read(voiceControllerProvider).recognizedText,
        'current reviewed text',
      );
      expect(container.read(voiceControllerProvider).isListening, isTrue);
    },
  );

  test(
    'synchronous interruption at the listening state prevents native capture',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      Future<void>? stopping;
      container.listen(voiceControllerProvider, (_, state) {
        if (state.isListening) stopping = controller.stopListening();
      });

      await controller.startListening();
      await stopping;

      expect(speech.listenCallCount, 0);
      expect(container.read(voiceControllerProvider).isListening, isFalse);
    },
  );

  for (final failure in ['tts', 'permission', 'initialize', 'listen']) {
    test(
      '$failure startup failure is sanitized and permits explicit retry',
      () async {
        final error = StateError('private native engine detail and transcript');
        switch (failure) {
          case 'tts':
            voice.error = error;
          case 'permission':
            permission.error = error;
          case 'initialize':
            speech.initializeError = error;
          case 'listen':
            speech.listenError = error;
        }
        container = buildContainer();
        final controller = container.read(voiceControllerProvider.notifier);
        await controller.startListening();

        final state = container.read(voiceControllerProvider);
        expect(state.isListening, isFalse);
        expect(
          state.error,
          'Voice input could not start. Try again or type your message instead.',
        );
        expect(state.recognizedText, isEmpty);
        expect(speech.isListening, isFalse);

        voice.error = null;
        permission.error = null;
        speech.initializeError = null;
        speech.listenError = null;
        await controller.startListening();
        expect(container.read(voiceControllerProvider).isListening, isTrue);
        expect(container.read(voiceControllerProvider).error, isNull);
      },
    );
  }

  test(
    'stop failure attempts cancellation and exposes only a safe message',
    () async {
      container = buildContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      await controller.startListening();
      speech.stopError = StateError('private plugin details');

      await controller.stopListening();

      expect(speech.cancelCallCount, 1);
      expect(speech.isListening, isFalse);
      final state = container.read(voiceControllerProvider);
      expect(state.isListening, isFalse);
      expect(
        state.error,
        'Voice input could not stop. Close voice input and try again.',
      );
    },
  );

  test(
    'local containment never requests permission or initializes capture',
    () async {
      container = ProviderContainer(
        overrides: [
          speechRecognitionServiceProvider.overrideWithValue(speech),
          voicePermissionServiceProvider.overrideWithValue(permission),
          voiceServiceProvider.overrideWithValue(voice),
          voiceInputEnabledProvider.overrideWithValue(false),
        ],
      );
      await container.read(voiceControllerProvider.notifier).startListening();

      expect(voice.stopCallCount, 0);
      expect(permission.requestCallCount, 0);
      expect(speech.initializeCallCount, 0);
      expect(speech.listenCallCount, 0);
      expect(container.read(voiceControllerProvider).isListening, isFalse);
    },
  );
}

enum _StartBoundary { tts, permission, initialization }

enum _Shutdown { stop, dispose, invalidate }

class _SpeechSession {
  _SpeechSession(this.onResult, this.onDone);

  final void Function(String, bool) onResult;
  final void Function() onDone;
}

class _FakeSpeechRecognitionService implements SpeechRecognitionService {
  bool available = true;
  int listenCallCount = 0;
  int initializeCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
  Future<void>? initializeGate;
  Future<void>? listenGate;
  Future<void>? stopGate;
  Error? initializeError;
  Error? listenError;
  Error? stopError;
  final initializeEntered = Completer<void>();
  final listenEntered = Completer<void>();
  final sessions = <_SpeechSession>[];
  bool _listening = false;
  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onDone;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize() async {
    initializeCallCount++;
    if (!initializeEntered.isCompleted) initializeEntered.complete();
    await initializeGate;
    if (initializeError case final error?) throw error;
    return available;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    listenCallCount++;
    _onResult = onResult;
    _onDone = onDone;
    sessions.add(_SpeechSession(onResult, onDone));
    if (!listenEntered.isCompleted) listenEntered.complete();
    await listenGate;
    _listening = true;
    if (listenError case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    await stopGate;
    if (stopError case final error?) throw error;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount++;
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
  Future<void>? gate;
  Error? error;
  int requestCallCount = 0;
  final entered = Completer<void>();

  @override
  Future<bool> requestPermission() async {
    requestCallCount++;
    if (!entered.isCompleted) entered.complete();
    await gate;
    if (error case final failure?) throw failure;
    return granted;
  }
}

class _RecordingVoiceService extends VoiceService {
  int stopCallCount = 0;
  Future<void>? stopGate;
  Error? error;
  final stopEntered = Completer<void>();

  @override
  Future<void> stop() async {
    stopCallCount++;
    if (!stopEntered.isCompleted) stopEntered.complete();
    await stopGate;
    if (error case final failure?) throw failure;
  }
}
