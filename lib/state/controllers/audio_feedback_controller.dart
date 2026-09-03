import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioFeedbackControllerProvider = Provider<AudioFeedbackController>(
  (ref) => const AudioFeedbackController(),
);

class AudioFeedbackController {
  const AudioFeedbackController();

  Future<void> playDecision() =>
      AudioService.play(AppAssets.audioActionTick, true);

  Future<void> playTaskComplete() =>
      AudioService.play(AppAssets.audioMilestoneLift, true);
}
