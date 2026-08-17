enum PersonalAlignmentDimension {
  purpose,
  identity,
  coreValues,
  futureSelf,
  vision,
  passions,
  lifeStory,
  relationships,
  legacy,
  reflections,
  growthJourney,
  lifeDirection,
}

class PersonalAlignmentProfile {
  const PersonalAlignmentProfile({
    required this.purposeStatement,
    required this.identityStatement,
    required this.futureSelfOneYear,
    required this.futureSelfFiveYears,
    required this.futureSelfTenYears,
    required this.visionStatement,
    required this.passionsStatement,
    required this.lifeStorySummary,
    required this.relationshipsFocus,
    required this.legacyGoal,
    required this.reflectionsNotes,
    required this.lifeDirectionStatement,
  });

  final String purposeStatement;
  final String identityStatement;
  final String futureSelfOneYear;
  final String futureSelfFiveYears;
  final String futureSelfTenYears;
  final String visionStatement;
  final String passionsStatement;
  final String lifeStorySummary;
  final String relationshipsFocus;
  final String legacyGoal;
  final String reflectionsNotes;
  final String lifeDirectionStatement;

  factory PersonalAlignmentProfile.empty() {
    return const PersonalAlignmentProfile(
      purposeStatement: '',
      identityStatement: '',
      futureSelfOneYear: '',
      futureSelfFiveYears: '',
      futureSelfTenYears: '',
      visionStatement: '',
      passionsStatement: '',
      lifeStorySummary: '',
      relationshipsFocus: '',
      legacyGoal: '',
      reflectionsNotes: '',
      lifeDirectionStatement: '',
    );
  }

  PersonalAlignmentProfile copyWith({
    String? purposeStatement,
    String? identityStatement,
    String? futureSelfOneYear,
    String? futureSelfFiveYears,
    String? futureSelfTenYears,
    String? visionStatement,
    String? passionsStatement,
    String? lifeStorySummary,
    String? relationshipsFocus,
    String? legacyGoal,
    String? reflectionsNotes,
    String? lifeDirectionStatement,
  }) {
    return PersonalAlignmentProfile(
      purposeStatement: purposeStatement ?? this.purposeStatement,
      identityStatement: identityStatement ?? this.identityStatement,
      futureSelfOneYear: futureSelfOneYear ?? this.futureSelfOneYear,
      futureSelfFiveYears: futureSelfFiveYears ?? this.futureSelfFiveYears,
      futureSelfTenYears: futureSelfTenYears ?? this.futureSelfTenYears,
      visionStatement: visionStatement ?? this.visionStatement,
      passionsStatement: passionsStatement ?? this.passionsStatement,
      lifeStorySummary: lifeStorySummary ?? this.lifeStorySummary,
      relationshipsFocus: relationshipsFocus ?? this.relationshipsFocus,
      legacyGoal: legacyGoal ?? this.legacyGoal,
      reflectionsNotes: reflectionsNotes ?? this.reflectionsNotes,
      lifeDirectionStatement:
          lifeDirectionStatement ?? this.lifeDirectionStatement,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'purposeStatement': purposeStatement,
      'identityStatement': identityStatement,
      'futureSelfOneYear': futureSelfOneYear,
      'futureSelfFiveYears': futureSelfFiveYears,
      'futureSelfTenYears': futureSelfTenYears,
      'visionStatement': visionStatement,
      'passionsStatement': passionsStatement,
      'lifeStorySummary': lifeStorySummary,
      'relationshipsFocus': relationshipsFocus,
      'legacyGoal': legacyGoal,
      'reflectionsNotes': reflectionsNotes,
      'lifeDirectionStatement': lifeDirectionStatement,
    };
  }

  factory PersonalAlignmentProfile.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] as String?)?.trim() ?? '';
    return PersonalAlignmentProfile(
      purposeStatement: read('purposeStatement'),
      identityStatement: read('identityStatement'),
      futureSelfOneYear: read('futureSelfOneYear'),
      futureSelfFiveYears: read('futureSelfFiveYears'),
      futureSelfTenYears: read('futureSelfTenYears'),
      visionStatement: read('visionStatement'),
      passionsStatement: read('passionsStatement'),
      lifeStorySummary: read('lifeStorySummary'),
      relationshipsFocus: read('relationshipsFocus'),
      legacyGoal: read('legacyGoal'),
      reflectionsNotes: read('reflectionsNotes'),
      lifeDirectionStatement: read('lifeDirectionStatement'),
    );
  }

  int get authoredFieldCount {
    final List<String> fields = <String>[
      purposeStatement,
      identityStatement,
      futureSelfOneYear,
      futureSelfFiveYears,
      futureSelfTenYears,
      visionStatement,
      passionsStatement,
      lifeStorySummary,
      relationshipsFocus,
      legacyGoal,
      reflectionsNotes,
      lifeDirectionStatement,
    ];
    return fields.where((String value) => value.trim().isNotEmpty).length;
  }
}

class PersonalAlignmentFutureSelfComparison {
  const PersonalAlignmentFutureSelfComparison({
    required this.currentSelfAlignment,
    required this.futureSelfReadiness,
    required this.gap,
    required this.stance,
    required this.recommendation,
  });

  final int currentSelfAlignment;
  final int futureSelfReadiness;
  final int gap;
  final String stance;
  final String recommendation;
}

class PersonalAlignmentDimensionDefinition {
  const PersonalAlignmentDimensionDefinition({
    required this.dimension,
    required this.title,
    required this.prompt,
    required this.description,
  });

  final PersonalAlignmentDimension dimension;
  final String title;
  final String prompt;
  final String description;
}

class PersonalAlignmentDimensionScore {
  const PersonalAlignmentDimensionScore({
    required this.dimension,
    required this.score,
    required this.definition,
  });

  final PersonalAlignmentDimension dimension;
  final int score;
  final PersonalAlignmentDimensionDefinition definition;
}

class PersonalAlignmentAlignment {
  const PersonalAlignmentAlignment({
    required this.scores,
    required this.overall,
    required this.strongest,
    required this.weakest,
    required this.recommendations,
  });

  final Map<PersonalAlignmentDimension, PersonalAlignmentDimensionScore> scores;
  final int overall;
  final PersonalAlignmentDimension strongest;
  final PersonalAlignmentDimension weakest;
  final List<String> recommendations;
}

class PersonalAlignmentSummary {
  const PersonalAlignmentSummary({
    required this.definition,
    required this.purposeStatement,
    required this.futureSelfVision,
    required this.lifeDirectionStatement,
  });

  final String definition;
  final String purposeStatement;
  final String futureSelfVision;
  final String lifeDirectionStatement;
}

const String personalAlignmentOneSentenceDefinition =
    'PersonalAlignment is the personal identity and purpose system that helps users understand who they are, '
    'who they want to become, what they value most, and how their goals, habits, decisions, and timeline '
    'align with the life they are trying to create.';

const Map<PersonalAlignmentDimension, PersonalAlignmentDimensionDefinition>
personalAlignmentDimensionDefinitions =
    <PersonalAlignmentDimension, PersonalAlignmentDimensionDefinition>{
      PersonalAlignmentDimension.purpose: PersonalAlignmentDimensionDefinition(
        dimension: PersonalAlignmentDimension.purpose,
        title: 'Purpose',
        prompt: 'Why do I exist?',
        description: 'Meaning and impact orientation.',
      ),
      PersonalAlignmentDimension.identity: PersonalAlignmentDimensionDefinition(
        dimension: PersonalAlignmentDimension.identity,
        title: 'Identity',
        prompt: 'Who am I becoming?',
        description: 'Traits, character, and self-concept.',
      ),
      PersonalAlignmentDimension.coreValues:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.coreValues,
            title: 'Core Values',
            prompt: 'How do I want to live?',
            description: 'Operating compass for decisions.',
          ),
      PersonalAlignmentDimension.futureSelf:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.futureSelf,
            title: 'Future Self',
            prompt: 'Who do I want to become in 1/5/10 years?',
            description: 'Identity projection over time.',
          ),
      PersonalAlignmentDimension.vision: PersonalAlignmentDimensionDefinition(
        dimension: PersonalAlignmentDimension.vision,
        title: 'Vision',
        prompt: 'What life am I building?',
        description: 'Long-horizon life architecture.',
      ),
      PersonalAlignmentDimension.passions: PersonalAlignmentDimensionDefinition(
        dimension: PersonalAlignmentDimension.passions,
        title: 'Passions',
        prompt: 'What energizes me?',
        description: 'Energizing work and interests.',
      ),
      PersonalAlignmentDimension.lifeStory:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.lifeStory,
            title: 'Life Story',
            prompt: 'What shaped me?',
            description: 'Narrative continuity and resilience context.',
          ),
      PersonalAlignmentDimension.relationships:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.relationships,
            title: 'Relationships',
            prompt: 'Who matters most, and how am I showing up for them?',
            description: 'Belonging and relational stewardship.',
          ),
      PersonalAlignmentDimension.legacy: PersonalAlignmentDimensionDefinition(
        dimension: PersonalAlignmentDimension.legacy,
        title: 'Legacy',
        prompt: 'What do I want to leave behind?',
        description: 'Contribution beyond short-term outcomes.',
      ),
      PersonalAlignmentDimension.reflections:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.reflections,
            title: 'Reflections',
            prompt: 'What am I learning about myself?',
            description: 'Self-review and course correction.',
          ),
      PersonalAlignmentDimension.growthJourney:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.growthJourney,
            title: 'Growth Journey',
            prompt: 'How far have I come?',
            description: 'Progress accumulation and evolution.',
          ),
      PersonalAlignmentDimension.lifeDirection:
          PersonalAlignmentDimensionDefinition(
            dimension: PersonalAlignmentDimension.lifeDirection,
            title: 'Life Direction',
            prompt: 'What kind of life am I creating?',
            description: 'Trajectory coherence across systems.',
          ),
    };

String personalAlignmentDimensionTitle(PersonalAlignmentDimension dimension) {
  return personalAlignmentDimensionDefinitions[dimension]?.title ??
      dimension.name;
}
