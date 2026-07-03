import 'package:fantastic_guacamole/core/services/voice_service.dart';
import 'package:fantastic_guacamole/engine/si/si_intent.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/coach_controller.dart';
import 'package:fantastic_guacamole/state/controllers/focus_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  return VoiceService();
});

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceState>(
  VoiceController.new,
);

class VoiceController extends Notifier<VoiceState> {
  final SpeechToText _speech = SpeechToText();

  @override
  VoiceState build() => const VoiceState();

  Future<void> startListening() async {
    if (state.isListening) return;

    bool available = false;
    try {
      available = await _speech.initialize(
        onError: (errorNotification) {
          state = state.copyWith(
            isListening: false,
            error: errorNotification.errorMsg,
          );
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            state = state.copyWith(isListening: false);
          }
        },
      );
    } on PlatformException catch (error) {
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error:
            error.message ?? 'Speech recognition unavailable on this device.',
      );
      return;
    } catch (_) {
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error: 'Speech recognition unavailable on this device.',
      );
      return;
    }

    if (!available) {
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error: 'Speech recognition unavailable on this device.',
      );
      return;
    }

    state = state.copyWith(
      isAvailable: true,
      isListening: true,
      clearError: true,
    );

    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
        ),
        onResult: _onSpeechResult,
      );
    } on PlatformException catch (error) {
      state = state.copyWith(
        isListening: false,
        error: error.message ?? 'Failed to start speech recognition.',
      );
    } catch (_) {
      state = state.copyWith(
        isListening: false,
        error: 'Failed to start speech recognition.',
      );
    }
  }

  Future<void> stopListening() async {
    if (!_speech.isListening) return;
    try {
      await _speech.stop();
    } catch (_) {
      state = state.copyWith(error: 'Failed to stop speech recognition.');
    }
    state = state.copyWith(isListening: false);
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    final String text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    state = state.copyWith(recognizedText: text, clearError: true);

    if (!result.finalResult) return;

    await _routeVoiceIntent(text);
  }

  Future<void> _routeVoiceIntent(String text) async {
    final SIIntent intent = SIIntentParser.parse(text);

    ref.read(aiInputProvider.notifier).set(text);
    try {
      await ref.read(aiResponseProvider.notifier).execute(inputOverride: text);
      await ref.read(coachControllerProvider.notifier).refresh();
    } catch (_) {
      state = state.copyWith(
        lastResponse: 'I could not process that request right now.',
        error: 'Voice command processing failed.',
      );
      return;
    }

    final AIRecommendation? response = ref
        .read(aiResponseProvider)
        .asData
        ?.value;
    final String? reasoning = response?.reasoning;
    final String spoken = (reasoning != null && reasoning.isNotEmpty)
        ? reasoning
        : (response?.message ?? 'I did not find a recommendation yet.');

    state = state.copyWith(lastResponse: spoken);
    try {
      await ref.read(voiceServiceProvider).speak(spoken);
    } catch (_) {
      state = state.copyWith(error: 'Voice playback failed.');
    }

    ref.read(aiInputProvider.notifier).set(null);

    if (intent == SIIntent.startFocus) {
      ref.read(focusControllerProvider.notifier).start();
      ref.read(appFlowProvider.notifier).toFocus();
      return;
    }

    if (intent == SIIntent.reflect) {
      ref.read(appFlowProvider.notifier).toReflect();
      return;
    }

    if (text.toLowerCase().contains('insight')) {
      ref.read(appFlowProvider.notifier).toInsight();
      return;
    }
  }

  Future<void> stopSpeaking() async {
    await ref.read(voiceServiceProvider).stop();
  }
}
