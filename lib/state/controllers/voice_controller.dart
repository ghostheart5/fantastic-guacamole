import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:fantastic_guacamole/system/voice/speech_recognition_service.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceState {
  const VoiceState({
    this.isListening = false,
    this.isAvailable = false,
    this.recognizedText = '',
    this.lastResponse = '',
    this.error,
  });

  final bool isListening;
  final bool isAvailable;
  final String recognizedText;
  final String lastResponse;
  final String? error;

  VoiceState copyWith({
    bool? isListening,
    bool? isAvailable,
    String? recognizedText,
    String? lastResponse,
    String? error,
    bool clearError = false,
  }) {
    return VoiceState(
      isListening: isListening ?? this.isListening,
      isAvailable: isAvailable ?? this.isAvailable,
      recognizedText: recognizedText ?? this.recognizedText,
      lastResponse: lastResponse ?? this.lastResponse,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return const VoiceService();
});

// Platform speech engines may send audio to an external service.
final voiceInputEnabledProvider = Provider<bool>((ref) {
  return Env.cloudServicesEnabled;
});

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  return PluginSpeechRecognitionService();
});

final audioInterruptionServiceProvider = Provider<AudioInterruptionService>((
  ref,
) {
  return PluginAudioInterruptionService();
});

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceState>(
  VoiceController.new,
);

class VoiceController extends Notifier<VoiceState> {
  static const String _permissionDeniedMessage =
      'Microphone permission is required for voice input.';
  static const String _unavailableMessage =
      'Speech recognition is not available on this device.';
  static const String _startFailedMessage =
      'Voice input could not start. Try again or type your message instead.';
  static const String _stopFailedMessage =
      'Voice input could not stop. Close voice input and try again.';

  // Provider invalidation may create another controller using the same native
  // service. It must not start while its predecessor is still stopping it.
  static final Expando<Future<void>> _serviceCleanup = Expando<Future<void>>(
    'voice service cleanup',
  );

  late SpeechRecognitionService _speechService;
  int _generation = 0;
  int _lifecycleRevision = 0;
  bool _disposed = false;
  bool _starting = false;
  Future<void>? _listenPending;
  Future<void>? _stopPending;

  /// Capture before awaiting consent, and check again before starting capture.
  /// Riverpod can rebuild this same notifier for a different signed-in account.
  int get lifecycleRevision => _lifecycleRevision;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  VoiceState build() {
    _disposed = false;
    _generation++;
    _lifecycleRevision++;
    _speechService = ref.read(speechRecognitionServiceProvider);
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _lifecycleRevision++;
      unawaited(_beginStop(cancel: true));
    });
    return const VoiceState();
  }

  /// Required flow: request permission, listen, populate the caller's input
  /// box with the transcript. Recognized text is never auto-sent or routed as
  /// an action — the caller reads [VoiceState.recognizedText] and the user
  /// must explicitly tap send.
  Future<void> startListening() async {
    if (_disposed ||
        _starting ||
        _stopPending != null ||
        _serviceCleanup[_speechService] != null) {
      return;
    }
    if (!ref.read(voiceInputEnabledProvider)) {
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error:
            'Voice input is unavailable in local mode. Type your message instead.',
      );
      return;
    }
    if (state.isListening) {
      return;
    }
    final int generation = ++_generation;
    final SpeechRecognitionService speechService = _speechService;
    _starting = true;
    try {
      // Stop TTS before permission and capture; every await can outlive the
      // caller's page, account, or foreground lifecycle.
      await ref.read(voiceServiceProvider).stop();
      if (!_isCurrent(generation)) return;

      final VoicePermissionService permissionService = ref.read(
        voicePermissionServiceProvider,
      );
      final bool granted = await permissionService.requestPermission();
      if (!_isCurrent(generation)) return;
      if (!granted) {
        state = state.copyWith(
          isAvailable: false,
          isListening: false,
          error: _permissionDeniedMessage,
        );
        return;
      }

      final bool available = await speechService.initialize();
      if (!_isCurrent(generation)) return;
      if (!available) {
        state = state.copyWith(
          isAvailable: false,
          isListening: false,
          error: _unavailableMessage,
        );
        return;
      }

      state = state.copyWith(
        isAvailable: true,
        isListening: true,
        recognizedText: '',
        clearError: true,
      );
      if (!_isCurrent(generation)) return;

      // Publish a settlement barrier before invoking the plugin, which can
      // synchronously call a listener that stops or disposes this controller.
      final Completer<void> listenSettled = Completer<void>();
      _listenPending = listenSettled.future;
      try {
        await speechService.listen(
          onResult: (String text, bool isFinal) {
            if (!_isCurrent(generation) || !state.isListening) return;
            state = state.copyWith(recognizedText: text);
          },
          onDone: () {
            if (!_isCurrent(generation) || !state.isListening) return;
            state = state.copyWith(isListening: false);
          },
        );
      } finally {
        listenSettled.complete();
        _listenPending = null;
      }
      if (!_isCurrent(generation)) return;
    } on Object {
      if (!_isCurrent(generation)) return;
      _generation++;
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error: _startFailedMessage,
      );
      await _beginStop(cancel: true);
    } finally {
      _starting = false;
    }
  }

  Future<void> stopListening() {
    _generation++;
    final Future<void> stopping = _beginStop();
    if (!_disposed) {
      state = state.copyWith(isListening: false);
    }
    return stopping;
  }

  Future<void> _beginStop({bool cancel = false}) {
    final Future<void>? existing =
        _stopPending ?? _serviceCleanup[_speechService];
    if (existing != null) return existing;
    final Future<void>? pendingListen = _listenPending;
    final int generation = _generation;
    final SpeechRecognitionService speechService = _speechService;
    final Completer<void> completion = Completer<void>();
    final Future<void> stopping = completion.future;
    _stopPending = stopping;
    _serviceCleanup[speechService] = stopping;
    final Future<void> operation = (() async {
      bool failed = false;
      try {
        if (cancel) {
          await speechService.cancel();
        } else {
          await speechService.stop();
        }
      } on Object {
        failed = true;
      }
      // A native listen already in flight may activate after the first stop.
      // Drain it and cancel again before allowing a new session to begin.
      if (pendingListen != null) await pendingListen;
      if (pendingListen != null || failed) {
        try {
          await speechService.cancel();
        } on Object {
          failed = true;
        }
      }
      if (failed && _isCurrent(generation)) {
        state = state.copyWith(isListening: false, error: _stopFailedMessage);
      }
    })();
    void finish() {
      if (identical(_stopPending, stopping)) _stopPending = null;
      if (identical(_serviceCleanup[speechService], stopping)) {
        _serviceCleanup[speechService] = null;
      }
    }

    unawaited(
      operation.then(
        (_) {
          finish();
          completion.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          finish();
          completion.completeError(error, stackTrace);
        },
      ),
    );
    return stopping;
  }

  /// Clears the transcript once the caller has consumed it, so a stale
  /// result cannot resurface into a later listening session.
  void clearRecognizedText() {
    if (_disposed) return;
    state = state.copyWith(recognizedText: '');
  }

  Future<void> stopSpeaking() async {
    return;
  }
}
