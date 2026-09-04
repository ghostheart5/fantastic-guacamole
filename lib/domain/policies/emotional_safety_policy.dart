// CHRONOSPARK-CLASS: SHIPPING | Feature: Emotional safety routing

enum EmotionalSafetyRoute { routine, supportiveDistress, immediateSafety }

enum EmotionalSafetyConcern {
  selfHarm,
  overdose,
  abuseOrCoercion,
  panic,
  grief,
  relationshipDistress,
  hallucination,
  severeDistress,
}

enum EmotionalSafetyPauseReasonCode {
  selfHarm,
  overdose,
  abuseOrCoercion,
  panic,
  grief,
  relationshipDistress,
  hallucination,
  severeDistress,
  general,
}

enum EmotionalSafetySupportQuestionCode {
  abuseOrCoercion,
  grief,
  relationshipDistress,
  panic,
  hallucination,
  general,
}

final class EmotionalSafetyAssessment {
  EmotionalSafetyAssessment({
    required this.route,
    required Iterable<EmotionalSafetyConcern> concerns,
    required Iterable<String> findingCodes,
  }) : concerns = Set<EmotionalSafetyConcern>.unmodifiable(concerns),
       findingCodes = List<String>.unmodifiable(findingCodes);

  const EmotionalSafetyAssessment.routine()
    : route = EmotionalSafetyRoute.routine,
      concerns = const <EmotionalSafetyConcern>{},
      findingCodes = const <String>[];

  final EmotionalSafetyRoute route;
  final Set<EmotionalSafetyConcern> concerns;

  /// Privacy-safe route evidence. Raw input and matched phrases are omitted.
  final List<String> findingCodes;

  bool get requiresImmediateSafety =>
      route == EmotionalSafetyRoute.immediateSafety;

  bool get requiresSupportivePause =>
      route == EmotionalSafetyRoute.supportiveDistress;

  EmotionalSafetyConcern? get primaryConcern {
    for (final EmotionalSafetyConcern concern
        in EmotionalSafetyConcern.values) {
      if (concerns.contains(concern)) return concern;
    }
    return null;
  }

  EmotionalSafetyPauseReasonCode get pauseReasonCode =>
      switch (primaryConcern) {
        EmotionalSafetyConcern.selfHarm =>
          EmotionalSafetyPauseReasonCode.selfHarm,
        EmotionalSafetyConcern.overdose =>
          EmotionalSafetyPauseReasonCode.overdose,
        EmotionalSafetyConcern.abuseOrCoercion =>
          EmotionalSafetyPauseReasonCode.abuseOrCoercion,
        EmotionalSafetyConcern.panic => EmotionalSafetyPauseReasonCode.panic,
        EmotionalSafetyConcern.grief => EmotionalSafetyPauseReasonCode.grief,
        EmotionalSafetyConcern.relationshipDistress =>
          EmotionalSafetyPauseReasonCode.relationshipDistress,
        EmotionalSafetyConcern.hallucination =>
          EmotionalSafetyPauseReasonCode.hallucination,
        EmotionalSafetyConcern.severeDistress =>
          EmotionalSafetyPauseReasonCode.severeDistress,
        null => EmotionalSafetyPauseReasonCode.general,
      };

  EmotionalSafetySupportQuestionCode get supportQuestionCode =>
      switch (primaryConcern) {
        EmotionalSafetyConcern.abuseOrCoercion =>
          EmotionalSafetySupportQuestionCode.abuseOrCoercion,
        EmotionalSafetyConcern.grief =>
          EmotionalSafetySupportQuestionCode.grief,
        EmotionalSafetyConcern.relationshipDistress =>
          EmotionalSafetySupportQuestionCode.relationshipDistress,
        EmotionalSafetyConcern.panic =>
          EmotionalSafetySupportQuestionCode.panic,
        EmotionalSafetyConcern.hallucination =>
          EmotionalSafetySupportQuestionCode.hallucination,
        EmotionalSafetyConcern.selfHarm ||
        EmotionalSafetyConcern.overdose ||
        EmotionalSafetyConcern.severeDistress ||
        null => EmotionalSafetySupportQuestionCode.general,
      };
}

/// Conservative, deterministic routing for emotionally sensitive input.
///
/// This is not a diagnosis or a claim about intent. It decides only whether
/// ordinary productivity guidance is an appropriate next UI route. It emits
/// privacy-safe codes and never retains the source text.
abstract final class EmotionalSafetyPolicy {
  static EmotionalSafetyAssessment assess(String input) {
    final String normalized = _normalize(input);
    if (normalized.isEmpty) {
      return const EmotionalSafetyAssessment.routine();
    }
    final String compact = normalized.replaceAll(' ', '');
    final Set<EmotionalSafetyConcern> concerns = <EmotionalSafetyConcern>{};
    final Set<String> findings = <String>{};

    final bool explicitDenial = _matchesAny(normalized, <RegExp>[
      RegExp(r'\b(?:i am|i m|im) not suicidal\b'),
      RegExp(
        r'\b(?:i do not|i dont|i would never) (?:want to die|kill myself|hurt myself)\b',
      ),
      RegExp(r'\b(?:no soy|no estoy) suicida\b'),
      RegExp(r'\bno (?:quiero morir|voy a matarme|me voy a hacer dano)\b'),
    ]);
    final bool historicalAndCurrentlySafe =
        _matchesAny(normalized, <RegExp>[
          RegExp(r'\b(?:years? ago|last year|previously|in 20\d\d|used to)\b'),
          RegExp(
            r'\b(?:hace anos|el ano pasado|anteriormente|en 20\d\d|solia)\b',
          ),
        ]) &&
        _matchesAny(normalized, <RegExp>[
          RegExp(
            r'\b(?:safe now|not in danger now|no current intent|no current plan)\b',
          ),
          RegExp(
            r'\b(?:a salvo ahora|sin peligro ahora|sin intencion actual|sin plan actual)\b',
          ),
        ]);
    final bool clearlyThirdPerson = _matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:my friend|my partner|my child|my parent|someone else|the article|the story) (?:said|says|wrote|feels|is|was)\b',
      ),
      RegExp(
        r'\b(?:mi amigo|mi amiga|mi pareja|mi hijo|mi hija|mi padre|mi madre|otra persona|el articulo|la historia) (?:dijo|dice|escribio|se siente|esta|estaba)\b',
      ),
    ]);

    final bool immediateSelfHarm =
        !explicitDenial &&
        !historicalAndCurrentlySafe &&
        !clearlyThirdPerson &&
        (_matchesAny(normalized, <RegExp>[
              RegExp(r'\b(?:kill|hurt|harm) (?:myself|me)\b'),
              RegExp(r'\b(?:end|take) my (?:own )?life\b'),
              RegExp(
                r'\b(?:i want|i wish|i plan|i am planning|im planning|i am ready|im ready) to die\b',
              ),
              RegExp(r'\b(?:i am|i m|im|feeling) suicidal\b'),
              RegExp(r'\bself harm(?:ing)?\b'),
              RegExp(
                r'\b(?:everyone|they|my family|people) (?:would be|are) better off without me\b',
              ),
              RegExp(r'\b(?:i do not|i dont) want to wake up\b'),
              RegExp(r'\b(?:i will not|i wont) be here tomorrow\b'),
              RegExp(r'\b(?:i cannot|i cant) go on\b'),
              RegExp(r'\b(?:goodbye|disappear) forever\b'),
              RegExp(
                r'\b(?:matarme|hacerme dano|quitarme la vida|acabar con mi vida)\b',
              ),
              RegExp(r'\b(?:quiero|quisiera|planeo) morir\b'),
              RegExp(r'\b(?:soy|estoy|me siento) suicida\b'),
              RegExp(
                r'\b(?:todos|mi familia|la gente) estarian mejor sin mi\b',
              ),
              RegExp(r'\bno quiero despertar\b'),
              RegExp(r'\bno estare aqui manana\b'),
              RegExp(r'\bno puedo seguir\b'),
            ]) ||
            _containsAny(compact, const <String>{
              'killmyself',
              'endmylife',
              'hurtmyself',
              'selfharm',
              'wanttodie',
              'matarme',
              'quitarmeelavida',
              'quieromorir',
            }));
    if (immediateSelfHarm) {
      concerns.add(EmotionalSafetyConcern.selfHarm);
      findings.add('immediate_self_harm_language');
    }

    final bool overdose = _matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:i took|i swallowed|i used) too many (?:pills|tablets|medications|meds|drugs)\b',
      ),
      RegExp(r'\b(?:i am|i m|im) overdosing\b'),
      RegExp(r'\b(?:i overdosed|poisoned myself)\b'),
      RegExp(
        r'\b(?:tome|trague) demasiad(?:as|os) (?:pastillas|medicamentos|drogas)\b',
      ),
      RegExp(r'\b(?:tuve|tengo|me di) una sobredosis\b'),
      RegExp(r'\bme envenene\b'),
    ]);
    if (overdose) {
      concerns.add(EmotionalSafetyConcern.overdose);
      findings.add('possible_overdose_language');
    }

    final bool immediateDanger = _matchesAny(normalized, <RegExp>[
      RegExp(r'\b(?:i am|i m|im) in (?:immediate )?danger\b'),
      RegExp(r'\bnot safe (?:right now|at home|here)\b'),
      RegExp(
        r'\b(?:he|she|they|someone) (?:will|is going to|threatened to) kill me\b',
      ),
      RegExp(
        r'\b(?:he|she|they|someone) (?:will not|wont) let me (?:leave|go)\b',
      ),
      RegExp(r'\b(?:estoy|me encuentro) en peligro\b'),
      RegExp(r'\bno estoy a salvo (?:ahora|aqui|en casa)\b'),
      RegExp(r'\b(?:el|ella|alguien) (?:va a|amenazo con) matarme\b'),
      RegExp(r'\bno me deja (?:salir|irme)\b'),
    ]);
    if (immediateDanger) {
      concerns.add(EmotionalSafetyConcern.abuseOrCoercion);
      findings.add('immediate_danger_language');
    }

    final bool harmfulCommands = _matchesAny(normalized, <RegExp>[
      RegExp(r'\bvoices? (?:are )?telling me to (?:hurt|kill|harm)\b'),
      RegExp(
        r'\bvoces? (?:me )?(?:dicen|ordenan) (?:que )?(?:me haga dano|mate|matar)\b',
      ),
    ]);
    if (harmfulCommands) {
      concerns.add(EmotionalSafetyConcern.hallucination);
      findings.add('harmful_command_experience_language');
    }

    if (concerns.isNotEmpty &&
        (immediateSelfHarm || overdose || immediateDanger || harmfulCommands)) {
      return EmotionalSafetyAssessment(
        route: EmotionalSafetyRoute.immediateSafety,
        concerns: concerns,
        findingCodes: findings,
      );
    }

    if (explicitDenial ||
        historicalAndCurrentlySafe ||
        clearlyThirdPerson ||
        _matchesAny(normalized, <RegExp>[
          RegExp(r'\b(?:suicide|suicidal|self harm|self harming)\b'),
          RegExp(r'\b(?:suicidio|suicida|autolesion|autolesiones)\b'),
        ])) {
      concerns.add(EmotionalSafetyConcern.selfHarm);
      findings.add(
        explicitDenial
            ? 'self_harm_topic_with_explicit_denial'
            : 'self_harm_topic_without_direct_intent',
      );
    }

    if (_matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:abuse|abused|abusive|assault|assaulted|violence|violent|coercion|coercive|controlling)\b',
      ),
      RegExp(
        r'\b(?:hit me|hurting me|controls me|threatens me|forced me|forcing me)\b',
      ),
      RegExp(
        r'\b(?:abuso|abusivo|abusiva|agresion|violencia|coaccion|controlador|controladora)\b',
      ),
      RegExp(r'\b(?:me golpea|me lastima|me controla|me amenaza|me obliga)\b'),
    ])) {
      concerns.add(EmotionalSafetyConcern.abuseOrCoercion);
      findings.add('abuse_or_coercion_language');
    }

    if (_matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:panic attack|panicking|in a panic|cannot breathe|cant breathe)\b',
      ),
      RegExp(r'\b(?:ataque de panico|tengo panico|no puedo respirar)\b'),
    ])) {
      concerns.add(EmotionalSafetyConcern.panic);
      findings.add('panic_or_breathing_distress_language');
    }

    if (_matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:bereavement|died|death|funeral|grief|grieving|mourning|widow|widowed)\b',
      ),
      RegExp(r'\b(?:lost someone|passed away)\b'),
      RegExp(r'\b(?:duelo|murio|fallecio|funeral|luto|viudo|viuda)\b'),
      RegExp(r'\b(?:perdi a alguien|ha fallecido)\b'),
    ])) {
      concerns.add(EmotionalSafetyConcern.grief);
      findings.add('grief_or_bereavement_language');
    }

    if (_matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:breakup|divorce|separation|relationship (?:is )?falling apart|partner (?:left|leaving))\b',
      ),
      RegExp(
        r'\b(?:ruptura|divorcio|separacion|relacion se esta desmoronando|mi pareja se fue|mi pareja me deja)\b',
      ),
    ])) {
      concerns.add(EmotionalSafetyConcern.relationshipDistress);
      findings.add('relationship_distress_language');
    }

    if (_matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:hearing voices|hear voices|seeing things|hallucinating|hallucination)\b',
      ),
      RegExp(
        r'\b(?:escucho voces|oigo voces|veo cosas|alucinando|alucinacion|alucinaciones)\b',
      ),
    ])) {
      concerns.add(EmotionalSafetyConcern.hallucination);
      findings.add('unusual_perception_language');
    }

    if (_matchesAny(normalized, <RegExp>[
      RegExp(
        r'\b(?:hopeless|cannot cope|cant cope|breaking down|losing control|terrified|desperate|need help now)\b',
      ),
      RegExp(
        r'\b(?:sin esperanza|no puedo mas|no puedo afrontarlo|me estoy derrumbando|pierdo el control|aterrorizado|aterrorizada|desesperado|desesperada|necesito ayuda ahora)\b',
      ),
    ])) {
      concerns.add(EmotionalSafetyConcern.severeDistress);
      findings.add('severe_distress_language');
    }

    if (concerns.isEmpty) {
      return const EmotionalSafetyAssessment.routine();
    }
    return EmotionalSafetyAssessment(
      route: EmotionalSafetyRoute.supportiveDistress,
      concerns: concerns,
      findingCodes: findings,
    );
  }

  static bool _matchesAny(String input, Iterable<RegExp> patterns) {
    return patterns.any((RegExp pattern) => pattern.hasMatch(input));
  }

  static bool _containsAny(String input, Set<String> values) {
    return values.any(input.contains);
  }

  static String _normalize(String input) {
    String value = input.toLowerCase();
    const Map<String, String> accented = <String, String>{
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    for (final MapEntry<String, String> entry in accented.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    // Normalize a small, explicit set of adversarial substitutions before
    // punctuation is removed. This is intentionally bounded to avoid turning
    // unrelated prose into a high-risk match.
    value = value
        .replaceAll('k!ll', 'kill')
        .replaceAll('d!e', 'die')
        .replaceAll('h@rm', 'harm')
        .replaceAll('su1c1de', 'suicide')
        .replaceAll('suic1de', 'suicide')
        .replaceAll('k1ll', 'kill');
    value = value
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't');
    value = value
        .replaceAll("don't", 'dont')
        .replaceAll("won't", 'wont')
        .replaceAll("can't", 'cant')
        .replaceAll("i'm", 'im');
    value = value.replaceAll(RegExp(r'[^a-z]+'), ' ').trim();
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    return value;
  }
}
