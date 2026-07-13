enum CoreValueType {
  discipline,
  growth,
  clarity,
  resilience,
  creativity,
  connection,
  purpose,
}

class CoreValueDefinition {
  const CoreValueDefinition({
    required this.type,
    required this.title,
    required this.definition,
    required this.guidingQuestion,
    required this.supports,
  });

  final CoreValueType type;
  final String title;
  final String definition;
  final String guidingQuestion;
  final List<String> supports;
}

class CoreValueScore {
  const CoreValueScore({
    required this.type,
    required this.score,
    required this.definition,
    required this.guidingQuestion,
    required this.supports,
  });

  final CoreValueType type;
  final int score;
  final String definition;
  final String guidingQuestion;
  final List<String> supports;
}

class CoreValuesAlignment {
  const CoreValuesAlignment({
    required this.scores,
    required this.overall,
    required this.strongest,
    required this.mostNeglected,
    required this.recommendations,
    required this.selectedValues,
  });

  final Map<CoreValueType, CoreValueScore> scores;
  final int overall;
  final CoreValueType strongest;
  final CoreValueType mostNeglected;
  final List<String> recommendations;
  final Set<String> selectedValues;
}

const Map<CoreValueType, CoreValueDefinition>
coreValueDefinitions = <CoreValueType, CoreValueDefinition>{
  CoreValueType.discipline: CoreValueDefinition(
    type: CoreValueType.discipline,
    title: 'Discipline',
    definition:
        'Consistently taking action regardless of mood, motivation, or circumstances.',
    guidingQuestion: 'Am I doing what needs to be done?',
    supports: <String>['Habits', 'Streaks', 'Routines', 'Goal completion'],
  ),
  CoreValueType.growth: CoreValueDefinition(
    type: CoreValueType.growth,
    title: 'Growth',
    definition:
        'Continuous improvement through learning, experience, and personal development.',
    guidingQuestion: 'Am I becoming better than I was yesterday?',
    supports: <String>[
      'Learning goals',
      'Skill development',
      'Self-improvement',
      'Future Self',
    ],
  ),
  CoreValueType.clarity: CoreValueDefinition(
    type: CoreValueType.clarity,
    title: 'Clarity',
    definition:
        'Understanding priorities, direction, purpose, and next actions.',
    guidingQuestion: 'Do I know what matters most right now?',
    supports: <String>[
      'Planning',
      'Prioritization',
      'Decision making',
      'SI Console',
    ],
  ),
  CoreValueType.resilience: CoreValueDefinition(
    type: CoreValueType.resilience,
    title: 'Resilience',
    definition:
        'The ability to recover, adapt, and continue moving forward after setbacks.',
    guidingQuestion: 'How do I respond when things get difficult?',
    supports: <String>[
      'Recovery plans',
      'Goal setbacks',
      'Habit failures',
      'Stress management',
    ],
  ),
  CoreValueType.creativity: CoreValueDefinition(
    type: CoreValueType.creativity,
    title: 'Creativity',
    definition:
        'The ability to imagine, innovate, solve problems, and create meaningful work.',
    guidingQuestion: 'Am I creating, exploring, and expressing my ideas?',
    supports: <String>[
      'Projects',
      'Innovation',
      'Problem solving',
      'Personal expression',
    ],
  ),
  CoreValueType.connection: CoreValueDefinition(
    type: CoreValueType.connection,
    title: 'Connection',
    definition:
        'Building meaningful relationships with yourself, others, and the world around you.',
    guidingQuestion: 'Am I nurturing the relationships that matter?',
    supports: <String>[
      'Family',
      'Friends',
      'Community',
      'Collaboration',
      'Self-connection',
    ],
  ),
  CoreValueType.purpose: CoreValueDefinition(
    type: CoreValueType.purpose,
    title: 'Purpose',
    definition:
        'Living intentionally in alignment with mission, meaning, and future vision.',
    guidingQuestion: 'Am I moving toward the life I was meant to build?',
    supports: <String>[
      'Future Self',
      'Vision Planning',
      'Legacy',
      'Long-term goals',
      'Identity development',
    ],
  ),
};

String coreValueTitle(CoreValueType value) {
  return coreValueDefinitions[value]?.title ?? value.name;
}

CoreValueType? coreValueFromTitle(String value) {
  final String target = value.trim().toLowerCase();
  for (final CoreValueType type in CoreValueType.values) {
    if (coreValueTitle(type).toLowerCase() == target ||
        type.name.toLowerCase() == target) {
      return type;
    }
  }
  return null;
}
