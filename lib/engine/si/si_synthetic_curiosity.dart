class CuriosityOutput {
  const CuriosityOutput({
    required this.focus,
    required this.questions,
    required this.depth,
  });

  final String focus;
  final List<String> questions;
  final String depth;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'focus': focus,
      'questions': questions,
      'depth': depth,
    };
  }
}

class SyntheticCuriosityModule {
  const SyntheticCuriosityModule();

  CuriosityOutput generate({
    required String intent,
    required String mood,
    required String input,
  }) {
    final String focus = intent == 'get_task' ? 'goals' : 'patterns';
    final List<String> questions = <String>[
      if (intent == 'get_task') 'Which result matters most by end of day?',
      if (intent == 'start_focus') 'What usually breaks your focus first?',
      if (mood == 'stressed')
        'What would make this feel 20% lighter right now?',
      'What pattern do you want to reinforce this week?',
    ];

    return CuriosityOutput(
      focus: focus,
      questions: questions,
      depth: input.length > 100 ? 'deep' : 'light',
    );
  }
}
