import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  VoiceState build() => const VoiceState();

  Future<void> startListening() async {
    if (state.isListening) {
      return;
    }

    final bool available = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
      debugLogging: false,
    );

    if (!available) {
      state = state.copyWith(
        isAvailable: false,
        isListening: false,
        error: 'Voice input is not available on this device.',
      );
      return;
    }

    state = state.copyWith(
      isAvailable: true,
      isListening: true,
      recognizedText: '',
      lastResponse: '',
      clearError: true,
    );

    await _speech.listen(
      onResult: _handleResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    state = state.copyWith(isListening: false);
  }

  Future<void> stopSpeaking() async {
    await ref.read(voiceServiceProvider).stop();
  }

  void _handleResult(SpeechRecognitionResult result) {
    final String words = result.recognizedWords.trim();
    final bool finalResult = result.finalResult;

    state = state.copyWith(
      recognizedText: words,
      lastResponse: finalResult ? words : state.lastResponse,
      isListening: finalResult ? false : state.isListening,
      clearError: true,
    );
  }

  void _handleStatus(String status) {
    final String normalized = status.toLowerCase();

    if (normalized == 'done' ||
        normalized == 'notlistening' ||
        normalized == 'not_listening') {
      state = state.copyWith(isListening: false);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    final String message = error.errorMsg.toString();

    state = state.copyWith(
      isListening: false,
      isAvailable: _speech.isAvailable,
      error: message,
    );
  }
}
