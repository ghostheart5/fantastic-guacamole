part of 'smart_planner_query_controller.dart';

/// A deliberately bounded local interpretation, not a claim of general language
/// understanding. Actions must be present in the user's words or selected note.
/// If an executable objective is missing, ask rather than manufacture a workflow.
final class _PlannerIntent {
  _PlannerIntent({
    required this.objective,
    required this.languageCode,
    required this.constraints,
    required this.noteActions,
    required this.recovery,
    required this.interruptible,
    required this.caregiving,
    required this.deadlineNeedsDeparture,
    required this.timeNeedsClarification,
    required this.recoveryConflict,
    this.action,
    this.availableContainer,
  });

  factory _PlannerIntent.resolve({
    required _PlannerConversationContext conversation,
    required _PlannerEvidence evidence,
    required bool zeroEnergy,
    String? languageCode,
  }) {
    final source = conversation.evidenceSearchText;
    final language = _plannerLanguage(source) == 'es' || languageCode == 'es'
        ? 'es'
        : 'en';
    final requestedAction = _extractPlannerAction(source);
    final currentRecovery =
        _explicitRecoveryRequest(conversation.input) ||
        requestedAction == null &&
            RegExp(
              r"\bi(?: am|'m|m)?\s+(?:tired|exhausted|fatigued)\b|\bestoy cansad[oa]\b",
              caseSensitive: false,
            ).hasMatch(conversation.input) &&
            !_negatedPlannerClause(conversation.input);
    // A retained note can explain the matched commitment; unrelated notes cannot
    // silently add instructions to a newly named objective.
    final note = evidence.selectedNote;
    // Evidence resolution is the single relevance gate, including its limits.
    final noteRelevant = note != null;
    final noteText = noteRelevant ? (note.body ?? '') : '';
    final personConstraints = evidence.personContext.signals
        .where(
          (signal) =>
              signal.kind == PersonContextKind.boundary &&
              evidence.personContext._hasAppliedEffect(signal),
        )
        .map((signal) => signal.value)
        .join('\n');
    final constraints = _plannerExclusions(
      '$source\n$noteText\n$personConstraints',
    );
    final recovery =
        zeroEnergy ||
        currentRecovery ||
        (!_declinesPlannerRecovery(conversation.input) &&
            (requestedAction == null || conversation.continuesPriorSubject) &&
            _explicitRecoveryRequest(source));
    final noteActions = noteRelevant
        ? _plannerActionCandidates(noteText)
              .where((action) => !_actionContradicts(action, constraints))
              .take(3)
              .toList(growable: false)
        : const <String>[];
    String? action = requestedAction;
    if (action == null && !recovery) {
      action = _plannerReferencesSelectedNote(source)
          ? noteActions.firstOrNull ??
                _savedPlannerAction(evidence.focusTask?.title ?? '')
          : _savedPlannerAction(evidence.focusTask?.title ?? '') ??
                noteActions.firstOrNull;
      action ??=
          _savedPlannerAction(evidence.focusRhythm?.habit.title ?? '') ??
          _extractPlannerAction(
            evidence.operatingReceipt.focus?.recommendedAction ?? '',
          );
    }
    if (action != null && noteRelevant && !recovery) {
      final requestedTerms = _plannerTopicTerms(action);
      final requestedActivity = _plannerVerbRoot(
        action.split(' ').first.toLowerCase(),
      );
      for (final noteAction in noteActions) {
        final prerequisite = RegExp(
          r'^(.+?)\s+(?:before|antes de)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(noteAction);
        if (prerequisite == null) {
          continue;
        }
        final dependentActivity = _plannerVerbRoot(
          prerequisite.group(2)!.trim().split(' ').first.toLowerCase(),
        );
        if (requestedActivity != dependentActivity) {
          continue;
        }
        final dependentTerms = _plannerTopicTerms(prerequisite.group(2)!);
        final selectedActivityOnly =
            dependentTerms.isEmpty && _plannerReferencesSelectedNote(source);
        if (selectedActivityOnly ||
            requestedTerms.any(
              (term) => dependentTerms.any(
                (dependent) =>
                    term == dependent ||
                    dependent == '${term}ing' ||
                    dependent == '${term}ed',
              ),
            )) {
          action = noteAction;
          break;
        }
      }
    }
    if (action != null &&
        (_actionContradicts(action, constraints) ||
            _actionContradicts(
              _concretePlannerStep(
                action,
                spanish: language == 'es',
                constraints: constraints,
                availableContainer: _plannerAvailableContainer(source),
              ),
              constraints,
            ))) {
      action = null;
    }
    return _PlannerIntent(
      objective: conversation.subject,
      action: action,
      availableContainer: _plannerAvailableContainer(source),
      languageCode: language,
      constraints: constraints,
      // Matching an object can justify a prerequisite, not every other task
      // in that note. Broader note steps require the user's explicit selection.
      noteActions: _plannerReferencesSelectedNote(source)
          ? noteActions
          : noteActions.where((noteAction) => noteAction == action).toList(),
      recovery: recovery,
      recoveryConflict:
          zeroEnergy &&
          requestedAction != null &&
          constraints.any(
            (constraint) => RegExp(
              r'\b(break|pause|rest|recovery|descansar|descanso|pausa)\b',
              caseSensitive: false,
            ).hasMatch(constraint),
          ),
      caregiving: RegExp(
        r'\b(toddler|baby|child|children|caring for|supervising|beb[eé]|niñ[oa]s?|hij[oa]s?|cuidando)\b',
        caseSensitive: false,
      ).hasMatch(source),
      interruptible: RegExp(
        r"\b(toddler|baby|supervis(?:e|ing)|caring for|child.{0,30}(?:home|sick|needs? me)|cannot silence|can['’]t silence|interruptions|interrump|cuidando|beb[eé]|niñ[oa]|hij[oa])",
        caseSensitive: false,
      ).hasMatch(source),
      deadlineNeedsDeparture: _plannerDepartureUnresolved(source),
      timeNeedsClarification:
          _rejectsPlannerTimeBudget(conversation.input) &&
          _explicitPlanningTimeLimit(conversation.input) == null,
    );
  }

  final String objective;
  final String? action;
  final String? availableContainer;
  final String languageCode;
  final List<String> constraints;
  final List<String> noteActions;
  final bool recovery;
  final bool interruptible;
  final bool caregiving;
  final bool deadlineNeedsDeparture;
  final bool timeNeedsClarification;
  final bool recoveryConflict;
  bool get spanish => languageCode == 'es';
  String? get ambiguousWorkTarget =>
      action == null ||
          RegExp(r'\breceipts?\b', caseSensitive: false).hasMatch(action!)
      ? null
      : RegExp(
          r'^work(?:ing)?(?: solo| alone)? on\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(action!)?.group(1);
  bool get needsClarification =>
      recoveryConflict ||
      timeNeedsClarification ||
      !recovery && (action == null || ambiguousWorkTarget != null);

  String acknowledgement({String? savedSubject}) {
    if (recoveryConflict) {
      return spanish
          ? 'Has indicado que no tienes energía y que una pausa no encaja con ${_plannerActionForDisplay(action ?? objective, spanish: spanish)}'
          : 'You reported zero energy, and a break does not fit ${_plannerActionForDisplay(action ?? objective, spanish: spanish)}';
    }
    if (recovery) {
      return spanish
          ? 'Ahora necesitas recuperarte; el trabajo guardado puede esperar.'
          : 'Right now you need recovery; saved work does not have to become a work block.';
    }
    if (action != null) {
      return spanish
          ? 'Vamos a centrarnos en esto: ${_plannerActionForDisplay(action!, spanish: spanish)}'
          : 'Let’s focus on this: ${_plannerActionForDisplay(action!, spanish: spanish)}';
    }
    final correction = RegExp(
      r'\b(?:I meant|me refiero a|quer[ií]a decir)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(objective)?.group(1)?.trim();
    if (correction != null) {
      return spanish
          ? 'El objetivo corregido es: ${_sentence(correction)}'
          : 'The corrected target is: ${_sentence(correction)}';
    }
    if (savedSubject != null && objective.trim().isEmpty) {
      return spanish
          ? 'Quieres avanzar en $savedSubject, pero falta concretar el siguiente paso.'
          : 'You want to move $savedSubject forward, but the next action is not clear yet.';
    }
    if (objective.trim().isNotEmpty) {
      return spanish
          ? 'Has descrito esto: «${objective.trim()}».'
          : 'You described this: “${objective.trim()}”.';
    }
    return spanish
        ? 'Puedo ayudarte a elegir un paso que encaje con tu situación.'
        : 'I can help choose a step that fits your situation.';
  }

  String get question => recoveryConflict
      ? spanish
            ? '¿Hay una parte imprescindible que debas hacer ahora o alguien que pueda ayudarte?'
            : 'Is there an essential part that must happen now, or someone who can help?'
      : timeNeedsClarification
      ? spanish
            ? '¿Cuánto tiempo tienes disponible ahora, contando cualquier desplazamiento?'
            : 'How much time is available now, after allowing for any travel?'
      : ambiguousWorkTarget != null
      ? spanish
            ? '¿Qué parte de «$ambiguousWorkTarget» está bloqueada?'
            : 'Which part of ${ambiguousWorkTarget!.replaceAll(RegExp(r"\bmy\b", caseSensitive: false), "your")} is getting in the way?'
      : spanish
      ? '¿Qué necesitas hacer exactamente y qué parte te está bloqueando?'
      : 'What exactly do you need to do, and which part is getting in the way?';

  String reason(int? limit) {
    if (recovery) {
      return spanish
          ? 'La prioridad ahora es cuidar tu capacidad, sin añadir trabajo.'
          : 'Protecting your capacity comes before adding work.';
    }
    if (interruptible) {
      return caregiving
          ? spanish
                ? 'Puedes parar en cualquier momento para atender a quien depende de ti.'
                : 'This can pause whenever someone in your care needs you.'
          : spanish
          ? 'Puedes parar y retomar este paso cuando haya interrupciones.'
          : 'This step can pause and resume around interruptions.';
    }
    if (limit != null) {
      return spanish
          ? limit == 1
                ? 'Mantén este único paso dentro del minuto disponible.'
                : 'Mantén este único paso dentro de los $limit minutos disponibles.'
          : 'Keep this one step within your available ${_plannerMinutes(limit)}.';
    }
    return spanish
        ? 'Empieza por la acción que has indicado y deja lo opcional para después.'
        : 'Start with one concrete action and leave optional work for later.';
  }

  List<String> get appliedEvidence => [
    if (noteActions.contains(action) && !recovery)
      spanish
          ? 'Acción aplicada de la nota seleccionada: $action.'
          : 'Applied selected-note action: $action.',
    if (constraints.isNotEmpty)
      spanish
          ? 'Se comprobaron las acciones propuestas frente a ${constraints.length} restricciones explícitas de esta petición o su nota pertinente.'
          : 'Checked proposed actions against ${constraints.length} explicit exclusion(s) from this request or its relevant selected note.',
    if (deadlineNeedsDeparture)
      spanish
          ? 'Se indicó la hora límite de un compromiso; falta confirmar el tiempo disponible antes de salir.'
          : 'An event deadline was supplied; available working time before departure is unknown.',
  ];

  String? get usefulQuestion => deadlineNeedsDeparture
      ? spanish
            ? '¿A qué hora necesitas salir para llegar a tiempo?'
            : 'When do you need to leave to get there on time?'
      : null;

  List<PlannerOption> options(_EffortProfile effort) {
    final step = recovery
        ? spanish
              ? 'Haz una pausa donde puedas seguir atendiendo tus responsabilidades esenciales. Deja lo que no sea urgente para después.'
              : 'Take a pause where you can still attend to essential responsibilities. Leave nonurgent work for later.'
        : _concretePlannerStep(
            action!,
            spanish: spanish,
            constraints: constraints,
            availableContainer: availableContainer,
          );
    final noteSteps = noteActions
        .where((value) => value.toLowerCase() != action?.toLowerCase())
        .map(_sentence)
        .take(2)
        .toList(growable: false);
    final noIroning = constraints.any(
      (value) => RegExp(
        r'\b(?:iron|ironing|planchar|planchado)\b',
        caseSensitive: false,
      ).hasMatch(value),
    );
    final laundryAction = RegExp(
      r'\b(?:laundry|wash\w*|shirt\w*|cloth\w*|fold\w*|iron\w*|lavander[ií]a|lav\w*|camisa\w*|ropa|planch\w*)\b',
      caseSensitive: false,
    ).hasMatch('$action ${noteSteps.join(' ')}');
    final constraintText = noIroning && laundryAction && !recovery
        ? spanish
              ? ' Deja la plancha para otro momento.'
              : ' Leave ironing out of this step.'
        : '';
    final interruptionText = interruptible && !recovery
        ? spanish
              ? ' Para cuando necesiten tu atención; retoma solo cuando sea posible.'
              : ' Pause when you are needed; resume only when you can.'
        : '';
    final minStep = '$step$interruptionText$constraintText';
    final expanded = noteSteps.isEmpty || recovery || effort.bestFitMinutes <= 2
        ? minStep
        : '$minStep ${spanish ? 'Después, solo si queda tiempo:' : 'Then, only if time remains:'} ${noteSteps.join(' ')}';
    return [
      for (final kind in PlannerOptionKind.values)
        PlannerOption(
          kind: kind,
          title: recovery
              ? spanish
                    ? 'Recuperar energía'
                    : 'Make room for recovery'
              : SmartPlannerQueryController._condense(
                  _plannerActionForDisplay(
                    action!,
                    spanish: spanish,
                  ).replaceFirst(RegExp(r'\.$'), ''),
                  maxLength: 80,
                ),
          description: kind == PlannerOptionKind.minimum ? minStep : expanded,
          estimatedMinutes: kind == PlannerOptionKind.minimum
              ? effort.minimumMinutes
              : kind == PlannerOptionKind.bestFit
              ? effort.bestFitMinutes
              : effort.stretchMinutes,
          tradeoff: spanish
              ? 'Es un límite de tiempo propuesto, no una promesa de terminar. Para al alcanzar el límite.'
              : 'This is a proposed time ceiling, not a promise of completion. Stop at the limit.',
        ),
    ];
  }
}

String _plannerLanguage(String text) =>
    RegExp(
      r'\b(tengo|necesito|quiero|minutos|ay[uú]dame|hacer|puedo|ningun[oa]|ninguno|antes de|mi hija|mi hijo|descansar|recoger)\b|[¿¡]',
      caseSensitive: false,
    ).hasMatch(text)
    ? 'es'
    : 'en';

bool _plannerReferencesSelectedNote(String text) => RegExp(
  r'\b(?:selected|this|that)(?:\s+[a-záéíóúüñ-]+){0,3}\s+note\b'
  r'|\b(?:esta|esa)\s+nota\b|\bnota(?:\s+[a-záéíóúüñ-]+){0,2}\s+seleccionada\b',
  caseSensitive: false,
).hasMatch(text);

String _sentence(String text) {
  final clean = text.trim().replaceAll(RegExp(r'[.!?;]+$'), '');
  return clean.isEmpty ? '' : '${clean[0].toUpperCase()}${clean.substring(1)}.';
}

bool _negatedPlannerClause(String clause) => RegExp(
  r"(?<![a-záéíóúüñ])(?:not|never|cannot|can['’]t|don['’]t|do not|no|nunca|sin|ni|evita|avoid)(?![a-záéíóúüñ])",
  caseSensitive: false,
).hasMatch(clause);

List<String> _plannerExclusions(String text) => text
    .split(RegExp(r'[.!?;,\n]+|\bbut\b|\bpero\b', caseSensitive: false))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty && _negatedPlannerClause(value))
    .where(
      (value) => !RegExp(
        r'\b(no|zero) energy\b|sin energ[ií]a',
        caseSensitive: false,
      ).hasMatch(value),
    )
    .take(6)
    .toList(growable: false);

bool _actionContradicts(String action, List<String> constraints) {
  for (final constraint in constraints) {
    final negation = RegExp(
      r"\b(?:do not|don['’]t|cannot|can['’]t|avoid|not|no|never|nunca|sin|evita)\s+",
      caseSensitive: false,
    ).firstMatch(constraint);
    if (negation == null) {
      continue;
    }
    final prohibited = constraint
        .substring(negation.end)
        .replaceFirst(
          RegExp(r'^(?:puedo|puedes|debemos|debo)\s+', caseSensitive: false),
          '',
        );
    // Coordinated prohibitions inherit the negation, but retain their own
    // objects: leaving a child does not forbid leaving other receipts for later.
    for (final phrase in prohibited.split(
      RegExp(r'\s+(?:or|and|ni|o|y)\s+', caseSensitive: false),
    )) {
      final words = RegExp(r'[a-záéíóúñ]+').allMatches(phrase.toLowerCase());
      if (words.isEmpty) {
        continue;
      }
      final verb = _plannerVerbRoot(words.first.group(0)!);
      if (!_plannerKnownVerb(verb)) {
        continue;
      }
      final objects = _plannerObjectTerms(phrase.substring(words.first.end));
      for (final proposed in action.split(RegExp(r'[.!?;\n]+'))) {
        final proposedWords = RegExp(
          r'[a-záéíóúñ]+',
        ).allMatches(proposed.toLowerCase());
        final usesVerb = proposedWords.any(
          (word) =>
              _plannerVerbRoot(word.group(0)!) == verb &&
              !_negatedPlannerClause(proposed.substring(0, word.start)),
        );
        if (usesVerb &&
            (objects.isEmpty ||
                objects
                    .intersection(_plannerObjectTerms(proposed))
                    .isNotEmpty)) {
          return true;
        }
      }
    }
  }
  return false;
}

const _plannerProhibitionVerbs = {
  'leave',
  'silence',
  'work',
  'iron',
  'send',
  'write',
  'open',
  'clean',
  'wash',
  'pack',
  'sort',
  'call',
  'read',
  'check',
  'plan',
  'dejar',
  'silenciar',
  'trabajar',
  'planchar',
  'enviar',
  'escribir',
  'abrir',
  'limpiar',
  'lavar',
  'guardar',
  'ordenar',
  'llamar',
  'leer',
  'revisar',
};

bool _plannerKnownVerb(String word) =>
    _plannerProhibitionVerbs.contains(word) ||
    RegExp('^(?:$_plannerActionVerbs)\$', caseSensitive: false).hasMatch(word);

String _plannerVerbRoot(String word) => switch (word) {
  'leaving' || 'leaves' || 'left' => 'leave',
  'silencing' || 'silenced' => 'silence',
  'working' || 'worked' => 'work',
  'ironing' || 'ironed' => 'iron',
  'writing' || 'written' => 'write',
  'sending' || 'sent' => 'send',
  'opening' || 'opened' => 'open',
  'cleaning' || 'cleaned' => 'clean',
  'washing' || 'washed' => 'wash',
  'packing' || 'packed' => 'pack',
  'sorting' || 'sorted' => 'sort',
  'planning' || 'planned' => 'plan',
  'deja' || 'dejes' || 'dejando' => 'dejar',
  'silencia' || 'silencies' => 'silenciar',
  'trabaja' || 'trabajes' || 'trabajo' => 'trabajar',
  'plancha' || 'planches' => 'planchar',
  'envía' || 'envíes' => 'enviar',
  'escribe' || 'escribas' => 'escribir',
  'abre' || 'abras' => 'abrir',
  'limpia' || 'limpies' => 'limpiar',
  'lava' || 'laves' => 'lavar',
  'guarda' || 'guardes' => 'guardar',
  'ordena' || 'ordeno' || 'ordenes' => 'ordenar',
  'revisa' || 'reviso' || 'revises' => 'revisar',
  _ => _plannerRegularVerbRoot(word),
};

String _plannerRegularVerbRoot(String word) {
  for (final suffix in ['ing', 'ed', 's']) {
    if (word.length > suffix.length + 2 && word.endsWith(suffix)) {
      final stem = word.substring(0, word.length - suffix.length);
      if (_plannerKnownVerb(stem)) {
        return stem;
      }
      if (_plannerKnownVerb('${stem}e')) {
        return '${stem}e';
      }
    }
  }
  return word;
}

Set<String> _plannerObjectTerms(String text) => _plannerTopicTerms(text)
    .map(
      (term) => switch (term) {
        'toddler' ||
        'baby' ||
        'children' ||
        'hijo' ||
        'hija' ||
        'niño' ||
        'niña' => 'child',
        _ =>
          term.length > 4 && term.endsWith('s')
              ? term.substring(0, term.length - 1)
              : term,
      },
    )
    .toSet();

// Procedural words can occur in almost any saved description. They cannot
// establish that the user chose that task, note, goal, or rhythm.
Set<String> _plannerTopicTerms(String text) => _plannerTerms(text)
    .where(
      (term) =>
          !RegExp(
            '^(?:$_plannerActionVerbs)\$',
            caseSensitive: false,
          ).hasMatch(term) &&
          !_plannerProhibitionVerbs.contains(_plannerVerbRoot(term)) &&
          !const {
            'stop',
            'resume',
            'first',
            'next',
            'later',
            'now',
            'minute',
            'minutes',
            'time',
            'step',
            'one',
            'two',
            'five',
            'ten',
            'twenty',
            'for',
            'and',
            'but',
            'not',
            'any',
            'the',
            'our',
            'your',
            'its',
            'can',
            'cannot',
            'alone',
            'immediately',
            'please',
            'right',
            'per',
            'day',
            'daily',
            'once',
            'enough',
            'gentle',
            'synthetic',
            'journey',
            'validation',
            // A shared day or generic work context does not identify a task.
            'work',
            'today',
            'tomorrow',
            'monday',
            'tuesday',
            'wednesday',
            'thursday',
            'friday',
            'saturday',
            'sunday',
            'trabajo',
            'hoy',
            'mañana',
            'lunes',
            'martes',
            'miércoles',
            'jueves',
            'viernes',
            'sábado',
            'domingo',
            'minuto',
            'paso',
            'primero',
            'luego',
            'ahora',
            'con',
            'sin',
            'una',
            'uno',
            'los',
            'las',
            'del',
            'mis',
            'sus',
            'por',
            'favor',
            'puedo',
            'debo',
            'parar',
            'retomar',
          }.contains(term),
    )
    .toSet();

Iterable<String> _plannerAffirmativeClauses(String text) => text
    .split(RegExp(r'[.!?;,\n]+|\bbut\b|\bpero\b', caseSensitive: false))
    .where((clause) => !_negatedPlannerClause(clause));

String _plannerWithoutQuotedText(String text) => text.replaceAll(
  RegExp(r'''"[^"]*"|“[^”]*”|‘[^’]*’|(?<!\w)'[^']*'(?!\w)'''),
  '',
);

bool _plannerHistoricalOrUncertain(String text) => RegExp(
  r'\b(?:yesterday|earlier|used to|last time|previously|said|quoted|quote|hypothetical|maybe|perhaps|might|if|not sure|unsure|ayer|antes dije|dije|quiz[aá]s|tal vez|no s[eé]|si pudiera)\b',
  caseSensitive: false,
).hasMatch(text);

bool? _plannerRecoveryPreference(String text) {
  bool? preference;
  for (final clause in text.split(
    RegExp(r'[.!?;,\n]+|\bbut\b|\bpero\b', caseSensitive: false),
  )) {
    final current = _plannerWithoutQuotedText(clause);
    if (_plannerHistoricalOrUncertain(current)) {
      continue;
    }
    if (RegExp(
      r"\b(?:do not|don['’]t|not|no longer|never|no)\b.{0,25}\b(?:need|want|suggest|rest|break|pause|necesito|quiero|sugieras|descansar|descanso|pausa)\b.{0,20}\b(?:rest|break|pause|recovery|descansar|descanso|pausa)\b|\b(?:do not rest|don['’]t rest|no rest|no break|sin descanso|sin pausa|no descanses)\b",
      caseSensitive: false,
    ).hasMatch(current)) {
      preference = false;
      continue;
    }
    if (_negatedPlannerClause(clause) &&
        !RegExp(
          r'\b(no|zero) energy\b|sin energ[ií]a',
          caseSensitive: false,
        ).hasMatch(clause)) {
      continue;
    }
    if (RegExp(
      r'\b(?:need|want|help me|give me|prioriti[sz]e|choose|protect|make room for)\b.{0,35}\b(?:rest|recover|recovery|break|sleep)\b|\b(?:zero|no) energy\b|\b(?:my|our) energy (?:is|has reached) (?:zero|0)\b|\b(?:necesito|quiero|dame|ay[uú]dame a)\b.{0,35}\b(?:descansar|descanso|pausa|recuperarme)\b|sin energ[ií]a|\bmi energ[ií]a (?:es|est[aá] en|est[aá] a) (?:cero|0)\b',
      caseSensitive: false,
    ).hasMatch(current)) {
      preference = true;
    }
  }
  return preference;
}

bool _explicitRecoveryRequest(String text) =>
    _plannerRecoveryPreference(text) == true;

bool _declinesPlannerRecovery(String text) =>
    _plannerRecoveryPreference(text) == false;

const _plannerActionVerbs =
    r'draft|redactar|redacta|record|fill|preparing|reviewing|writing|working on|work(?: solo| alone)? on|pack|gather|fold|sort|send|write|reply|email|call|tell|review|read|check|wash|prepare|finish|complete|pay|open|put|list|compare|book|schedule|clean|cook|start|practise|practice|walk|drink|collect|organize|organise|look at|guarda|guardar|preparar|prepara|recoger|recoge|doblar|dobla|ordenar|ordena|ordeno|enviar|env[ií]a|escribir|escribe|revisar|revisa|reviso|leer|lee|llamar|llama|lavar|lava|terminar|termina|hacer|limpiar|limpia|abrir|abre';

bool _plannerHasActionPosition(String prefix) {
  final clean = prefix.trim();
  if (clean.isEmpty || RegExp(r'^[-*\d):\s]+$').hasMatch(clean)) {
    return true;
  }
  // An action needs an imperative, an explicit request, or a present-tense
  // subject. "a clean tote" and "the care-label check" are noun phrases.
  return RegExp(
    r"\b(?:please|help me|can you|could you|would you|(?:i|we)\s+(?:(?:need|want|have|am trying|are trying) to|must|should|can)|i am|we are|i['’]m|we['’]re|need to|want to|have to|must|i|we|first|next|then|now|necesito|quiero|debo|puedo|yo|ay[uú]dame a|por favor|primero|ahora|mientras)\s*$"
    r'|\b(?:minutes?|mins?|hours?|step|task|session|plan)\s+(?:available\s+)?to\s*$'
    r'|\b(?:i|we)\s+(?:only\s+)?have\s+\S+(?:\s+\S+)?\s+(?:minutes?|mins?|hours?)\s+(?:after|before)\s+(?:(?:my|our|the)\s+)?(?:breakfast|lunch|dinner|work|school|school pickup|school run|meeting|appointment)\s+to\s*$'
    r'|\btengo\s+\S+(?:\s+\S+)?\s+(?:minutos?|horas?)\s+(?:despu[eé]s de|antes de)\s+(?:(?:mi|el|la)\s+)?(?:desayunar|almorzar|cenar|desayuno|almuerzo|cena|trabajo|escuela|reuni[oó]n|cita)\s+para\s*$'
    r'|\b(?:minutos?|horas?|paso)\s+(?:disponibles?\s+)?para\s*$',
    caseSensitive: false,
  ).hasMatch(clean);
}

List<String> _plannerActionCandidates(String source) {
  final candidates = <String>[];
  for (final clause in source.split(
    RegExp(
      r'[.!?;,\n]+|\b(?:and then|then|but|pero|despu[eé]s(?!\s+de\b))\b|\band\s+(?=(?:(?:I|we)\s+)?(?:need|must|have to|want to)\b)',
      caseSensitive: false,
    ),
  )) {
    final matches = RegExp(
      '\\b($_plannerActionVerbs)\\s+([^.!?;]+)',
      caseSensitive: false,
    ).allMatches(clause);
    if (matches.isEmpty) {
      continue;
    }
    final match = matches.first;
    final prefix = clause.substring(0, match.start);
    if (!_plannerHasActionPosition(prefix) ||
        _negatedPlannerClause(prefix) ||
        RegExp(
          r"\b(already|finished|completed|done|used to|yesterday|ya|termin[eé]|hice)\b|\b(?:can|could) wait\b",
          caseSensitive: false,
        ).hasMatch(clause)) {
      continue;
    }
    var action = match.group(0)!.trim();
    if (RegExp(
      r'^list\s+(?:unchanged|alone|as it is)\b',
      caseSensitive: false,
    ).hasMatch(action)) {
      continue;
    }

    if (RegExp(
      r'^start\s+(?:(?:my|the|a|our)\s+)?(?:restaurant\s+)?(?:shift|meeting|appointment)\b',
      caseSensitive: false,
    ).hasMatch(action)) {
      continue;
    }

    action = action
        .split(
          RegExp(
            r'\s+and\s+(?:(?:I |i |my |the )|(?:start|send|write|pack|cook|fold)\b)|\s+y\s+(?:despu[eé]s|necesito)\b',
            caseSensitive: false,
          ),
        )
        .first;
    action = action.replaceFirst(
      RegExp(
        r'\s+(?:and\s+(?:(?:I|we)\s+)?(?:only\s+)?have|y\s+(?:solo\s+)?tengo)\s+(?:only\s+|solo\s+)?(?:\d+|one|two|three|four|five|ten|fifteen|twenty|thirty|un|uno|dos|tres|cuatro|cinco|diez|quince|veinte|treinta)\s+(?:minutes?|mins?|hours?|minutos?|horas?)\b.*$',
        caseSensitive: false,
      ),
      '',
    );
    action = action.replaceFirst(
      RegExp(
        r'\s+(?:for|within|in)\s+(?:\d+|one|two|three|five|ten|twenty)\s+minutes?.*$',
        caseSensitive: false,
      ),
      '',
    );
    if (RegExp(
      r'^(?:make|prepare|hacer)\s+(?:it|that|this|the plan|el plan)\b',
      caseSensitive: false,
    ).hasMatch(action)) {
      continue;
    }
    if (RegExp(r'^(?:give|tell) me\b', caseSensitive: false).hasMatch(action)) {
      continue;
    }
    if (_plannerReferencesSelectedNote(action) ||
        RegExp(
          r'\bsaved (?:task|goal)\b',
          caseSensitive: false,
        ).hasMatch(action)) {
      continue;
    }
    // Pronouns and ordering adverbs do not identify a new action object.
    if (RegExp(
      '^($_plannerActionVerbs)\\s+(?:it|that|this|something|anything|eso|algo|first|next|now|later|primero|ahora)(?:\\s+and\\b.*)?\\W*\$',
      caseSensitive: false,
    ).hasMatch(action)) {
      continue;
    }
    if (action.length > 5) {
      candidates.add(action);
    }
  }
  return candidates;
}

String? _extractPlannerAction(String source) {
  final candidates = _plannerActionCandidates(source);
  final deferredTerms = <String>{};
  final priorityTerms = <String>{};
  for (final clause in source.split(RegExp(r'[.!?;\n]+'))) {
    final deferred = RegExp(
      r'(.+?)\s+(?:can wait|can be deferred|is optional|puede esperar)\b',
      caseSensitive: false,
    ).firstMatch(clause);
    if (deferred != null) {
      deferredTerms.addAll(_plannerTerms(deferred.group(1)!));
    }
    final priority = RegExp(
      r'(.+?)\s+(?:takes priority|comes first|is (?:the )?priority|is urgent|va primero)\b',
      caseSensitive: false,
    ).firstMatch(clause);
    if (priority != null) {
      priorityTerms.addAll(_plannerTerms(priority.group(1)!));
    }
  }
  final available = candidates
      .where(
        (action) => _plannerTerms(action).intersection(deferredTerms).isEmpty,
      )
      .toList();
  if (available.isNotEmpty) {
    int score(String action) =>
        _plannerTerms(action).intersection(priorityTerms).length * 3 +
        (RegExp(
              r'\b(overdue|urgent|vencido|urgente)\b',
              caseSensitive: false,
            ).hasMatch(action)
            ? 1
            : 0);
    var chosen = available.first;
    for (final action in available.skip(1)) {
      if (score(action) > score(chosen)) {
        chosen = action;
      }
    }
    return chosen;
  }
  if (candidates.isNotEmpty) {
    return null;
  }
  for (final clause in _plannerWithoutQuotedText(
    source,
  ).split(RegExp(r'[.!?;,\n]+'))) {
    if (_negatedPlannerClause(clause)) {
      continue;
    }
    final checklist = RegExp(
      r'\b(?:the|my|a)?\s*((?:[a-z]+\s+){0,3}checklist)\b',
      caseSensitive: false,
    ).firstMatch(clause)?.group(1);
    if (checklist != null) {
      final name = checklist
          .replaceFirst(
            RegExp(r'^(?:on |the |my |plan |focus )+', caseSensitive: false),
            '',
          )
          .trim();
      return 'Review $name and identify one unfinished item';
    }
  }
  return null;
}

String? _savedPlannerAction(String title) {
  final action = _extractPlannerAction(title);
  if (action != null) {
    return action;
  }
  if (RegExp(r'\bwalk\b', caseSensitive: false).hasMatch(title)) {
    return 'Prepare for one session of "$title" if it is still needed';
  }
  return null;
}

String _concretePlannerStep(
  String action, {
  required bool spanish,
  List<String> constraints = const [],
  String? availableContainer,
}) {
  final lower = action.toLowerCase();
  if (RegExp(
    r'\b(?:pack|preparar|prepara|guardar|guarda)\b.*\b(?:uniform|uniforme)\b',
  ).hasMatch(lower)) {
    final badge = RegExp(r'\b(?:badge|identificaci[oó]n)\b').hasMatch(lower);
    if (availableContainer != null) {
      return spanish
          ? 'Reúne las prendas de tu uniforme${badge ? ' y tu identificación' : ''} y guárdalas en $availableContainer. Deja lo opcional para después.'
          : 'Gather the pieces of your uniform${badge ? ' and your name badge' : ''} and pack them in the $availableContainer. Leave optional jobs for later.';
    }
    return spanish
        ? 'Guarda las prendas de tu uniforme${badge ? ' y tu identificación' : ''} juntas para llevarlas. Deja lo opcional para después.'
        : 'Gather the pieces of your uniform${badge ? ' and your name badge' : ''} and pack them together. Leave optional jobs for later.';
  }
  if (RegExp(
    r'\b(?:work on|working on|sort|ordenar|ordena|ordeno)\b.*\b(?:receipts?|recibos?)\b',
  ).hasMatch(lower)) {
    return spanish
        ? 'Pon un solo recibo delante de ti y trabaja únicamente con ese. Deja los demás para después.'
        : 'Put one receipt in front of you and work on just that one. Leave the others for later.';
  }
  if (RegExp(
    r'\b(?:draft|send|reply|email|write|redactar|redacta)\b.*\b(?:email|message|reply|correo)\b',
  ).hasMatch(lower)) {
    final draftOnly = constraints.any(
      (value) => RegExp(
        r'\b(send|sending|enviar|env[ií]es)\b',
        caseSensitive: false,
      ).hasMatch(value),
    );
    if (draftOnly ||
        RegExp(r'\bdraft\b', caseSensitive: false).hasMatch(action)) {
      return spanish
          ? 'Abre el correo y escribe el borrador. Déjalo guardado para revisarlo.'
          : 'Open the email and write the draft. Keep it as a draft for review.';
    }
    return spanish
        ? 'Abre el mensaje y escribe la actualización o respuesta que necesitas enviar. Revísala antes de enviarla.'
        : 'Open the email and write the update or reply you need to send. Check it before sending.';
  }
  if (RegExp(
    r'\b(?:tell|email|message)\b.*\b(?:manager|boss)\b.*\blate\b',
  ).hasMatch(lower)) {
    return spanish
        ? 'Escribe a tu responsable que llegarás tarde. Indica la hora solo si la sabes; si no, di cuándo podrás confirmarla.'
        : 'Message your manager that you will be late. Include an arrival time only if you know it; otherwise say when you can update them.';
  }
  var imperative = action
      .replaceFirst(RegExp(r'^preparing\b', caseSensitive: false), 'Prepare')
      .replaceFirst(RegExp(r'^writing\b', caseSensitive: false), 'Write')
      .replaceFirst(RegExp(r'^reviewing\b', caseSensitive: false), 'Review')
      .replaceAll(RegExp(r'\bmy\b', caseSensitive: false), 'your')
      .replaceAll(RegExp(r'\bour\b', caseSensitive: false), 'your');
  if (spanish) {
    const verbs = {
      'guardar': 'Guarda',
      'preparar': 'Prepara',
      'recoger': 'Recoge',
      'doblar': 'Dobla',
      'ordenar': 'Ordena',
      'enviar': 'Envía',
      'escribir': 'Escribe',
      'revisar': 'Revisa',
      'leer': 'Lee',
      'llamar': 'Llama',
      'lavar': 'Lava',
      'terminar': 'Termina',
      'hacer': 'Haz',
    };
    imperative = imperative.replaceFirstMapped(
      RegExp('^(${verbs.keys.join('|')})\\b', caseSensitive: false),
      (match) => verbs[match.group(0)!.toLowerCase()]!,
    );
    imperative = imperative.replaceAll(
      RegExp(r'\bmi\b', caseSensitive: false),
      'tu',
    );
  }
  return _sentence(imperative);
}

String? _plannerAvailableContainer(String source) {
  String? available;
  for (final clause in source.split(RegExp(r'[.!?;,\n]+'))) {
    final current = _plannerWithoutQuotedText(clause);
    if (_plannerHistoricalOrUncertain(current)) {
      continue;
    }
    if (_negatedPlannerClause(current) &&
        RegExp(
          r'\b(?:bag|tote|bolsa|mochila)\b',
          caseSensitive: false,
        ).hasMatch(current)) {
      available = null;
      continue;
    }
    final match = RegExp(
      r'\b(?:i have|we have)\s+(?:a|an|another|my)\s+((?:(?:clean|open|spare|empty|canvas)\s+){0,2}(?:tote(?: bag)?|bag|backpack))\b'
      r'|\b(?:tengo|tenemos)\s+((?:una|otra|mi)\s+(?:bolsa(?: de tela)?|mochila)(?:\s+(?:limpia|abierta|vac[ií]a))?)\b',
      caseSensitive: false,
    ).firstMatch(current);
    if (match != null) {
      available = match.group(1) ?? match.group(2);
    }
  }
  return available;
}

String _plannerActionForDisplay(String action, {required bool spanish}) =>
    _sentence(
      action
          .replaceAll(
            RegExp(spanish ? r'\bmi\b' : r'\bmy\b', caseSensitive: false),
            spanish ? 'tu' : 'your',
          )
          .replaceAll(RegExp(r'\bour\b', caseSensitive: false), 'your'),
    );

bool _plannerDepartureUnresolved(String source) {
  bool departureConfirmed = false;
  for (final clause in _plannerWithoutQuotedText(
    source,
  ).split(RegExp(r'[.!?;,\n]+'))) {
    final current = _plannerWithoutQuotedText(clause);
    final workBeforeLeaving = RegExp(
      r'\b(?:i|we)\s+have\s+(?:\d+|one|two|three|five|ten|fifteen|twenty|thirty)\s+minutes?\s+(?:before|until)\s+(?:(?:i|we)\s+)?(?:leaving|leave|departing)\b',
      caseSensitive: false,
    ).hasMatch(current);
    if (workBeforeLeaving) {
      departureConfirmed =
          !_plannerHistoricalOrUncertain(current) &&
          !_negatedPlannerClause(current);
      continue;
    }

    final departure = RegExp(
      r"\b(?:(?:i|we)\s+(?:leave|depart|am leaving|are leaving|need to leave|have to leave|(?:might|may|could|would|cannot|can['’]t|do not|will|won['’]t) leave)|salgo|salimos|(?:tengo|tenemos) que salir|voy a salir|(?:quiz[aá]s|tal vez) salga)\b",
      caseSensitive: false,
    ).firstMatch(current);
    if (departure == null) {
      continue;
    }
    if (_plannerHistoricalOrUncertain(current) ||
        _negatedPlannerClause(current) ||
        RegExp(
          r"\b(?:may|could|would|won['’]t)\b",
          caseSensitive: false,
        ).hasMatch(current)) {
      // A newer uncertainty cannot be satisfied by an earlier departure fact.
      departureConfirmed = false;
      continue;
    }
    departureConfirmed = RegExp(
      r'^\s+(?:in|en)\s+(?:\d+|one|two|three|five|ten|fifteen|twenty|thirty|un|uno|dos|tres|cinco|diez|quince|veinte|treinta)\s+(?:minutes?|minutos?)\b',
      caseSensitive: false,
    ).hasMatch(current.substring(departure.end));
  }
  final travelConfirmed =
      RegExp(
        r'\b(?:travel|commut(?:e|ing)|journey|driv(?:e|ing)|desplazamiento|trayecto)\b.{0,30}\b(?:already accounted for|already allowed for|included|accounted for|incluido)\b|\b(?:including|after allowing for|after setting aside)\s+(?:the )?(?:travel|commute|driving)\b',
        caseSensitive: false,
      ).hasMatch(source) &&
      !RegExp(
        r"\b(?:not|no|isn[’']t)\s+(?:yet\s+)?(?:included|accounted for|incluido)\b",
        caseSensitive: false,
      ).hasMatch(source);
  if (travelConfirmed || departureConfirmed) {
    return false;
  }
  return RegExp(
        '\\b(?:before|until|antes de)\\b(?:(?!\\b(?:to|para)\\s+(?:$_plannerActionVerbs)\\b)[^.!?;\\n]){0,45}\\b(?:school|pick(?:up|[- ]up)(?!\\s+list)|shift|appointment|meeting|ride|bus|train|turno|cita|recoger|autobús|tren)\\b',
        caseSensitive: false,
      ).hasMatch(source) ||
      RegExp(
        r'\b(shift|appointment|school|pick(?:up|[- ]up)(?!\s+list)|meeting|ride|bus|train|departure|turno|cita|recoger|autobús|tren)\b[^.!?;\n]{0,70}\b(?:in|en)\s+(?:\d+|one|two|three|five|ten|fifteen|twenty|thirty|uno|dos|tres|cinco|diez|quince|veinte|treinta)\s+(?:minutes?|minutos?)\b',
        caseSensitive: false,
      ).hasMatch(source);
}

bool _rejectsPlannerTimeBudget(String input) => RegExp(
  r"\b(?:(?:i|we)\s+(?:do not|don['’]t|no longer|cannot|can['’]t)\s+have|no\s+(?:tengo|tenemos))\b[^.!?;]{0,35}\b(?:minutes?|minutos?|hours?|horas?)\b",
  caseSensitive: false,
).hasMatch(input);

String _plannerEmotionText(EmotionalState emotion, {required bool isSpanish}) =>
    !isSpanish
    ? emotion.name
    : switch (emotion) {
        EmotionalState.fatigued => 'cansancio',
        EmotionalState.anxious => 'ansiedad',
        EmotionalState.scattered => 'dispersión',
        EmotionalState.negative => 'negativo',
        EmotionalState.energized => 'con energía',
        EmotionalState.engaged => 'implicación',
        EmotionalState.calm => 'calma',
        EmotionalState.positive => 'positivo',
        EmotionalState.neutral => 'neutral',
      };
