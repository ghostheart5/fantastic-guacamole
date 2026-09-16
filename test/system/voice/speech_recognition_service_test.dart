import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/system/voice/speech_recognition_service.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SpeechPlatformHarness platform;
  late PluginSpeechRecognitionService service;

  setUp(() {
    platform = _SpeechPlatformHarness()..install();
    // Exercise the real package's status/final-result ordering. Every outbound
    // native method is intercepted; no recognizer or microphone is opened.
    service = PluginSpeechRecognitionService(
      speech: SpeechToText.withMethodChannel(),
    );
  });

  tearDown(() async {
    platform.failures.clear();
    await service.cancel();
    platform.uninstall();
  });

  Future<void> listen({
    void Function(String, bool)? onResult,
    void Function()? onDone,
  }) async {
    expect(await service.initialize(), isTrue);
    await service.listen(
      onResult: onResult ?? (_, _) {},
      onDone: onDone ?? () {},
    );
  }

  Matcher safeFailure(String operation) =>
      isA<SpeechRecognitionFailure>().having(
        (error) => error.toString(),
        'sanitized message',
        'Speech recognition $operation failed.',
      );

  ProviderContainer controllerContainer() => ProviderContainer(
    overrides: [
      speechRecognitionServiceProvider.overrideWithValue(service),
      voicePermissionServiceProvider.overrideWithValue(_GrantedPermission()),
      voiceServiceProvider.overrideWithValue(_SilentVoiceService()),
      voiceInputEnabledProvider.overrideWithValue(true),
    ],
  );

  test('production callers share the singleton engine callback owner', () {
    expect(
      identical(
        PluginSpeechRecognitionService(),
        PluginSpeechRecognitionService(),
      ),
      isTrue,
    );
  });

  test(
    'stop and cancel before initialization invoke no native method',
    () async {
      await service.stop();
      await service.cancel();
      expect(platform.calls, isEmpty);
    },
  );

  test('unavailable initialization cannot start native capture', () async {
    platform.available = false;
    expect(await service.initialize(), isFalse);
    await expectLater(
      service.listen(onResult: (_, _) {}, onDone: () {}),
      throwsA(safeFailure('listen')),
    );
    expect(platform.calls, ['initialize']);
  });

  test(
    'initialization failure reports unavailable and permits retry',
    () async {
      platform.failures.add('initialize');
      expect(await Logger.withMutedErrors(service.initialize), isFalse);
      expect(service.isListening, isFalse);
      platform.failures.clear();
      expect(await service.initialize(), isTrue);
    },
  );

  test(
    'notListening and early done preserve the corrected final transcript',
    () async {
      final events = <String>[];
      await listen(
        onResult: (text, finalResult) => events.add('$text:$finalResult'),
        onDone: () => events.add('done'),
      );
      await platform.result('partial draft');
      await platform.status('notListening');
      await platform.status('done');
      expect(events, ['partial draft:false']);

      await platform.result('corrected final draft', finalResult: true);
      await platform.status('done');
      await platform.status('done');
      expect(events, [
        'partial draft:false',
        'corrected final draft:true',
        'done',
      ]);
    },
  );

  test('a no-result completion reports done exactly once', () async {
    int done = 0;
    await listen(onDone: () => done++);
    await platform.status('notListening');
    expect(done, 0);
    await platform.status('doneNoResult');
    await platform.status('done');
    expect(done, 1);
  });

  test('native error followed by repeated completion finishes once', () async {
    int done = 0;
    final results = <String>[];
    await listen(
      onDone: () => done++,
      onResult: (text, _) => results.add(text),
    );
    await platform.error();
    await platform.status('notListening');
    await platform.status('doneNoResult');
    await platform.error();
    await platform.result(
      'result arriving after terminal error',
      finalResult: true,
    );
    expect(done, 1);
    expect(results, isEmpty);
  });

  test(
    'listen exception propagates safely without a false done receipt',
    () async {
      expect(await service.initialize(), isTrue);
      platform.failures.add('listen');
      int done = 0;
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () => done++),
        throwsA(safeFailure('listen')),
      );
      expect(done, 0);
      platform.failures.clear();
      await listen();
      expect(platform.calls.where((call) => call == 'listen').length, 2);
    },
  );

  test(
    'native error during asynchronous startup propagates a safe failure',
    () async {
      expect(await service.initialize(), isTrue);
      platform.onListen = platform.error;
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () {}),
        throwsA(safeFailure('listen')),
      );
    },
  );

  test(
    'stop failure reaches the caller and cancellation permits recovery',
    () async {
      await listen();
      platform.failures.add('stop');
      await expectLater(service.stop(), throwsA(safeFailure('stop')));
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () {}),
        throwsA(safeFailure('listen')),
      );
      await service.cancel();
      platform.failures.clear();
      await listen();
      expect(
        platform.calls,
        containsAllInOrder(['listen', 'stop', 'cancel', 'listen']),
      );
    },
  );

  test(
    'cancel failure blocks replacement until an explicit successful cleanup',
    () async {
      await listen();
      platform.failures.add('cancel');
      await expectLater(service.cancel(), throwsA(safeFailure('cancel')));
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () {}),
        throwsA(safeFailure('listen')),
      );
      expect(platform.calls.where((call) => call == 'listen').length, 1);
      platform.failures.clear();
      await service.cancel();
      await listen();
      expect(platform.calls.where((call) => call == 'listen').length, 2);
    },
  );

  test(
    'stop acknowledgement cannot replace a session before its final result',
    () async {
      final events = <String>[];
      await listen(
        onResult: (text, _) => events.add(text),
        onDone: () => events.add('done'),
      );
      await platform.result('reviewed partial');
      bool stopped = false;
      final stopping = service.stop().then((_) => stopped = true);
      await platform.stopEntered.future;
      await platform.status('notListening');
      await platform.status('done');
      expect(stopped, isFalse);
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () {}),
        throwsA(safeFailure('listen')),
      );

      await platform.result('old final while stopping', finalResult: true);
      await stopping;
      expect(stopped, isTrue);
      expect(
        events,
        ['reviewed partial'],
        reason: 'Caller-ended sessions no longer emit transcripts or done.',
      );
      await listen();
      expect(platform.calls.where((call) => call == 'listen').length, 2);
    },
  );

  testWidgets(
    'missing terminal receipt fails a bounded stop and allows cancel',
    (tester) async {
      await listen();
      final stopping = expectLater(
        service.stop(),
        throwsA(safeFailure('stop')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await stopping;
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () {}),
        throwsA(safeFailure('listen')),
      );
      await service.cancel();
      await listen();
      await service.cancel();
    },
  );

  test(
    'cancel during native startup also cancels its late activation',
    () async {
      final gate = Completer<void>();
      platform.listenGate = gate.future;
      expect(await service.initialize(), isTrue);
      final events = <String>[];
      final starting = service.listen(
        onResult: (text, _) => events.add(text),
        onDone: () => events.add('done'),
      );
      await platform.listenEntered.future;
      await service.cancel();
      gate.complete();
      await starting;
      expect(platform.calls.where((call) => call == 'cancel').length, 2);
      expect(service.isListening, isFalse);
      await platform.result('discard old result', finalResult: true);
      expect(events, isEmpty);
      platform.listenGate = null;
      await listen();
    },
  );

  test(
    'stop during native startup drains its receipt and late activation',
    () async {
      final gate = Completer<void>();
      platform.listenGate = gate.future;
      platform.onStop = () => platform.status('doneNoResult');
      expect(await service.initialize(), isTrue);
      final starting = service.listen(onResult: (_, _) {}, onDone: () {});
      await platform.listenEntered.future;
      await service.stop();
      await expectLater(
        service.listen(onResult: (_, _) {}, onDone: () {}),
        throwsA(safeFailure('listen')),
      );

      gate.complete();
      await starting;
      expect(platform.calls, containsAllInOrder(['listen', 'stop', 'cancel']));
      expect(service.isListening, isFalse);
      platform.listenGate = null;
      await listen();
      expect(platform.calls.where((call) => call == 'listen').length, 2);
    },
  );

  test(
    'controller receives actual adapter startup failures as safe UI errors',
    () async {
      final container = controllerContainer();
      platform.failures.add('listen');
      final controller = container.read(voiceControllerProvider.notifier);
      await controller.startListening();
      final state = container.read(voiceControllerProvider);
      expect(state.isListening, isFalse);
      expect(
        state.error,
        'Voice input could not start. Try again or type your message instead.',
      );
      expect(platform.calls, containsAllInOrder(['listen', 'cancel']));
      container.dispose();
      await service.cancel();
    },
  );

  testWidgets('native listen rejection times out and restores controller UI', (
    tester,
  ) async {
    platform.startAccepted = false;
    final container = controllerContainer();
    final controller = container.read(voiceControllerProvider.notifier);
    final starting = controller.startListening();
    await tester.pump();
    expect(container.read(voiceControllerProvider).isListening, isTrue);
    await tester.pump(const Duration(seconds: 6));
    await starting;

    final state = container.read(voiceControllerProvider);
    expect(state.isListening, isFalse);
    expect(
      state.error,
      'Voice input could not start. Try again or type your message instead.',
    );
    expect(platform.calls, containsAllInOrder(['listen', 'cancel']));
    platform.startAccepted = true;
    await controller.startListening();
    expect(container.read(voiceControllerProvider).isListening, isTrue);
    container.dispose();
    await service.cancel();
  });

  test('a valid delayed listening acknowledgement completes startup', () async {
    platform.emitListening = false;
    expect(await service.initialize(), isTrue);
    bool completed = false;
    final starting = service
        .listen(onResult: (_, _) {}, onDone: () {})
        .then((_) => completed = true);
    await platform.listenEntered.future;
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    await platform.status('listening');
    await starting;
    expect(completed, isTrue);
    expect(platform.calls.where((call) => call == 'cancel'), isEmpty);
  });

  for (final operation in ['stop', 'cancel']) {
    test(
      '$operation during startup acknowledgement wait does not deadlock',
      () async {
        platform.emitListening = false;
        platform.onStop = () => platform.status('doneNoResult');
        expect(await service.initialize(), isTrue);
        final results = <String>[];
        final starting = service.listen(
          onResult: (text, _) => results.add(text),
          onDone: () => results.add('done'),
        );
        await platform.listenEntered.future;
        await Future<void>.delayed(Duration.zero);
        await (operation == 'stop' ? service.stop() : service.cancel());
        await starting;
        expect(results, isEmpty);
        expect(service.isListening, isFalse);
        expect(platform.calls, containsAllInOrder([operation, 'cancel']));
        platform.emitListening = true;
        await listen();
      },
    );
  }

  testWidgets('startup timeout with failed cleanup blocks native restart', (
    tester,
  ) async {
    platform.startAccepted = false;
    platform.failures.add('cancel');
    expect(await service.initialize(), isTrue);
    final failure = expectLater(
      service.listen(onResult: (_, _) {}, onDone: () {}),
      throwsA(safeFailure('listen')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await failure;
    platform.startAccepted = true;
    platform.failures.clear();
    await expectLater(
      service.listen(onResult: (_, _) {}, onDone: () {}),
      throwsA(safeFailure('listen')),
    );
    expect(platform.calls.where((call) => call == 'listen').length, 1);

    await service.cancel();
    await listen();
    expect(platform.calls.where((call) => call == 'listen').length, 2);
    await service.cancel();
  });

  test(
    'controller falls back to native cancel when adapter stop fails',
    () async {
      final container = controllerContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      await controller.startListening();
      platform.failures.add('stop');
      await controller.stopListening();
      expect(platform.calls, containsAllInOrder(['listen', 'stop', 'cancel']));
      expect(container.read(voiceControllerProvider).isListening, isFalse);
      expect(
        container.read(voiceControllerProvider).error,
        'Voice input could not stop. Close voice input and try again.',
      );
      container.dispose();
      await service.cancel();
    },
  );

  test(
    'controller retains actual final correction until explicit review',
    () async {
      final container = controllerContainer();
      final controller = container.read(voiceControllerProvider.notifier);
      await controller.startListening();
      await platform.result('meet Tuesday');
      await platform.status('notListening');
      expect(container.read(voiceControllerProvider).isListening, isTrue);
      await platform.status('done');
      await platform.result('meet Thursday', finalResult: true);
      final state = container.read(voiceControllerProvider);
      expect(state.isListening, isFalse);
      expect(state.recognizedText, 'meet Thursday');
      expect(state.lastResponse, isEmpty);
      container.dispose();
      await service.cancel();
    },
  );
}

class _SpeechPlatformHarness {
  static const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  final failures = <String>{};
  final listenEntered = Completer<void>();
  final stopEntered = Completer<void>();
  bool available = true;
  bool startAccepted = true;
  bool emitListening = true;
  Future<void>? listenGate;
  Future<void> Function()? onListen;
  Future<void> Function()? onStop;

  void install() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (failures.contains(call.method)) {
        throw PlatformException(
          code: 'private-native-code',
          message: 'private recognizer detail and transcript',
          details: 'private native diagnostic',
        );
      }
      switch (call.method) {
        case 'initialize':
          return available;
        case 'listen':
          if (!listenEntered.isCompleted) listenEntered.complete();
          await listenGate;
          if (startAccepted && emitListening) await status('listening');
          await onListen?.call();
          return startAccepted;
        case 'stop':
          if (!stopEntered.isCompleted) stopEntered.complete();
          await onStop?.call();
          return null;
        case 'cancel':
          return null;
        default:
          throw MissingPluginException();
      }
    });
  }

  void uninstall() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  }

  Future<void> status(String value) => _emit('notifyStatus', value);

  Future<void> result(String text, {bool finalResult = false}) => _emit(
    'textRecognition',
    jsonEncode({
      'alternates': [
        {'recognizedWords': text, 'confidence': 0.9},
      ],
      'resultType': finalResult ? 2 : 0,
    }),
  );

  Future<void> error() => _emit(
    'notifyError',
    jsonEncode({'errorMsg': 'private runtime diagnostic', 'permanent': true}),
  );

  Future<void> _emit(String method, Object value) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, value)),
      null,
    );
  }
}

class _GrantedPermission extends VoicePermissionService {
  @override
  Future<bool> requestPermission() async => true;
}

class _SilentVoiceService extends VoiceService {
  @override
  Future<void> stop() async {}
}
