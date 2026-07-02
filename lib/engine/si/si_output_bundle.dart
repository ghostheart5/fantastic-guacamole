class SIOutputBundle {
  SIOutputBundle({
    required this.reply,
    required this.summary,
    required this.keywords,
    required this.actions,
    required this.mood,
    required this.confidence,
    required this.intent,
    required this.tags,
    required this.memoryShouldWrite,
    required this.memoryData,
    required this.uiComponent,
    required this.uiPriority,
    required this.nextQuestion,
    this.outputMode = 'conversational',
    this.persona = 'assistant',
    this.pipelines = const <String>[],
    this.cognitiveStyle = 'analytical',
    this.compressedReasoning = '',
    this.agencyMode = 'assistive',
    this.linkedGoal,
    this.gravityScore = 0.0,
    this.intuitionHint = '',
    this.temporalHint = '',
    this.loadLevel = 'medium',
    this.presenceScore = 0.0,
    this.reasoning = const <String, dynamic>{},
  });

  final String reply;
  final String summary;
  final List<String> keywords;
  final List<String> actions;
  final String mood;
  final double confidence;
  final String intent;
  final List<String> tags;
  final bool memoryShouldWrite;
  final Map<String, dynamic> memoryData;
  final String uiComponent;
  final String uiPriority;
  final String nextQuestion;
  final String outputMode;
  final String persona;
  final List<String> pipelines;
  final String cognitiveStyle;
  final String compressedReasoning;
  final String agencyMode;
  final String? linkedGoal;
  final double gravityScore;
  final String intuitionHint;
  final String temporalHint;
  final String loadLevel;
  final double presenceScore;
  final Map<String, dynamic> reasoning;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reply': reply,
      'summary': summary,
      'keywords': keywords,
      'actions': actions,
      'mood': mood,
      'confidence': confidence,
      'intent': intent,
      'tags': tags,
      'memory_updates': <String, dynamic>{
        'should_write': memoryShouldWrite,
        'data': memoryData,
      },
      'ui_hints': <String, dynamic>{
        'component': uiComponent,
        'priority': uiPriority,
      },
      'next_question': nextQuestion,
      'output_mode': outputMode,
      'persona': persona,
      'pipelines': pipelines,
      'cognitive_style': cognitiveStyle,
      'compressed_reasoning': compressedReasoning,
      'agency_mode': agencyMode,
      'linked_goal': linkedGoal,
      'gravity_score': gravityScore,
      'intuition_hint': intuitionHint,
      'temporal_hint': temporalHint,
      'load_level': loadLevel,
      'presence_score': presenceScore,
      'reasoning': reasoning,
    };
  }
}
