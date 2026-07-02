import 'package:fantastic_guacamole/core/services/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioFeedbackControllerProvider = Provider<AudioFeedbackController>(
  (ref) => const AudioFeedbackController(),
);

class AudioFeedbackController {
  const AudioFeedbackController();

  void playDecision() {
    AudioService.play('audio/ai_decision.wav', true);
  }

  void playFocusStart() {
    AudioService.play('audio/focus_start.wav', true);
  }

  void playTaskComplete() {
    AudioService.play('audio/task_complete.wav', true);
  }
}
