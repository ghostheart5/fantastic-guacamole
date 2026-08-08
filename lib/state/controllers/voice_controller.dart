import 'dart:async';

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

  late final SpeechRecognitionService _speechService;

  @override
  VoiceState build() {
    _speechService = ref.read(speechRecognitionServiceProvider);
    ref.onDispose(() {
      unawaited(_speechService.cancel());
    });
    return const VoiceState();
  }

  /// Required flow: request permission, listen, populate the caller's input
  /// box with the transcript. Recognized text is never auto-sent or routed as
  /// a command — the caller reads [VoiceState.recognizedText] and the user
  /// must explicitly tap send.
  Future<void> startListening() async {
    if (state.isListening) {
      return;
    }
    // Mutual exclusion: stop any active TTS so the mic cannot pick up
    // ChronoSpark's own speech.
    await ref.read(voiceServiceProvider).stop();

    final VoicePermissionService permissionService = ref.read(
      voicePermissionServiceProvider,
    );
    final bool granted = await permissionService.requestPermission();
    if (!granted) {
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error: _permissionDeniedMessage,
      );
      return;
    }

    final bool available = await _speechService.initialize();
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

    await _speechService.listen(
      onResult: (String text, bool isFinal) {
        if (!state.isListening) {
          return;
        }
        state = state.copyWith(recognizedText: text);
      },
      onDone: () {
        // The plugin stopped listening on its own (bounded timeout or
        // silence window) without the caller tapping again.
        state = state.copyWith(isListening: false);
      },
    );
  }

  Future<void> stopListening() async {
    if (!state.isListening) {
      return;
    }
    await _speechService.stop();
    state = state.copyWith(isListening: false);
  }

  /// Clears the transcript once the caller has consumed it, so a stale
  /// result cannot resurface into a later listening session.
  void clearRecognizedText() {
    state = state.copyWith(recognizedText: '');
  }

  Future<void> stopSpeaking() async {
    return;
  }
}
