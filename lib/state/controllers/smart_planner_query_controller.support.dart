part of 'smart_planner_query_controller.dart';

String _plannerMinutes(int minutes) =>
    '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';

final class _PlannerConversationContext {
  const _PlannerConversationContext({
    required this.input,
    required this.searchText,
    required this.evidenceSearchText,
    required this.savedContextDeclined,
    required this.answeredSavedContextQuestion,
    required this.continuesPriorSubject,
    required this.subject,
    required this.priorSubject,
    required this.priorTimeLimitMinutes,
    required this.historyTurnsUsed,
    required this.isFollowUp,
    required this.corrections,
  });

  factory _PlannerConversationContext.resolve({
    required String input,
    required List<Map<String, String>> history,
    String? reflection,
    required bool isFollowUp,
    PlannerUserContext? currentUserContext,
    bool respondingToPlanQuestion = false,
  }) {
    final String normalizedInput = input.trim() == _defaultPlanningPrompt
        ? ''
        : input.trim();
    bool awaitingSavedChoice = false;
    bool savedContextDeclined =
        currentUserContext?.savedContextDeclined ?? false;
    final priorUserTurns = <String>[
      if (currentUserContext != null) currentUserContext.objective,
      ...?currentUserContext?.corrections,
    ];
    final normalizedReflection = reflection?.trim() ?? '';
    if (currentUserContext == null &&
        normalizedReflection.isNotEmpty &&
        normalizedReflection != _defaultPlanningPrompt) {
      priorUserTurns.add(normalizedReflection);
    }
    for (final turn in history) {
      final content = turn['content']?.trim() ?? '';
      if (turn['role'] == 'assistant') {
        awaitingSavedChoice =
            content.contains(_savedContextQuestion) ||
            content.contains(_savedContextQuestionEs);
      } else if (currentUserContext == null &&
          turn['role'] == 'user' &&
          content.isNotEmpty &&
          content != _defaultPlanningPrompt) {
        if (_declinesSavedChoice(content)) {
          savedContextDeclined = true;
        }
        if (_optsIntoSavedContext(content)) {
          savedContextDeclined = false;
        }
        if (!priorUserTurns.contains(content)) {
          priorUserTurns.add(content);
        }
        awaitingSavedChoice = false;
      }
    }
    final declinesCurrentChoice =
        isFollowUp && _declinesSavedChoice(normalizedInput);
    savedContextDeclined = savedContextDeclined || declinesCurrentChoice;
    final declineOnly =
        declinesCurrentChoice && _extractPlannerAction(normalizedInput) == null;
    if (_optsIntoSavedContext(normalizedInput)) {
      savedContextDeclined = false;
    }
    // Keep complete semantic turns. Display truncation must never discard an
    // objective or exclusion. The envelope/UI already bound input lengths.
    final boundedPrior = currentUserContext == null && priorUserTurns.length > 8
        ? priorUserTurns.sublist(priorUserTurns.length - 8)
        : priorUserTurns;
    // Typed state is already classified user input. Replaying its corrections
    // as new turns could replace the objective with a non-pronoun obstacle.
    String priorSubject = currentUserContext?.objective ?? '';
    final retainedConstraints = <String>[...?currentUserContext?.corrections];
    int? priorTimeLimitMinutes = currentUserContext?.timeLimitMinutes;
    if (currentUserContext == null) {
      for (final turn in boundedPrior) {
        if (_declinesSavedChoice(turn) && _extractPlannerAction(turn) == null) {
          continue;
        }
        if (priorSubject.isEmpty || !_continuesPlannerObjective(turn)) {
          priorSubject = turn;
          retainedConstraints.clear();
          priorTimeLimitMinutes = _explicitPlanningTimeLimit(turn);
        } else {
          retainedConstraints.add(turn);
          priorTimeLimitMinutes =
              _explicitPlanningTimeLimit(turn) ?? priorTimeLimitMinutes;
        }
      }
    }
    final continuesPriorSubject =
        isFollowUp &&
        priorSubject.isNotEmpty &&
        (declineOnly ||
            _continuesPlannerObjective(normalizedInput) ||
            respondingToPlanQuestion &&
                _extractPlannerAction(normalizedInput) == null &&
                !RegExp(
                  r'\b(?:I meant|me refiero a|quer[ií]a decir)\b',
                  caseSensitive: false,
                ).hasMatch(normalizedInput));
    final subject = continuesPriorSubject ? priorSubject : normalizedInput;

    return _PlannerConversationContext(
      input: normalizedInput,
      searchText: <String>[
        ...boundedPrior,
        normalizedInput,
      ].where((String value) => value.isNotEmpty).join(' '),
      evidenceSearchText: <String>[
        if (continuesPriorSubject) ...[priorSubject, ...retainedConstraints],
        if (!declineOnly) normalizedInput,
      ].where((value) => value.isNotEmpty).join('. '),
      savedContextDeclined: savedContextDeclined,
      answeredSavedContextQuestion:
          isFollowUp && awaitingSavedChoice && normalizedInput.isNotEmpty,
      continuesPriorSubject: continuesPriorSubject,
      subject: subject,
      priorSubject: priorSubject,
      priorTimeLimitMinutes: priorTimeLimitMinutes,
      historyTurnsUsed: boundedPrior.length,
      isFollowUp: isFollowUp,
      corrections: continuesPriorSubject
          ? [
              ...retainedConstraints,
              if (!declineOnly && normalizedInput.isNotEmpty) normalizedInput,
            ]
          : const [],
    );
  }

  final String input;
  final String searchText;
  final String evidenceSearchText;
  final bool savedContextDeclined;
  final bool answeredSavedContextQuestion;
  final bool continuesPriorSubject;
  final String subject;
  final String priorSubject;
  final int? priorTimeLimitMinutes;
  final int historyTurnsUsed;
  final bool isFollowUp;
  final List<String> corrections;

  PlannerUserContext get userContext => PlannerUserContext(
    objective: subject,
    corrections: corrections,
    savedContextDeclined: savedContextDeclined,
    timeLimitMinutes: explicitTimeLimitMinutes,
  );

  // A concrete new request starts a new time budget. A referential follow-up
  // can retain its subject's budget, but an explicit current limit wins.
  int? get explicitTimeLimitMinutes =>
      _rejectsPlannerTimeBudget(input) &&
          _explicitPlanningTimeLimit(input) == null
      ? null
      : _explicitPlanningTimeLimit(input) ??
            (continuesPriorSubject ? priorTimeLimitMinutes : null);

  String evidenceSummary({
    required bool contextWasProvided,
    String languageCode = 'en',
  }) {
    if (historyTurnsUsed > 0) {
      return _plannerEvidenceText(
        languageCode,
        'Used $historyTurnsUsed prior user conversation turn(s) for this response only; Planner did not save them.',
        'Se usaron $historyTurnsUsed mensajes anteriores tuyos únicamente para esta respuesta; el Planificador no los guardó.',
      );
    }
    return contextWasProvided
        ? _plannerEvidenceText(
            languageCode,
            'Planning context was supplied for this check-in; it was not saved as a reflection or memory.',
            'Aportaste contexto de planificación para este registro; no se guardó como reflexión ni como memoria.',
          )
        : _plannerEvidenceText(
            languageCode,
            'No planning context or prior user turn was supplied.',
            'No se aportó contexto de planificación ni un mensaje anterior del usuario.',
          );
  }
}

const String _savedContextQuestion =
    'Which saved task or goal, if any, should this plan support?';

const String _savedContextQuestionEs =
    '¿Qué tarea u objetivo guardado, si lo hay, debe apoyar este plan?';

bool _optsIntoSavedContext(String input) =>
    RegExp(
      r'\b(?:use|choose|attach|usar|usa|elige)\b.{0,30}\b(?:saved (?:task|goal)|saved planning recommendation|tarea guardada|objetivo guardado)\b',
      caseSensitive: false,
    ).hasMatch(input) &&
    !_negatedPlannerClause(input);

bool _continuesPlannerObjective(String input) {
  // A named new action wins over a loose pronoun such as "this evening".
  if (_extractPlannerAction(input) != null ||
      RegExp(
        r'\b(?:I meant|me refiero a|quer[ií]a decir)\b',
        caseSensitive: false,
      ).hasMatch(input)) {
    return false;
  }
  return _declinesSavedChoice(input) ||
      _explicitPlanningTimeLimit(input) != null ||
      _negatedPlannerClause(input) ||
      RegExp(
        r'\b(it|that|those|these|earlier|previous|smaller|shorter|instead|tomorrow|interruptions|interrupciones|eso|anterior|menos|mañana)\b|^why\b|^por qu[eé]\b|^can you make\b|^make this\b|^this (?:one|plan)\b',
        caseSensitive: false,
      ).hasMatch(input);
}

int? _explicitPlanningTimeLimit(String input) {
  if (_plannerDepartureUnresolved(input)) {
    return null;
  }
  // Recognize explicit numeric work windows, not arbitrary numbers in titles
  // or durations reported as past activity. This does not infer capacity.
  const numbers = <String, int>{
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'fifteen': 15,
    'twenty': 20,
    'thirty': 30,
    'sixty': 60,
    'uno': 1,
    'un': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'diez': 10,
    'quince': 15,
    'veinte': 20,
    'treinta': 30,
  };
  final normalized = input.replaceAllMapped(
    RegExp('\\b(${numbers.keys.join('|')})\\b', caseSensitive: false),
    (match) => '${numbers[match.group(0)!.toLowerCase()]}',
  );
  final windowPattern = RegExp(
    r"\b(?:within|for|only|(?:i|we|and)\s+(?:only\s+)?have(?:\s+only)?|at most|no more than|(?:today(?:'s)?\s+)?(?:time\s+)?limit\s*:|dentro de|durante|(?:solo\s+)?(?:tengo|tenemos)(?:\s+solo)?|como máximo|no más de)\s+"
    r'(\d+(?:\.\d+)?)\s*(?:quiet\s+|spare\s+)?(minutes?|minutos?|mins?|hours?|horas?|hrs?)\b',
    caseSensitive: false,
  );
  // A requested short step is also a work window. Keep the request verb so
  // historical activity or a duration appearing only in a title is not a cap.
  final stepPattern = RegExp(
    r'\b(?:give me|suggest|plan|make|choose)(?:\s+an?)?\s+'
    r'(\d+(?:\.\d+)?)[ -]+(minutes?|hours?)[ -]+(?:step|plan|session|task)\b',
    caseSensitive: false,
  );
  // A present-tense capacity statement can share its verb: "I have zero
  // energy and five minutes". Keep the intervening phrase bounded to energy
  // rather than scanning arbitrary text (titles, past activity, or negation).
  final compoundWindowPattern = RegExp(
    r'\b(?:(?:i|we)\s+have\s+(?:(?:zero|no|low|little|very little|0)\s+)?energy\s+and\s+(?:only\s+)?'
    r'|(?<!no\s)(?:tengo|tenemos)\s+(?:(?:cero|poca|muy poca|0)\s+)?energ[ií]a\s+y\s+(?:solo\s+)?)'
    r'(\d+(?:\.\d+)?)\s*(?:quiet\s+|spare\s+)?(minutes?|minutos?|mins?|hours?|horas?|hrs?)\b',
    caseSensitive: false,
  );
  final actionWindowPattern = RegExp(
    r'\b(?:help me|please|can you help me|ay[uú]dame a)\s+[^.!?;]+?\s+(?:in|en)\s+'
    r'(\d+(?:\.\d+)?)\s*(minutes?|minutos?|mins?|hours?|horas?|hrs?)\b',
    caseSensitive: false,
  );
  final directActionWindowPattern = RegExp(
    '(?:^|[.!?]\\s*|\\b(?:i|we)\\s+(?:need|want|have) to\\s+)(?:$_plannerActionVerbs)\\b[^.!?;]+?\\s+(?:in|en)\\s+'
    r'(\d+(?:\.\d+)?)\s*(minutes?|minutos?|mins?|hours?|horas?|hrs?)\b',
    caseSensitive: false,
  );
  final matches = <RegExpMatch>[
    ...windowPattern.allMatches(normalized),
    ...stepPattern.allMatches(normalized),
    ...compoundWindowPattern.allMatches(normalized),
    ...actionWindowPattern.allMatches(normalized),
    ...directActionWindowPattern.allMatches(normalized),
  ];
  int? limit;
  for (final match in matches) {
    final double? amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite || amount <= 0) {
      continue;
    }
    final bool hours = match.group(2)!.toLowerCase().startsWith('h');
    final int minutes = (amount * (hours ? 60 : 1)).floor();
    if (minutes < 1 || minutes > 1440) {
      continue;
    }
    limit = limit == null ? minutes : math.min(limit, minutes);
  }
  return limit;
}

bool _declinesSavedChoice(String input) => RegExp(
  r'^(?:none|neither|no thanks|none of them|not now|ningun[oa]|ninguno|ninguna de ellas|no gracias)(?:[.!;,]|$)|^no[.!]?$|\b(?:new situation|new problem|use only what I|without saved|situación nueva|problema nuevo|solo lo que|sin tareas guardadas)\b',
  caseSensitive: false,
).hasMatch(input.trim());

final class _PlannerEvidence {
  const _PlannerEvidence.empty()
    : savedContextDeclined = false,
      activeTasks = const <TaskEntity>[],
      activeGoals = const <GoalEntity>[],
      focusTask = null,
      focusGoal = null,
      taskReadSucceeded = true,
      goalReadSucceeded = true,
      focusTaskIsUrgent = false,
      rhythms = const [],
      focusRhythm = null,
      selectedNote = null,
      rhythmReadSucceeded = true,
      noteReadSucceeded = true,
      personContext = const _PlannerPersonContextEvidence.unavailable(),
      operatingReceipt = const _PlannerOperatingReceiptEvidence.unavailable(),
      plannerMemory = const _PlannerMemoryEvidence.empty();

  _PlannerEvidence({
    required List<TaskEntity> activeTasks,
    required List<GoalEntity> activeGoals,
    required this.focusTask,
    required this.focusGoal,
    required this.taskReadSucceeded,
    required this.goalReadSucceeded,
    required this.focusTaskIsUrgent,
    required this.personContext,
    required this.operatingReceipt,
    required this.plannerMemory,
    this.rhythms = const [],
    this.focusRhythm,
    this.selectedNote,
    this.rhythmReadSucceeded = true,
    this.noteReadSucceeded = true,
    this.savedContextDeclined = false,
  }) : activeTasks = List<TaskEntity>.unmodifiable(activeTasks),
       activeGoals = List<GoalEntity>.unmodifiable(activeGoals);

  factory _PlannerEvidence.resolve({
    required List<TaskEntity> tasks,
    required List<GoalEntity> goals,
    required String searchText,
    required DateTime now,
    required bool taskReadSucceeded,
    required bool goalReadSucceeded,
    required PersonContextView? personContext,
    required String accountScopeId,
    required OperatingDecisionReceipt? operatingReceipt,
    required List<MemoryEntity> plannerMemories,
    bool savedContextDeclined = false,
    List<RhythmPlanningEntry> rhythms = const [],
    bool rhythmReadSucceeded = true,
    NoteEntity? selectedNote,
    bool noteReadSucceeded = true,
  }) {
    final List<TaskEntity> activeTasks = tasks
        .where((TaskEntity task) => task.isActive)
        .toList(growable: true);
    final List<GoalEntity> activeGoals = goals
        .where((GoalEntity goal) => goal.isActive)
        .toList(growable: true);
    final _PlannerPersonContextEvidence resolvedPersonContext =
        _PlannerPersonContextEvidence.resolve(
          personContext,
          now: now,
          accountScopeId: accountScopeId,
          decisionText: searchText,
        );
    final Set<String> requestTerms = _plannerTerms(
      searchText.replaceAll(
        RegExp(
          r'\b(?:\d+|one|two|three|four|five|ten|fifteen|twenty|thirty|forty|sixty)[ -]+minutes?\b',
          caseSensitive: false,
        ),
        '',
      ),
    );
    final bool explicitlyUsesNote = RegExp(
      r'\b(?:selected|this|that) note\b|\b(?:esta nota|nota seleccionada)\b',
      caseSensitive: false,
    ).hasMatch(searchText);
    if (selectedNote != null && !explicitlyUsesNote) {
      final noteTerms = _plannerTerms(
        '${selectedNote.title} ${selectedNote.body ?? ''}',
      );
      final linkedTaskMatches = activeTasks.any(
        (task) =>
            task.id == selectedNote?.taskId &&
            _taskTextMatch(task, requestTerms) > 0,
      );
      final linkedGoalMatches = activeGoals.any(
        (goal) =>
            goal.id == selectedNote?.goalId &&
            _goalTextMatch(goal, requestTerms) > 0,
      );
      if (!linkedTaskMatches &&
          !linkedGoalMatches &&
          noteTerms.intersection(requestTerms).isEmpty) {
        selectedNote = null;
      }
    }
    final bool requestMatchesSavedWork =
        activeTasks.any((task) => _taskTextMatch(task, requestTerms) > 0) ||
        activeGoals.any((goal) => _goalTextMatch(goal, requestTerms) > 0);
    // Only a relevant retained note may supply instructions. Its longer body
    // must not outvote the user's current named task or goal. Explicit requests
    // to use that note keep its linked evidence in the ranking.
    final Set<String> terms = requestMatchesSavedWork && !explicitlyUsesNote
        ? requestTerms
        : _plannerTerms(
            [
              searchText,
              if (!savedContextDeclined && selectedNote != null) ...[
                selectedNote.title,
                selectedNote.body ?? '',
                for (final task in activeTasks)
                  if (task.id == selectedNote.taskId) task.title,
                for (final goal in activeGoals)
                  if (goal.id == selectedNote.goalId) goal.title,
              ],
            ].join(' '),
          );
    activeTasks.sort(
      (TaskEntity left, TaskEntity right) =>
          _compareTasks(left, right, terms: terms, now: now),
    );
    activeGoals.sort(
      (GoalEntity left, GoalEntity right) =>
          _compareGoals(left, right, terms: terms, now: now),
    );

    final TaskEntity? matchedTask = activeTasks.isEmpty
        ? null
        : activeTasks.first;
    final GoalEntity? matchedGoal = activeGoals.isEmpty
        ? null
        : activeGoals.first;
    final int taskMatch = matchedTask == null
        ? 0
        : _taskTextMatch(matchedTask, terms);
    final bool hasCloseTaskTie =
        activeTasks
            .where(
              (TaskEntity task) => _taskTextMatch(task, terms) == taskMatch,
            )
            .length >
        1;
    final int goalMatch = matchedGoal == null
        ? 0
        : _goalTextMatch(matchedGoal, terms);

    TaskEntity? focusTask;
    GoalEntity? focusGoal;
    if (goalMatch > taskMatch && goalMatch > 0) {
      focusGoal = matchedGoal;
      final List<TaskEntity> linkedTasks = activeTasks
          .where((TaskEntity task) => task.goalId == focusGoal?.id)
          .toList(growable: false);
      if (linkedTasks.isNotEmpty) {
        focusTask = linkedTasks.first;
      }
    } else if (matchedTask != null && taskMatch > 0) {
      focusTask = matchedTask;
      for (final GoalEntity goal in activeGoals) {
        if (goal.id == focusTask.goalId) {
          focusGoal = goal;
          break;
        }
      }
    } else if (hasCloseTaskTie) {
      final _PlannerPersonContextSignal? rankingFocus =
          resolvedPersonContext.rankingFocus;
      final Set<String> contextTerms = rankingFocus == null
          ? const <String>{}
          : _plannerTerms(rankingFocus.value);
      int bestContextMatch = 0;
      for (final TaskEntity task in activeTasks) {
        final int match = _taskTextMatch(task, contextTerms);
        if (match <= bestContextMatch) {
          continue;
        }
        bestContextMatch = match;
        focusTask = task;
      }
      if (bestContextMatch == 0) {
        focusTask = null;
      } else {
        for (final GoalEntity goal in activeGoals) {
          if (goal.id == focusTask?.goalId) {
            focusGoal = goal;
            break;
          }
        }
      }
    }

    RhythmPlanningEntry? focusRhythm;
    int bestRhythmMatch = math.max(taskMatch, goalMatch);
    for (final entry in rhythms) {
      final match = _plannerTerms(
        '${entry.habit.title} ${entry.habit.description ?? ''}',
      ).intersection(terms).length;
      // A note link supplies context, not an unconditional choice of work.
      // Preserve a matched task/goal; a resolved linked rhythm cannot block it.
      final bool linkedFallback =
          entry.habit.id == selectedNote?.habitId &&
          focusTask == null &&
          focusGoal == null &&
          focusRhythm == null;
      if (linkedFallback || match > bestRhythmMatch) {
        focusRhythm = entry;
        bestRhythmMatch = match;
      }
    }
    if (focusRhythm != null) {
      focusTask = null;
      focusGoal = null;
    }
    if (selectedNote != null &&
        !explicitlyUsesNote &&
        ((selectedNote.taskId != null &&
                focusTask != null &&
                selectedNote.taskId != focusTask.id) ||
            (selectedNote.goalId != null &&
                focusGoal != null &&
                selectedNote.goalId != focusGoal.id))) {
      selectedNote = null;
    }
    final DateTime? focusTime = focusTask?.dueDate ?? focusTask?.scheduledFor;
    return _PlannerEvidence(
      activeTasks: activeTasks,
      activeGoals: activeGoals,
      focusTask: savedContextDeclined ? null : focusTask,
      focusGoal: savedContextDeclined ? null : focusGoal,
      taskReadSucceeded: taskReadSucceeded,
      goalReadSucceeded: goalReadSucceeded,
      personContext: resolvedPersonContext,
      operatingReceipt: _PlannerOperatingReceiptEvidence.resolve(
        savedContextDeclined ? null : operatingReceipt,
        searchText: searchText,
        now: now,
      ),
      plannerMemory: _PlannerMemoryEvidence.resolve(plannerMemories, now: now),
      savedContextDeclined: savedContextDeclined,
      rhythms: savedContextDeclined ? const [] : rhythms,
      focusRhythm: savedContextDeclined ? null : focusRhythm,
      selectedNote: savedContextDeclined ? null : selectedNote,
      rhythmReadSucceeded: rhythmReadSucceeded,
      noteReadSucceeded: noteReadSucceeded,
      focusTaskIsUrgent:
          focusTime != null &&
          !focusTime.isAfter(now.add(const Duration(days: 1))),
    );
  }

  final List<TaskEntity> activeTasks;
  final List<GoalEntity> activeGoals;
  final TaskEntity? focusTask;
  final GoalEntity? focusGoal;
  final bool taskReadSucceeded;
  final bool goalReadSucceeded;
  final bool focusTaskIsUrgent;
  final _PlannerPersonContextEvidence personContext;
  final _PlannerOperatingReceiptEvidence operatingReceipt;
  final _PlannerMemoryEvidence plannerMemory;
  final bool savedContextDeclined;
  final List<RhythmPlanningEntry> rhythms;
  final RhythmPlanningEntry? focusRhythm;
  final NoteEntity? selectedNote;
  final bool rhythmReadSucceeded;
  final bool noteReadSucceeded;

  RhythmPlanningEntry? get resolvedRhythm =>
      focusRhythm?.needsAttention == false ? focusRhythm : null;
  int? get noteTimeLimitMinutes => selectedNote == null
      ? null
      : _explicitPlanningTimeLimit(
          '${selectedNote!.title} ${selectedNote!.body ?? ''}',
        );
  List<String> get supplementaryEvidence => supplementaryEvidenceFor();

  List<String> supplementaryEvidenceFor({String languageCode = 'en'}) => [
    if (!rhythmReadSucceeded)
      _plannerEvidenceText(
        languageCode,
        'Daily Rhythm outcomes were unavailable; remaining rhythm work was not assumed.',
        'Los resultados de Ritmo diario no estaban disponibles; no se supuso que quedara trabajo por hacer.',
      ),
    if (rhythmReadSucceeded && rhythms.isNotEmpty)
      _plannerEvidenceText(
        languageCode,
        'Daily Rhythms: ${rhythms.where((entry) => entry.needsAttention).length} current-period targets have no recorded outcome. Individual repetitions and session durations are unknown.',
        'Ritmos diarios: ${rhythms.where((entry) => entry.needsAttention).length} objetivos del período actual no tienen un resultado registrado. Se desconocen las repeticiones individuales y la duración de las sesiones.',
      ),
    if (focusRhythm != null)
      _plannerEvidenceText(
        languageCode,
        'Focused Daily Rhythm: "${SmartPlannerQueryController._safeEvidenceTitle(focusRhythm!.habit.title)}"; ${focusRhythm!.habit.targetCount} per ${focusRhythm!.habit.cadence.name}; period ${focusRhythm!.periodKey}; ${focusRhythm!.status.name}.',
        'Ritmo diario elegido: "${SmartPlannerQueryController._safeEvidenceTitle(focusRhythm!.habit.title)}"; ${focusRhythm!.habit.targetCount} por ${_plannerEvidenceLabel(focusRhythm!.habit.cadence.name)}; período ${focusRhythm!.periodKey}; ${_plannerEvidenceLabel(focusRhythm!.status.name)}.',
      ),
    if (!noteReadSucceeded)
      _plannerEvidenceText(
        languageCode,
        'The selected note could not be read; its contents were not used.',
        'No se pudo leer la nota seleccionada; no se usó su contenido.',
      ),
    if (selectedNote != null)
      _plannerEvidenceText(
        languageCode,
        'Read note "${SmartPlannerQueryController._safeEvidenceTitle(selectedNote!.title)}" because you explicitly selected it. Applied actions and limits are listed separately; no emotion was inferred from it.',
        'Se leyó la nota "${SmartPlannerQueryController._safeEvidenceTitle(selectedNote!.title)}" porque la seleccionaste explícitamente. Las acciones y los límites aplicados se indican por separado; no se dedujo ninguna emoción de la nota.',
      ),
    if (noteTimeLimitMinutes != null)
      _plannerEvidenceText(
        languageCode,
        'Applied the selected note\'s explicit $noteTimeLimitMinutes-minute limit to every option.',
        'Se aplicó a todas las opciones el límite explícito de $noteTimeLimitMinutes minutos de la nota seleccionada.',
      ),
  ];

  bool get hasStoredEvidence =>
      activeTasks.isNotEmpty ||
      activeGoals.isNotEmpty ||
      rhythms.isNotEmpty ||
      selectedNote != null;

  bool get hasMatchedStoredEvidence =>
      focusTask != null ||
      focusGoal != null ||
      focusRhythm != null ||
      selectedNote != null;

  bool get hasPositiveGrounding =>
      !savedContextDeclined &&
      (hasMatchedStoredEvidence ||
          operatingReceipt.focus != null ||
          personContext.planningFocus != null);

  bool get hasAvailableGroundingEvidence =>
      hasStoredEvidence ||
      operatingReceipt.wasAvailable ||
      personContext.planningFocus != null;

  bool get requiresClarification =>
      !savedContextDeclined &&
      hasAvailableGroundingEvidence &&
      !hasPositiveGrounding;

  String get domainAdaptationSummary => domainAdaptationSummaryFor();

  String domainAdaptationSummaryFor({String languageCode = 'en'}) {
    if (focusRhythm != null) {
      return _plannerEvidenceText(
        languageCode,
        'Used the matched Daily Rhythm and its current period outcome.',
        'Se usó el Ritmo diario coincidente y su resultado del período actual.',
      );
    }
    if (selectedNote != null) {
      return _plannerEvidenceText(
        languageCode,
        'Used only the note explicitly selected for this planning session, plus relevant saved evidence.',
        'Se usó únicamente la nota seleccionada explícitamente para esta sesión, junto con la información guardada pertinente.',
      );
    }
    if (savedContextDeclined) {
      return _plannerEvidenceText(
        languageCode,
        'You chose to plan independently; saved tasks, goals, and recommendations were not attached. Consented capacity limits still apply.',
        'Elegiste planificar de forma independiente; no se añadieron tareas, metas ni recomendaciones guardadas. Siguen aplicándose los límites de capacidad que autorizaste.',
      );
    }
    if (hasMatchedStoredEvidence) {
      return _plannerEvidenceText(
        languageCode,
        'Used only saved task or goal evidence with a positive text relevance match.',
        'Solo se usaron tareas o metas guardadas cuyo texto coincide de forma pertinente con la solicitud.',
      );
    }
    if (personContext.planningFocus != null) {
      return _plannerEvidenceText(
        languageCode,
        'Used only consented, fresh Person Context with typed or positive-text relevance to this planning request.',
        'Solo se usó Contexto Personal vigente y autorizado, pertinente por su categoría o por una coincidencia de texto con esta solicitud.',
      );
    }
    if (hasStoredEvidence) {
      return _plannerEvidenceText(
        languageCode,
        'Active saved tasks or goals were present, but none had positive relevance to this check-in.',
        'Había tareas o metas guardadas activas, pero ninguna era pertinente para este registro.',
      );
    }
    if (!taskReadSucceeded || !goalReadSucceeded) {
      return _plannerEvidenceText(
        languageCode,
        'Saved task or goal evidence was unavailable; the missing data was not treated as an empty account.',
        'La información de tareas o metas guardadas no estaba disponible; la falta de datos no se interpretó como una cuenta vacía.',
      );
    }
    return _plannerEvidenceText(
      languageCode,
      'No active saved task or goal was available to ground this check-in.',
      'No había una tarea o meta guardada activa disponible para fundamentar este registro.',
    );
  }

  String? get focusSubject {
    if (savedContextDeclined) {
      return null;
    }
    if (focusRhythm != null) {
      return 'Daily Rhythm "${SmartPlannerQueryController._safeEvidenceTitle(focusRhythm!.habit.title)}"';
    }
    final TaskEntity? task = focusTask;
    if (task != null) {
      return 'saved task "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"';
    }
    final GoalEntity? goal = focusGoal;
    if (goal != null) {
      return 'saved goal "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"';
    }
    final OperatingDecisionReceipt? receipt = operatingReceipt.focus;
    if (receipt != null) {
      return 'saved planning recommendation "${SmartPlannerQueryController._safeEvidenceTitle(receipt.recommendedAction)}"';
    }
    return selectedNote != null
        ? 'selected note "${SmartPlannerQueryController._safeEvidenceTitle(selectedNote!.title)}"'
        : personContext.planningFocus?.subject;
  }

  String? focusSubjectFor({String languageCode = 'en'}) {
    if (languageCode.toLowerCase().split(RegExp('[-_]')).first != 'es') {
      return focusSubject;
    }
    if (savedContextDeclined) return null;
    if (focusRhythm != null) {
      return 'el Ritmo diario "${SmartPlannerQueryController._safeEvidenceTitle(focusRhythm!.habit.title)}"';
    }
    if (focusTask != null) {
      return 'la tarea guardada "${SmartPlannerQueryController._safeEvidenceTitle(focusTask!.title)}"';
    }
    if (focusGoal != null) {
      return 'la meta guardada "${SmartPlannerQueryController._safeEvidenceTitle(focusGoal!.title)}"';
    }
    if (operatingReceipt.focus != null) {
      return 'la recomendación de planificación guardada "${SmartPlannerQueryController._safeEvidenceTitle(operatingReceipt.focus!.recommendedAction)}"';
    }
    return selectedNote != null
        ? 'la nota seleccionada "${SmartPlannerQueryController._safeEvidenceTitle(selectedNote!.title)}"'
        : personContext.planningFocus?.subjectFor(languageCode: languageCode);
  }

  String? get mattersMost {
    if (savedContextDeclined) {
      return null;
    }
    if (focusRhythm != null) {
      return 'Planning only rhythm work that is still needed in the current period.';
    }
    final TaskEntity? task = focusTask;
    if (task != null) {
      return 'Making a credible next move on saved task "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}" without exceeding your reported capacity.';
    }
    final GoalEntity? goal = focusGoal;
    if (goal != null) {
      return 'Turning saved goal "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}" into observable progress.';
    }
    final OperatingDecisionReceipt? receipt = operatingReceipt.focus;
    if (receipt != null) {
      return SmartPlannerQueryController._condense(
        receipt.whyItMatters,
        maxLength: 180,
      );
    }
    return personContext.planningFocus?.mattersMost;
  }

  String? mattersMostFor({String languageCode = 'en'}) {
    if (languageCode.toLowerCase().split(RegExp('[-_]')).first != 'es') {
      return mattersMost;
    }
    if (savedContextDeclined) return null;
    if (focusRhythm != null) {
      return 'Planificar únicamente lo que aún falta del ritmo en el período actual.';
    }
    if (focusTask != null) {
      return 'Dar un siguiente paso realista en la tarea guardada "${SmartPlannerQueryController._safeEvidenceTitle(focusTask!.title)}" sin superar la capacidad que indicaste.';
    }
    if (focusGoal != null) {
      return 'Avanzar de forma observable en la meta guardada "${SmartPlannerQueryController._safeEvidenceTitle(focusGoal!.title)}".';
    }
    if (operatingReceipt.focus != null) {
      return SmartPlannerQueryController._condense(
        operatingReceipt.focus!.whyItMatters,
        maxLength: 180,
      );
    }
    return personContext.planningFocus?.mattersMostFor(
      languageCode: languageCode,
    );
  }

  Map<String, Object?> get requestContext => <String, Object?>{
    'storedEvidenceUsed': hasMatchedStoredEvidence,
    'storedEvidenceAvailable': hasStoredEvidence,
    'positiveEvidenceRelevance': hasPositiveGrounding,
    'activeTaskCount': activeTasks.length,
    'activeGoalCount': activeGoals.length,
    'selectedNoteId': selectedNote?.id,
    'rhythmEvidenceReadSucceeded': rhythmReadSucceeded,
    'noteEvidenceReadSucceeded': noteReadSucceeded,
    'focusedEvidenceKind': focusRhythm != null
        ? 'daily_rhythm'
        : focusTask != null
        ? 'task'
        : focusGoal != null
        ? 'goal'
        : operatingReceipt.focus != null
        ? 'operating_receipt'
        : !savedContextDeclined && personContext.planningFocus != null
        ? 'person_context'
        : selectedNote != null
        ? 'note'
        : 'none',
    'taskEvidenceReadSucceeded': taskReadSucceeded,
    'goalEvidenceReadSucceeded': goalReadSucceeded,
    ...operatingReceipt.requestContext,
    ...plannerMemory.requestContext,
    ...personContext.requestContext,
  };

  List<String> verifiedEvidence(
    DateTime observedAt, {
    String languageCode = 'en',
  }) {
    if (savedContextDeclined) {
      return <String>[
        domainAdaptationSummaryFor(languageCode: languageCode),
        ...plannerMemory.verifiedEvidence(languageCode: languageCode),
        ...personContext.verifiedEvidence(languageCode: languageCode),
      ];
    }
    final List<String> evidence = <String>[];
    if (!taskReadSucceeded || !goalReadSucceeded) {
      evidence.add(
        _plannerEvidenceText(
          languageCode,
          'Saved planning evidence was only partially available for this check-in.',
          'La información de planificación guardada solo estaba parcialmente disponible para este registro.',
        ),
      );
    }
    if (!hasStoredEvidence) {
      evidence.add(
        taskReadSucceeded && goalReadSucceeded
            ? _plannerEvidenceText(
                languageCode,
                'Saved planning evidence checked: no active tasks or goals were found for this account.',
                'Se comprobó la información de planificación guardada: no se encontraron tareas ni metas activas en esta cuenta.',
              )
            : _plannerEvidenceText(
                languageCode,
                'No readable active task or goal was available, so guidance used check-in context only.',
                'No se pudo leer ninguna tarea o meta activa, así que la orientación solo usó el contexto de este registro.',
              ),
      );
    } else if (!hasMatchedStoredEvidence) {
      evidence.add(
        _plannerEvidenceText(
          languageCode,
          'Saved planning evidence checked: ${activeTasks.length} active task(s) and ${activeGoals.length} active goal(s), with no positive relevance match to this check-in.',
          'Se comprobó la información de planificación guardada: ${activeTasks.length} tarea(s) activa(s) y ${activeGoals.length} meta(s) activa(s), sin coincidencias pertinentes para este registro.',
        ),
      );
    } else {
      evidence.add(
        _plannerEvidenceText(
          languageCode,
          'Saved planning evidence read at ${observedAt.toIso8601String()}: ${activeTasks.length} active task(s), ${activeGoals.length} active goal(s).',
          'Información de planificación guardada leída a las ${observedAt.toIso8601String()}: ${activeTasks.length} tarea(s) activa(s), ${activeGoals.length} meta(s) activa(s).',
        ),
      );
      final TaskEntity? task = focusTask;
      if (task != null) {
        final DateTime? relevantDate = task.dueDate ?? task.scheduledFor;
        final String timing = relevantDate == null
            ? _plannerEvidenceText(
                languageCode,
                'no saved due or scheduled time',
                'sin fecha límite ni horario guardado',
              )
            : '${task.dueDate != null ? _plannerEvidenceText(languageCode, 'due', 'fecha límite') : _plannerEvidenceText(languageCode, 'scheduled', 'programada para')} ${_dateLabel(relevantDate)}';
        evidence.add(
          _plannerEvidenceText(
            languageCode,
            'Focused saved task: "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"; priority ${task.priority}/5; energy ${task.energyRequired}/5; $timing.',
            'Tarea guardada elegida: "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"; prioridad ${task.priority}/5; energía ${task.energyRequired}/5; $timing.',
          ),
        );
      }
      final GoalEntity? goal = focusGoal;
      if (goal != null) {
        evidence.add(
          _plannerEvidenceText(
            languageCode,
            'Focused saved goal: "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"; ${goal.targetDate == null ? 'no target date' : 'target ${_dateLabel(goal.targetDate!)}'}.',
            'Meta guardada elegida: "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"; ${goal.targetDate == null ? 'sin fecha objetivo' : 'fecha objetivo ${_dateLabel(goal.targetDate!)}'}.',
          ),
        );
      }
    }
    evidence.addAll(
      operatingReceipt.verifiedEvidence(languageCode: languageCode),
    );
    evidence.addAll(plannerMemory.verifiedEvidence(languageCode: languageCode));
    evidence.addAll(personContext.verifiedEvidence(languageCode: languageCode));
    evidence.addAll(supplementaryEvidenceFor(languageCode: languageCode));
    return evidence;
  }

  List<String> clarificationEvidence(
    DateTime observedAt, {
    String languageCode = 'en',
  }) {
    final List<String> evidence = <String>[
      if (!taskReadSucceeded || !goalReadSucceeded)
        _plannerEvidenceText(
          languageCode,
          'Saved planning evidence was only partially available for this check-in.',
          'La información de planificación guardada solo estaba parcialmente disponible para este registro.',
        )
      else if (hasStoredEvidence)
        _plannerEvidenceText(
          languageCode,
          'Saved planning evidence checked at ${observedAt.toIso8601String()}: ${activeTasks.length} active task(s), ${activeGoals.length} active goal(s); none was attached without positive relevance.',
          'Información de planificación guardada comprobada a las ${observedAt.toIso8601String()}: ${activeTasks.length} tarea(s) activa(s), ${activeGoals.length} meta(s) activa(s); no se añadió ninguna sin una coincidencia pertinente.',
        )
      else
        _plannerEvidenceText(
          languageCode,
          'Saved planning evidence checked: no active tasks or goals were found for this account.',
          'Se comprobó la información de planificación guardada: no se encontraron tareas ni metas activas en esta cuenta.',
        ),
      ...operatingReceipt.clarificationEvidence(languageCode: languageCode),
      ...plannerMemory.verifiedEvidence(languageCode: languageCode),
      ...personContext.verifiedEvidence(languageCode: languageCode),
      ...supplementaryEvidenceFor(languageCode: languageCode),
    ];
    return evidence;
  }
}

enum _PlannerOperatingReceiptStatus { unavailable, expired, unmatched, matched }

final class _PlannerOperatingReceiptEvidence {
  const _PlannerOperatingReceiptEvidence.unavailable()
    : status = _PlannerOperatingReceiptStatus.unavailable,
      receipt = null;

  const _PlannerOperatingReceiptEvidence._(this.status, this.receipt);

  factory _PlannerOperatingReceiptEvidence.resolve(
    OperatingDecisionReceipt? receipt, {
    required String searchText,
    required DateTime now,
  }) {
    if (receipt == null) {
      return const _PlannerOperatingReceiptEvidence.unavailable();
    }
    try {
      receipt.validate();
    } on Object {
      return const _PlannerOperatingReceiptEvidence.unavailable();
    }
    if (receipt.isExpiredAt(now)) {
      return _PlannerOperatingReceiptEvidence._(
        _PlannerOperatingReceiptStatus.expired,
        receipt,
      );
    }
    final Set<String> queryTerms = _plannerTerms(searchText);
    // Explanatory boilerplate is not the subject of a saved recommendation.
    final Set<String> receiptTerms = _plannerTerms(receipt.recommendedAction);
    final bool matched = queryTerms.any(receiptTerms.contains);
    return _PlannerOperatingReceiptEvidence._(
      matched
          ? _PlannerOperatingReceiptStatus.matched
          : _PlannerOperatingReceiptStatus.unmatched,
      receipt,
    );
  }

  final _PlannerOperatingReceiptStatus status;
  final OperatingDecisionReceipt? receipt;

  OperatingDecisionReceipt? get focus =>
      status == _PlannerOperatingReceiptStatus.matched ? receipt : null;

  bool get wasAvailable =>
      status == _PlannerOperatingReceiptStatus.matched ||
      status == _PlannerOperatingReceiptStatus.unmatched;

  String get adaptationSummary => adaptationSummaryFor();

  String adaptationSummaryFor({String languageCode = 'en'}) => switch (status) {
    _PlannerOperatingReceiptStatus.matched => _plannerEvidenceText(
      languageCode,
      'Used a recent saved planning recommendation only after a positive relevance match.',
      'Solo se usó una recomendación de planificación guardada reciente después de comprobar que era pertinente.',
    ),
    _PlannerOperatingReceiptStatus.unmatched => _plannerEvidenceText(
      languageCode,
      'A recent saved planning recommendation was available but not used because it did not match this check-in.',
      'Había una recomendación de planificación guardada reciente, pero no se usó porque no coincidía con este registro.',
    ),
    _PlannerOperatingReceiptStatus.expired => _plannerEvidenceText(
      languageCode,
      'The saved planning recommendation had expired and was not used.',
      'La recomendación de planificación guardada había caducado y no se usó.',
    ),
    _PlannerOperatingReceiptStatus.unavailable => _plannerEvidenceText(
      languageCode,
      'No recent saved planning recommendation was available.',
      'No había ninguna recomendación de planificación guardada reciente disponible.',
    ),
  };

  Map<String, Object?> get requestContext => <String, Object?>{
    'operatingReceiptStatus': status.name,
    'operatingReceiptUsed': focus != null,
    'operatingReceiptId': focus?.decisionId,
  };

  List<String> verifiedEvidence({
    String languageCode = 'en',
  }) => switch (status) {
    _PlannerOperatingReceiptStatus.matched => <String>[
      _plannerEvidenceText(
        languageCode,
        'A saved planning recommendation matched this check-in: "${SmartPlannerQueryController._safeEvidenceTitle(receipt!.recommendedAction)}"; generated ${receipt!.generatedAt.toUtc().toIso8601String()}; expires ${receipt!.expiresAt.toUtc().toIso8601String()}.',
        'Una recomendación de planificación guardada coincidió con este registro: "${SmartPlannerQueryController._safeEvidenceTitle(receipt!.recommendedAction)}"; creada ${receipt!.generatedAt.toUtc().toIso8601String()}; caduca ${receipt!.expiresAt.toUtc().toIso8601String()}.',
      ),
    ],
    _PlannerOperatingReceiptStatus.unmatched => <String>[
      _plannerEvidenceText(
        languageCode,
        'A recent saved planning recommendation was checked but not attached because it had no positive relevance match.',
        'Se comprobó una recomendación de planificación guardada reciente, pero no se añadió porque no tenía una coincidencia pertinente.',
      ),
    ],
    _PlannerOperatingReceiptStatus.expired => <String>[
      _plannerEvidenceText(
        languageCode,
        'The available saved planning recommendation had expired and was not used.',
        'La recomendación de planificación guardada disponible había caducado y no se usó.',
      ),
    ],
    _PlannerOperatingReceiptStatus.unavailable => <String>[
      _plannerEvidenceText(
        languageCode,
        'No recent saved planning recommendation was available for this check-in.',
        'No había ninguna recomendación de planificación guardada reciente para este registro.',
      ),
    ],
  };

  List<String> clarificationEvidence({
    String languageCode = 'en',
  }) => switch (status) {
    _PlannerOperatingReceiptStatus.matched ||
    _PlannerOperatingReceiptStatus.unmatched => <String>[
      _plannerEvidenceText(
        languageCode,
        'A recent saved planning recommendation was checked and was not attached while clarification is needed.',
        'Se comprobó una recomendación de planificación guardada reciente; no se añadió porque aún hace falta una aclaración.',
      ),
    ],
    _PlannerOperatingReceiptStatus.expired => <String>[
      _plannerEvidenceText(
        languageCode,
        'The available saved planning recommendation had expired and was not used.',
        'La recomendación de planificación guardada disponible había caducado y no se usó.',
      ),
    ],
    _PlannerOperatingReceiptStatus.unavailable => <String>[
      _plannerEvidenceText(
        languageCode,
        'No recent saved planning recommendation was available for this check-in.',
        'No había ninguna recomendación de planificación guardada reciente para este registro.',
      ),
    ],
  };
}

final class _PlannerMemoryEvidence {
  const _PlannerMemoryEvidence.empty() : memories = const <MemoryEntity>[];

  const _PlannerMemoryEvidence._(this.memories);

  factory _PlannerMemoryEvidence.resolve(
    List<MemoryEntity> memories, {
    required DateTime now,
  }) {
    final List<MemoryEntity> authorized = memories
        .where(
          (MemoryEntity memory) =>
              memory.sourceSurface == MemorySurface.smartPlanner &&
              memory.purpose == MemoryPurpose.guidancePreference &&
              memory.consentStatus == MemoryConsentStatus.granted &&
              memory.sensitivity != MemorySensitivity.emotional &&
              memory.sensitivity != MemorySensitivity.crisis &&
              !memory.isArchived &&
              !memory.isExpiredAt(now),
        )
        .take(2)
        .toList(growable: false);
    return _PlannerMemoryEvidence._(
      List<MemoryEntity>.unmodifiable(authorized),
    );
  }

  final List<MemoryEntity> memories;

  String get adaptationSummary => adaptationSummaryFor();

  String adaptationSummaryFor({String languageCode = 'en'}) => memories.isEmpty
      ? _plannerEvidenceText(
          languageCode,
          'No governed Smart Planner preference was recalled.',
          'No se recuperó ninguna preferencia guardada con consentimiento del Planificador Inteligente.',
        )
      : _plannerEvidenceText(
          languageCode,
          'Recalled ${memories.length} consented Smart Planner guidance preference(s) through the exact surface and purpose boundary.',
          'Se recuperaron ${memories.length} preferencias autorizadas de orientación del Planificador Inteligente, respetando el ámbito y la finalidad exactos.',
        );

  Map<String, Object?> get requestContext => <String, Object?>{
    'plannerMemoryPurpose': MemoryPurpose.guidancePreference.name,
    'plannerMemorySignalsUsed': memories.length,
  };

  List<String> verifiedEvidence({String languageCode = 'en'}) {
    if (memories.isEmpty) {
      return <String>[
        _plannerEvidenceText(
          languageCode,
          'No authorized governed Smart Planner preference was recalled.',
          'No se recuperó ninguna preferencia guardada autorizada del Planificador Inteligente.',
        ),
      ];
    }
    return memories
        .map(
          (MemoryEntity memory) => _plannerEvidenceText(
            languageCode,
            'Governed Smart Planner preference recalled for ${memory.purpose.name}: "${SmartPlannerQueryController._condense(memory.text.replaceAll('"', "'"), maxLength: 120)}". It remained bounded to Smart Planner.',
            'Preferencia guardada autorizada del Planificador Inteligente recuperada para ${_plannerEvidenceLabel(memory.purpose.name)}: "${SmartPlannerQueryController._condense(memory.text.replaceAll('"', "'"), maxLength: 120)}". Su uso siguió limitado al Planificador Inteligente.',
          ),
        )
        .toList(growable: false);
  }
}

String _plannerEvidenceText(
  String languageCode,
  String english,
  String spanish,
) => languageCode.toLowerCase().split(RegExp('[-_]')).first == 'es'
    ? spanish
    : english;

String _plannerEvidenceLabel(String code) => switch (code) {
  'daily' => 'día',
  'weekly' => 'semana',
  'monthly' => 'mes',
  'unrecorded' => 'sin registrar',
  'completed' => 'completado',
  'skipped' => 'omitido',
  'paused' => 'en pausa',
  'role' => 'rol',
  'value' => 'valor',
  'currentPriority' => 'prioridad actual',
  'lifeArea' => 'área de vida',
  'presentCapacity' => 'capacidad actual',
  'preferredSupportStyle' => 'estilo de apoyo preferido',
  'boundary' => 'límite',
  'importantRelationship' => 'relación importante',
  'commitment' => 'compromiso',
  'outcomeHistory' => 'historial de resultados confirmados',
  'userAuthored' => 'aportada por ti',
  'confirmedOutcome' => 'resultado confirmado',
  'planningGuidance' => 'orientación de planificación',
  'decisionSupport' => 'apoyo para decisiones',
  'reflection' => 'reflexión',
  'outcomeLearning' => 'aprendizaje de resultados',
  'guidancePreference' => 'preferencia de orientación',
  'userNote' => 'nota del usuario',
  'unknown' => 'finalidad desconocida',
  _ => code,
};

const Set<String> _plannerStopWords = <String>{
  // Request scaffolding and constraint language do not identify a saved
  // subject. Otherwise "one ... task list" can outrank "course".
  'the', 'and', 'for', 'one', 'small', 'step', 'steps', 'use', 'selected',
  'note', 'keep', 'unchanged', 'list', 'task', 'tasks', 'goal', 'goals',
  'without', 'another', 'next', 'not', 'its', 'limit', 'minutes',
  'about',
  'after',
  'before',
  'only',
  'again',
  'could',
  'current',
  'give',
  'have',
  'help',
  'make',
  'need',
  'plan',
  'planner',
  'planning',
  'practical',
  'should',
  'that',
  'this',
  'today',
  'want',
  'what',
  'with',
  'would',
  'para', 'antes', 'después', 'solo', 'tengo', 'necesito', 'quiero', 'minutos',
  'tarea', 'tareas', 'objetivo', 'objetivos', 'nota', 'seleccionada', 'ayúdame',
};

Set<String> _plannerTerms(String input) => RegExp(r'[a-záéíóúüñ0-9]+')
    .allMatches(input.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where(
      (String term) => term.length >= 3 && !_plannerStopWords.contains(term),
    )
    .toSet();

int _taskTextMatch(TaskEntity task, Set<String> terms) {
  if (terms.isEmpty) {
    return 0;
  }
  final Set<String> titleTerms = _plannerTerms(task.title);
  final Set<String> descriptionTerms = _plannerTerms(task.description ?? '');
  return terms.where(titleTerms.contains).length * 4 +
      terms.where(descriptionTerms.contains).length;
}

int _goalTextMatch(GoalEntity goal, Set<String> terms) {
  if (terms.isEmpty) {
    return 0;
  }
  final Set<String> titleTerms = _plannerTerms(goal.title);
  final Set<String> descriptionTerms = _plannerTerms(goal.description ?? '');
  return terms.where(titleTerms.contains).length * 4 +
      terms.where(descriptionTerms.contains).length;
}

int _compareTasks(
  TaskEntity left,
  TaskEntity right, {
  required Set<String> terms,
  required DateTime now,
}) {
  final int leftScore =
      _taskTextMatch(left, terms) * 1000 + _taskPriorityScore(left, now);
  final int rightScore =
      _taskTextMatch(right, terms) * 1000 + _taskPriorityScore(right, now);
  final int scoreOrder = rightScore.compareTo(leftScore);
  return scoreOrder != 0 ? scoreOrder : left.title.compareTo(right.title);
}

int _taskPriorityScore(TaskEntity task, DateTime now) {
  int score = task.priority.clamp(1, 5) * 20;
  final DateTime? relevant = task.dueDate ?? task.scheduledFor;
  if (relevant == null) {
    return score;
  }
  if (!relevant.isAfter(now)) {
    return score + 300;
  }
  if (!relevant.isAfter(now.add(const Duration(days: 1)))) {
    return score + 220;
  }
  if (!relevant.isAfter(now.add(const Duration(days: 7)))) {
    return score + 100;
  }
  return score + 20;
}

int _compareGoals(
  GoalEntity left,
  GoalEntity right, {
  required Set<String> terms,
  required DateTime now,
}) {
  final int leftScore =
      _goalTextMatch(left, terms) * 1000 + _goalUrgencyScore(left, now);
  final int rightScore =
      _goalTextMatch(right, terms) * 1000 + _goalUrgencyScore(right, now);
  final int scoreOrder = rightScore.compareTo(leftScore);
  return scoreOrder != 0 ? scoreOrder : left.title.compareTo(right.title);
}

int _goalUrgencyScore(GoalEntity goal, DateTime now) {
  final DateTime? target = goal.targetDate;
  if (target == null) {
    return 0;
  }
  if (!target.isAfter(now)) {
    return 200;
  }
  if (!target.isAfter(now.add(const Duration(days: 7)))) {
    return 100;
  }
  if (!target.isAfter(now.add(const Duration(days: 30)))) {
    return 40;
  }
  return 10;
}

String _dateLabel(DateTime value) =>
    value.toLocal().toIso8601String().split('T').first;

AssistantSafetyReceipt _requirePublishableSafety(
  AssistantSafetyOutcome outcome,
) {
  if (!outcome.mayPublish) {
    throw const AssistantSafetyRouteException(
      'assistant_response_withheld',
      'The response did not pass the assistant safety boundary.',
    );
  }
  return outcome.receipt;
}

enum _PlannerTopic {
  overwhelm,
  habit,
  recovery,
  wellbeing,
  goal,
  focus,
  health,
  general,
}

final class _EffortProfile {
  const _EffortProfile(
    this.minimumMinutes,
    this.bestFitMinutes,
    this.stretchMinutes,
  );

  final int minimumMinutes;
  final int bestFitMinutes;
  final int stretchMinutes;

  _EffortProfile cappedAt(int maximumMinutes) => _EffortProfile(
    math.min(minimumMinutes, maximumMinutes),
    math.min(bestFitMinutes, maximumMinutes),
    math.min(stretchMinutes, maximumMinutes),
  );
}

PlannerV2Response _compatibilityPlannerResponse({
  required String prompt,
  required String message,
  required List<String> evidence,
  required AIProcessingMode processingMode,
}) {
  final String safeMessage = message.trim().isEmpty
      ? 'Choose one concrete next action.'
      : message.trim();
  return PlannerV2Response(
    whatIHeard: prompt.trim().isEmpty ? 'You want planning guidance.' : prompt,
    mattersMost: 'A clear next action.',
    verifiedEvidence: evidence.isEmpty
        ? const <String>['Compatibility response; no stored evidence used.']
        : evidence,
    options: <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: 'Small start',
        description: safeMessage,
        estimatedMinutes: 5,
        tradeoff: 'Lowest effort.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Practical step',
        description: safeMessage,
        estimatedMinutes: 20,
        tradeoff: 'Balanced effort.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: 'Deeper pass',
        description: safeMessage,
        estimatedMinutes: 40,
        tradeoff: 'Higher effort.',
      ),
    ],
    recommendedKind: PlannerOptionKind.bestFit,
    recommendationReason: 'Compatibility response supplied by the caller.',
    nextStep: safeMessage,
    adaptationReceipt: PlannerAdaptationReceipt(
      userSetEnergy: null,
      userSelectedEmotion: null,
      adjustments: const <String>[
        'Compatibility mode did not use energy or infer emotional state.',
      ],
    ),
    origin: processingMode == AIProcessingMode.external
        ? PlannerResponseOrigin.externalModel
        : PlannerResponseOrigin.deterministic,
  );
}
