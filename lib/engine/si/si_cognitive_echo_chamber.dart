class EchoChamber {
  const EchoChamber({
    required this.emotionalEchoes,
    required this.memoryEchoes,
    required this.intentEchoes,
    required this.contextualEchoes,
    required this.prediction,
  });

  final List<String> emotionalEchoes;
  final List<String> memoryEchoes;
  final List<String> intentEchoes;
  final List<String> contextualEchoes;
  final String prediction;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional_echoes': emotionalEchoes,
      'memory_echoes': memoryEchoes,
      'intent_echoes': intentEchoes,
      'contextual_echoes': contextualEchoes,
      'prediction': prediction,
    };
  }
}

class CognitiveEchoChamber {
  const CognitiveEchoChamber();

  EchoChamber generate({
    required String mood,
    required String intent,
    required String appState,
  }) {
    return EchoChamber(
      emotionalEchoes: <String>[mood, 'regulated_$mood'],
      memoryEchoes: <String>['recent_task_memory', 'goal_link_memory'],
      intentEchoes: <String>[intent, 'sub_$intent'],
      contextualEchoes: <String>[appState, 'session_context'],
      prediction: 'User likely needs concise next action with reassurance.',
    );
  }
}
