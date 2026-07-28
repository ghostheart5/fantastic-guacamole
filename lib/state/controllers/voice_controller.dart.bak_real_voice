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

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceState>(
  VoiceController.new,
);

class VoiceController extends Notifier<VoiceState> {
  static const String _unavailableMessage =
      'Voice interactions are unavailable in this build.';

  @override
  VoiceState build() => const VoiceState();

  Future<void> startListening() async {
    state = state.copyWith(
      isAvailable: false,
      isListening: false,
      error: _unavailableMessage,
    );
  }

  Future<void> stopListening() async {
    state = state.copyWith(isListening: false);
  }

  Future<void> stopSpeaking() async {
    return;
  }
}
