enum SoulMapDimension {
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

class SoulMapProfile {
  const SoulMapProfile({
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

  factory SoulMapProfile.empty() {
    return const SoulMapProfile(
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

  SoulMapProfile copyWith({
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
    return SoulMapProfile(
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

  factory SoulMapProfile.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] as String?)?.trim() ?? '';
    return SoulMapProfile(
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

class SoulMapFutureSelfComparison {
  const SoulMapFutureSelfComparison({
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

class SoulMapDimensionDefinition {
  const SoulMapDimensionDefinition({
    required this.dimension,
    required this.title,
    required this.prompt,
    required this.description,
  });

  final SoulMapDimension dimension;
  final String title;
  final String prompt;
  final String description;
}

class SoulMapDimensionScore {
  const SoulMapDimensionScore({
    required this.dimension,
    required this.score,
    required this.definition,
  });

  final SoulMapDimension dimension;
  final int score;
  final SoulMapDimensionDefinition definition;
}

class SoulMapAlignment {
  const SoulMapAlignment({
    required this.scores,
    required this.overall,
    required this.strongest,
    required this.weakest,
    required this.recommendations,
  });

  final Map<SoulMapDimension, SoulMapDimensionScore> scores;
  final int overall;
  final SoulMapDimension strongest;
  final SoulMapDimension weakest;
  final List<String> recommendations;
}

class SoulMapSummary {
  const SoulMapSummary({
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

const String soulMapOneSentenceDefinition =
    'SoulMap is the personal identity and purpose system that helps users understand who they are, '
    'who they want to become, what they value most, and how their goals, habits, decisions, and timeline '
    'align with the life they are trying to create.';

const Map<SoulMapDimension, SoulMapDimensionDefinition>
soulMapDimensionDefinitions = <SoulMapDimension, SoulMapDimensionDefinition>{
  SoulMapDimension.purpose: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.purpose,
    title: 'Purpose',
    prompt: 'Why do I exist?',
    description: 'Meaning and impact orientation.',
  ),
  SoulMapDimension.identity: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.identity,
    title: 'Identity',
    prompt: 'Who am I becoming?',
    description: 'Traits, character, and self-concept.',
  ),
  SoulMapDimension.coreValues: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.coreValues,
    title: 'Core Values',
    prompt: 'How do I want to live?',
    description: 'Operating compass for decisions.',
  ),
  SoulMapDimension.futureSelf: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.futureSelf,
    title: 'Future Self',
    prompt: 'Who do I want to become in 1/5/10 years?',
    description: 'Identity projection over time.',
  ),
  SoulMapDimension.vision: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.vision,
    title: 'Vision',
    prompt: 'What life am I building?',
    description: 'Long-horizon life architecture.',
  ),
  SoulMapDimension.passions: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.passions,
    title: 'Passions',
    prompt: 'What energizes me?',
    description: 'Energizing work and interests.',
  ),
  SoulMapDimension.lifeStory: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.lifeStory,
    title: 'Life Story',
    prompt: 'What shaped me?',
    description: 'Narrative continuity and resilience context.',
  ),
  SoulMapDimension.relationships: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.relationships,
    title: 'Relationships',
    prompt: 'Who matters most, and how am I showing up for them?',
    description: 'Belonging and relational stewardship.',
  ),
  SoulMapDimension.legacy: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.legacy,
    title: 'Legacy',
    prompt: 'What do I want to leave behind?',
    description: 'Contribution beyond short-term outcomes.',
  ),
  SoulMapDimension.reflections: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.reflections,
    title: 'Reflections',
    prompt: 'What am I learning about myself?',
    description: 'Self-review and course correction.',
  ),
  SoulMapDimension.growthJourney: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.growthJourney,
    title: 'Growth Journey',
    prompt: 'How far have I come?',
    description: 'Progress accumulation and evolution.',
  ),
  SoulMapDimension.lifeDirection: SoulMapDimensionDefinition(
    dimension: SoulMapDimension.lifeDirection,
    title: 'Life Direction',
    prompt: 'What kind of life am I creating?',
    description: 'Trajectory coherence across systems.',
  ),
};

String soulMapDimensionTitle(SoulMapDimension dimension) {
  return soulMapDimensionDefinitions[dimension]?.title ?? dimension.name;
}
