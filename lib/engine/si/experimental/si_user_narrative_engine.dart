class UserNarrative {
  const UserNarrative({
    required this.arc,
    required this.theme,
    required this.challenge,
    required this.progressBeat,
    required this.nextStoryPrompt,
  });

  final String arc;
  final String theme;
  final String challenge;
  final String progressBeat;
  final String nextStoryPrompt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'arc': arc,
      'theme': theme,
      'challenge': challenge,
      'progress_beat': progressBeat,
      'next_story_prompt': nextStoryPrompt,
    };
  }
}

class UserNarrativeEngine {
  const UserNarrativeEngine();

  UserNarrative build({
    required String intent,
    required List<String> goals,
    required double confidence,
  }) {
    final String arc = goals.isEmpty ? 'orientation_arc' : 'growth_arc';
    final String theme = intent == 'reflect' ? 'reflection' : 'momentum';
    final String challenge = confidence < 0.55
        ? 'clarity_gap'
        : 'execution_friction';
    final String beat = confidence >= 0.7
        ? 'You are consolidating capability through consistent action.'
        : 'You are moving from uncertainty into structure.';

    return UserNarrative(
      arc: arc,
      theme: theme,
      challenge: challenge,
      progressBeat: beat,
      nextStoryPrompt: 'What chapter do you want to complete today?',
    );
  }
}
