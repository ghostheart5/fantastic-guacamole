import 'package:fantastic_guacamole/engine/si/si_input_fusion.dart';

class EmotionalSignal {
  const EmotionalSignal({
    required this.mood,
    required this.intensity,
    required this.shift,
  });

  final String mood;
  final double intensity;
  final String shift;
}

class EmotionalEngine {
  const EmotionalEngine();

  EmotionalSignal infer({
    required String text,
    required SILatentInputs latent,
    String? previousMood,
  }) {
    final String lowered = text.toLowerCase();
    String mood = 'neutral';
    if (latent.frustration > 0.6 || lowered.contains('frustrated')) {
      mood = 'stressed';
    }
    if (latent.excitement > 0.6 || lowered.contains('excited')) {
      mood = 'excited';
    }
    if (latent.confusion > 0.5 || lowered.contains('confused')) {
      mood = 'confused';
    }

    final double intensity =
        (latent.frustration +
            latent.excitement +
            latent.confusion +
            latent.hesitation) /
        4;
    final String shift = previousMood == null || previousMood == mood
        ? 'stable'
        : '$previousMood->$mood';

    return EmotionalSignal(
      mood: mood,
      intensity: intensity.clamp(0.0, 1.0),
      shift: shift,
    );
  }

  String shapeReply(String reply, EmotionalSignal signal) {
    if (signal.mood == 'confused') {
      return '$reply\n\nI will keep this simple and step-by-step.';
    }
    if (signal.mood == 'stressed') {
      return '$reply\n\nLet us take one action at a time.';
    }
    if (signal.mood == 'excited') {
      return '$reply\n\nMomentum looks great, keep it rolling.';
    }
    return reply;
  }
}
