import 'package:audioplayers/audioplayers.dart';

class AudioService {
  void playDecisionPrimary() => _play('audio/decision_primary.wav');
  void playDecisionSecondary() => _play('audio/decision_secondary.wav');
  void playInputSend() => _play('audio/input_send.wav');
  void playSystemProcessing() => _play('audio/system_processing.wav');
  void playAlertOverload() => _play('audio/alert_overload.wav');

  void _play(String path) {
    final AudioPlayer player = AudioPlayer();
    player.play(AssetSource(path)).catchError((_) {}).then((_) {
      player.onPlayerComplete.first.then((_) => player.dispose());
    });
  }
}
