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

class InputFusionLayer {
  const InputFusionLayer();

  Map<String, dynamic> fuse(SIInputPacket packet) {
    final List<String> weightedHistory = packet.history.reversed
        .take(5)
        .toList()
        .reversed
        .toList();
    return <String, dynamic>{
      'text': packet.text,
      'history_recent': weightedHistory,
      'metadata': packet.metadata,
      'context': packet.context,
      'voice_text': packet.nonText.voiceToText,
      'image_labels': packet.nonText.imageLabels,
      'ui_state': packet.nonText.uiState,
      'sensor_data': packet.nonText.sensorData,
      'time_triggers': packet.nonText.timeTriggers,
      'behavior_patterns': packet.nonText.behaviorPatterns,
      'latent': <String, dynamic>{
        'frustration': packet.latent.frustration,
        'excitement': packet.latent.excitement,
        'confusion': packet.latent.confusion,
        'confidence': packet.latent.confidence,
        'hesitation': packet.latent.hesitation,
      },
    };
  }
}
