import 'package:fantastic_guacamole/engine/si/si_input_fusion.dart';

class UserState {
  const UserState({
    required this.emotion,
    required this.cognitiveLoad,
    required this.stress,
    required this.motivation,
    required this.engagement,
    required this.fatigue,
    required this.frustration,
    required this.excitement,
  });

  final String emotion;
  final double cognitiveLoad;
  final double stress;
  final double motivation;
  final double engagement;
  final double fatigue;
  final double frustration;
  final double excitement;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotion': emotion,
      'cognitive_load': cognitiveLoad,
      'stress': stress,
      'motivation': motivation,
      'engagement': engagement,
      'fatigue': fatigue,
      'frustration': frustration,
      'excitement': excitement,
    };
  }
}

class UserStateEngine {
  const UserStateEngine();

  UserState evaluate({required String mood, required SILatentInputs latent}) {
    final double stress =
        ((latent.frustration + latent.confusion + latent.hesitation) / 3).clamp(
          0.0,
          1.0,
        );
    final double engagement =
        (0.6 + (latent.excitement - latent.hesitation) * 0.4).clamp(0.0, 1.0);
    final double fatigue =
        (0.3 + latent.hesitation * 0.4 + latent.confusion * 0.3).clamp(
          0.0,
          1.0,
        );

    return UserState(
      emotion: mood,
      cognitiveLoad: (stress + fatigue).clamp(0.0, 1.0),
      stress: stress,
      motivation: (latent.excitement + latent.confidence * 0.5).clamp(0.0, 1.0),
      engagement: engagement,
      fatigue: fatigue,
      frustration: latent.frustration,
      excitement: latent.excitement,
    );
  }
}
