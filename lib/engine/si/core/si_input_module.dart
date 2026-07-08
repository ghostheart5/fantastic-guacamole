// lib/engine/si/core/si_input_module.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIInputModule {
  const SIInputModule();

  SIContext process(SIInputPacket packet, {String? mood}) {
    final SILatentInputs l = packet.latent;

    final double frustration = siClamp01(l.frustration);
    final double excitement = siClamp01(l.excitement);
    final double confusion = siClamp01(l.confusion);
    final double confidence = siClamp01(l.confidence);
    final double hesitation = siClamp01(l.hesitation);

    final double stress = ((frustration + confusion + hesitation) / 3)
        .clamp(0.0, 1.0)
        .toDouble();

    final double engagement = (0.5 + (excitement - hesitation) * 0.5)
        .clamp(0.0, 1.0)
        .toDouble();

    final double fatigue = (0.2 + hesitation * 0.5 + confusion * 0.3)
        .clamp(0.0, 1.0)
        .toDouble();

    final double motivation = (excitement * 0.6 + confidence * 0.4)
        .clamp(0.0, 1.0)
        .toDouble();

    final double cognitiveLoad = (stress * 0.6 + fatigue * 0.4)
        .clamp(0.0, 1.0)
        .toDouble();

    final String resolvedMood = siNormalizeMood(
      mood ??
          packet.metadata['mood']?.toString() ??
          packet.context['mood']?.toString() ??
          'neutral',
    );

    final SIUserState userState = SIUserState(
      emotion: resolvedMood,
      cognitiveLoad: cognitiveLoad,
      stress: stress,
      motivation: motivation,
      engagement: engagement,
      fatigue: fatigue,
      frustration: frustration,
      excitement: excitement,
      stability: _stability(confidence: confidence, stress: stress),
    );

    return SIContext(input: packet, userState: userState);
  }

  String _stability({required double confidence, required double stress}) {
    if (confidence >= 0.75 && stress < 0.4) return 'stable';
    if (stress >= 0.7) return 'fragile';
    return 'volatile';
  }
}
