// Module 2 — Input
// Pipeline step: raw input → SIContext { input, userState }
// Merges: si_input_fusion + si_user_state_engine + si_user_state_tracker

// ─── Input types ─────────────────────────────────────────────────────────────

class SINonTextInputs {
  const SINonTextInputs({
    this.voiceToText,
    this.imageLabels = const <String>[],
    this.uiState = const <String, dynamic>{},
    this.sensorData = const <String, dynamic>{},
    this.timeTriggers = const <String>[],
    this.behaviorPatterns = const <String>[],
  });

  final String? voiceToText;
  final List<String> imageLabels;
  final Map<String, dynamic> uiState;
  final Map<String, dynamic> sensorData;
  final List<String> timeTriggers;
  final List<String> behaviorPatterns;
}

class SILatentInputs {
  const SILatentInputs({
    this.frustration = 0,
    this.excitement = 0,
    this.confusion = 0,
    this.confidence = 0.5,
    this.hesitation = 0,
  });

  final double frustration;
  final double excitement;
  final double confusion;
  final double confidence;
  final double hesitation;
}

class SIInputPacket {
  const SIInputPacket({
    required this.text,
    this.history = const <String>[],
    this.metadata = const <String, dynamic>{},
    this.context = const <String, dynamic>{},
    this.nonText = const SINonTextInputs(),
    this.latent = const SILatentInputs(),
  });

  final String text;
  final List<String> history;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> context;
  final SINonTextInputs nonText;
  final SILatentInputs latent;
}

// ─── User state ───────────────────────────────────────────────────────────────

class SIUserState {
  const SIUserState({
    required this.emotion,
    required this.cognitiveLoad,
    required this.stress,
    required this.motivation,
    required this.engagement,
    required this.fatigue,
    required this.frustration,
    required this.excitement,
    required this.stability,
  });

  final String emotion;
  final double cognitiveLoad;
  final double stress;
  final double motivation;
  final double engagement;
  final double fatigue;
  final double frustration;
  final double excitement;
  final String stability;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'emotion': emotion,
    'cognitive_load': cognitiveLoad,
    'stress': stress,
    'motivation': motivation,
    'engagement': engagement,
    'fatigue': fatigue,
    'frustration': frustration,
    'excitement': excitement,
    'stability': stability,
  };
}

// ─── Pipeline output contract ─────────────────────────────────────────────────

class SIContext {
  const SIContext({required this.input, required this.userState});

  final SIInputPacket input;
  final SIUserState userState;
}

// ─── Module ───────────────────────────────────────────────────────────────────

class SIInputModule {
  const SIInputModule();

  SIContext process(SIInputPacket packet, {String mood = 'neutral'}) {
    final SILatentInputs l = packet.latent;

    final double stress = ((l.frustration + l.confusion + l.hesitation) / 3)
        .clamp(0.0, 1.0);
    final double engagement = (0.6 + (l.excitement - l.hesitation) * 0.4).clamp(
      0.0,
      1.0,
    );
    final double fatigue = (0.3 + l.hesitation * 0.4 + l.confusion * 0.3).clamp(
      0.0,
      1.0,
    );
    final double motivation = (l.excitement + l.confidence * 0.5).clamp(
      0.0,
      1.0,
    );
    final String stability = l.confidence >= 0.7 ? 'stable' : 'volatile';

    final SIUserState userState = SIUserState(
      emotion: mood,
      cognitiveLoad: (stress + fatigue).clamp(0.0, 1.0),
      stress: stress,
      motivation: motivation,
      engagement: engagement,
      fatigue: fatigue,
      frustration: l.frustration,
      excitement: l.excitement,
      stability: stability,
    );

    return SIContext(input: packet, userState: userState);
  }
}
