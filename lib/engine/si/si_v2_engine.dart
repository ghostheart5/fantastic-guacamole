import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

final class SIV2Engine {
  const SIV2Engine();

  /// Record lists and unsupported questions must retain their own response
  /// instead of receiving the Home decision's unrelated recommendation.
  bool allowsSharedDecisionFor(SIV2Query query) =>
      query.intent == SIV2Intent.answer &&
      query.entityFilter == null &&
      query.assumptions.isEmpty &&
      query.priorUserTurns.isEmpty &&
      RegExp(
        r'^(?:what should i do next|what needs attention|qu[eé] deber[ií]a hacer despu[eé]s|qu[eé] necesita atenci[oó]n)[?!.¿¡ ]*$',
        caseSensitive: false,
      ).hasMatch(query.rawText);

  SIV2Response analyze({
    required SIV2Query query,
    required SIV2EvidenceSnapshot snapshot,
    required DateTime now,
  }) {
    final DateTime observedNow = now.toLocal();
    final _SIV2Question question = _SIV2Question.parse(query);
    final String? entityFilter = query.entityFilter?.toLowerCase();
    bool matchesEntity(String title) =>
        entityFilter == null || title.toLowerCase().contains(entityFilter);

    final List<SIV2TaskEvidence> tasks =
        query.sources.contains(SIV2Source.tasks)
        ? snapshot.tasks
              .where((SIV2TaskEvidence item) => matchesEntity(item.title))
              .where((SIV2TaskEvidence item) => !question.excludes(item.title))
              .where(
                (SIV2TaskEvidence item) =>
                    _withinTaskRange(item, query.timeRange, observedNow),
              )
              .toList(growable: false)
        : const <SIV2TaskEvidence>[];
    final List<SIV2GoalEvidence> goals =
        query.sources.contains(SIV2Source.goals)
        ? snapshot.goals
              .where((SIV2GoalEvidence item) => matchesEntity(item.title))
              .where((SIV2GoalEvidence item) => !question.excludes(item.title))
              .where(
                (SIV2GoalEvidence item) => _withinGoalRange(
                  item.targetDate,
                  query.timeRange,
                  observedNow,
                  undatedMatches: true,
                ),
              )
              .toList(growable: false)
        : const <SIV2GoalEvidence>[];
    final List<SIV2MilestoneEvidence> milestones =
        query.sources.contains(SIV2Source.milestones)
        ? snapshot.milestones
              .where((SIV2MilestoneEvidence item) => !item.archived)
              .where((SIV2MilestoneEvidence item) => matchesEntity(item.title))
              .where(
                (SIV2MilestoneEvidence item) => !question.excludes(item.title),
              )
              .where(
                (SIV2MilestoneEvidence item) => _withinDeadlineRange(
                  item.targetDate,
                  query.timeRange,
                  observedNow,
                  undatedMatches: true,
                ),
              )
              .toList(growable: false)
        : const <SIV2MilestoneEvidence>[];
    final List<SIV2TimelineEvidence> timeline =
        query.sources.contains(SIV2Source.timeline)
        ? snapshot.timeline
              .where((SIV2TimelineEvidence item) => matchesEntity(item.title))
              .where(
                (SIV2TimelineEvidence item) => !question.excludes(item.title),
              )
              .where(
                (SIV2TimelineEvidence item) =>
                    _withinTimelineRange(item, query.timeRange, observedNow),
              )
              .toList(growable: false)
        : const <SIV2TimelineEvidence>[];

    final List<SIV2EvidenceLink> links = _buildEvidenceLinks(
      snapshot: snapshot,
      query: query,
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      timeline: timeline,
    );
    final Map<String, SIV2EvidenceLink> linkById = <String, SIV2EvidenceLink>{
      for (final SIV2EvidenceLink link in links) link.evidenceId: link,
    };
    String sourceId(SIV2Source source) => '${source.name}:collection';

    final List<SIV2Statement> facts = <SIV2Statement>[
      if (query.sources.contains(SIV2Source.tasks))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text: question.isSpanish
              ? '${tasks.length} ${tasks.length == 1 ? 'tarea activa coincide' : 'tareas activas coinciden'} con el filtro actual.'
              : '${tasks.length} active task${tasks.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.tasks)],
        ),
      if (query.sources.contains(SIV2Source.goals))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text: question.isSpanish
              ? '${goals.length} ${goals.length == 1 ? 'meta activa coincide' : 'metas activas coinciden'} con el filtro actual.'
              : '${goals.length} active goal${goals.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.goals)],
        ),
      if (query.sources.contains(SIV2Source.milestones))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text: question.isSpanish
              ? '${milestones.length} ${milestones.length == 1 ? 'hito coincide' : 'hitos coinciden'} con el filtro actual.'
              : '${milestones.length} milestone${milestones.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.milestones)],
        ),
      if (query.sources.contains(SIV2Source.timeline))
        SIV2Statement(
          kind: SIV2StatementKind.observedFact,
          text: question.isSpanish
              ? '${timeline.length} ${timeline.length == 1 ? 'evento del Historial coincide' : 'eventos del Historial coinciden'} con el filtro actual.'
              : '${timeline.length} Timeline event${timeline.length == 1 ? '' : 's'} matched the current lens.',
          evidenceIds: <String>[sourceId(SIV2Source.timeline)],
        ),
    ];
    final List<SIV2Statement> userReportedEvidence = <SIV2Statement>[
      ...?snapshot.personContext?.signals.map(
        (SIV2PersonContextSignalEvidence signal) => SIV2Statement(
          kind: SIV2StatementKind.userReportedEvidence,
          text: question.isSpanish
              ? 'La persona informó ${signal.kind.name}: ${_sentence(signal.userReportedValue)} Es contexto pertinente, no un hecho verificado de forma independiente.'
              : 'User reported ${signal.kind.name}: ${_sentence(signal.userReportedValue)} This is relevant context, not independently verified fact.',
          evidenceIds: <String>['person-context:${signal.id}'],
        ),
      ),
    ];

    final int overdueTasks = tasks
        .where(
          (SIV2TaskEvidence item) =>
              item.dueDate != null && _taskIsOverdue(item, observedNow),
        )
        .length;
    final int overdueGoals = goals
        .where(
          (SIV2GoalEvidence item) =>
              item.targetDate != null &&
              _localDay(item.targetDate!).isBefore(_localDay(observedNow)),
        )
        .length;
    final int overdueMilestones = milestones
        .where(
          (SIV2MilestoneEvidence item) =>
              !item.completed &&
              item.targetDate != null &&
              item.targetDate!.toUtc().isBefore(observedNow),
        )
        .length;
    final List<SIV2Statement> calculations = <SIV2Statement>[
      if (query.sources.contains(SIV2Source.tasks))
        SIV2Statement(
          kind: SIV2StatementKind.deterministicCalculation,
          text: question.isSpanish
              ? '$overdueTasks ${overdueTasks == 1 ? 'tarea está vencida' : 'tareas están vencidas'} según la fecha guardada.'
              : '$overdueTasks matched task${overdueTasks == 1 ? ' is' : 's are'} past the recorded due date.',
          evidenceIds: <String>[sourceId(SIV2Source.tasks)],
        ),
      if (query.sources.contains(SIV2Source.goals))
        SIV2Statement(
          kind: SIV2StatementKind.deterministicCalculation,
          text: question.isSpanish
              ? '$overdueGoals ${overdueGoals == 1 ? 'meta está vencida' : 'metas están vencidas'} según la fecha objetivo guardada.'
              : '$overdueGoals matched goal${overdueGoals == 1 ? ' is' : 's are'} past the recorded target date.',
          evidenceIds: <String>[sourceId(SIV2Source.goals)],
        ),
      if (query.sources.contains(SIV2Source.milestones))
        SIV2Statement(
          kind: SIV2StatementKind.deterministicCalculation,
          text: question.isSpanish
              ? '$overdueMilestones ${overdueMilestones == 1 ? 'hito incompleto está vencido' : 'hitos incompletos están vencidos'} según la fecha objetivo guardada.'
              : '$overdueMilestones incomplete milestone${overdueMilestones == 1 ? ' is' : 's are'} past the recorded target date.',
          evidenceIds: <String>[sourceId(SIV2Source.milestones)],
        ),
    ];

    final List<SIV2Conflict> conflicts = _detectConflicts(
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      now: observedNow,
      linkById: linkById,
    );
    final bool namedTaskMissing =
        question.namedTaskPhrase != null &&
        !tasks.any((task) => question.matchesNamedTask(task.title));
    SIV2TaskEvidence? focusTask = namedTaskMissing
        ? null
        : _selectFocusTask(tasks, question);
    SIV2GoalEvidence? focusGoal = namedTaskMissing
        ? null
        : _selectFocusGoal(goals, question);
    final int taskQuestionScore = focusTask == null
        ? 0
        : question.titleScore(focusTask.title);
    final int goalQuestionScore = focusGoal == null
        ? 0
        : question.titleScore(focusGoal.title);
    final bool questionLeadsWithGoal =
        question.namedTaskPhrase == null &&
        focusGoal != null &&
        (goalQuestionScore > taskQuestionScore ||
            (question.sourceHint == SIV2Source.goals &&
                goalQuestionScore >= taskQuestionScore));
    if (questionLeadsWithGoal) {
      final List<SIV2TaskEvidence> linkedTasks = tasks
          .where((SIV2TaskEvidence task) => task.goalId == focusGoal!.id)
          .toList(growable: false);
      focusTask = _selectFocusTask(linkedTasks, question);
    } else if (focusTask?.goalId != null &&
        (taskQuestionScore > 0 || question.sourceHint == SIV2Source.tasks)) {
      focusGoal = goals
          .where((SIV2GoalEvidence goal) => goal.id == focusTask!.goalId)
          .firstOrNull;
    }
    final SIV2MilestoneEvidence? focusMilestone = namedTaskMissing
        ? null
        : _selectFocusMilestone(milestones, question);
    if (focusMilestone?.goalId != null &&
        question.titleScore(focusMilestone!.title) >
            (focusGoal == null ? 0 : question.titleScore(focusGoal.title))) {
      focusGoal = goals
          .where((goal) => goal.id == focusMilestone.goalId)
          .firstOrNull;
    }
    final SIV2TimelineEvidence? focusTimeline = namedTaskMissing
        ? null
        : _selectFocusTimeline(timeline, question, observedNow);
    final List<SIV2Scenario> scenarios = _buildScenarios(
      task: focusTask,
      goals: goals,
      now: observedNow,
      userAssumptions: query.assumptions,
      deferDays: question.deferDays,
      spanish: question.isSpanish,
      linkById: linkById,
    );
    final List<String> scenarioAssumptions = <String>[
      question.isSpanish
          ? 'Los escenarios describen efectos en el horario guardado, no resultados seguros.'
          : 'Scenarios describe recorded schedule effects, not certain outcomes.',
      question.isSpanish
          ? 'No se supone ninguna dependencia, viaje o límite de capacidad que no esté guardado.'
          : 'No unrecorded dependency, travel, or capacity constraint is assumed.',
      ...query.assumptions,
    ];
    final List<String> missing = <String>[
      if (namedTaskMissing)
        question.isSpanish
            ? 'No se encontró una tarea guardada que coincida con "${question.namedTaskPhrase}" en los datos seleccionados.'
            : 'No saved task matching "${question.namedTaskPhrase}" was found in the selected evidence lens.',
      for (final SIV2Source source in query.sources)
        if (snapshot.unavailableSources.contains(source))
          question.isSpanish
              ? 'Los datos de ${_sourceLabelSpanish(source)} no están disponibles.'
              : '${source.label} evidence is unavailable.',
      if (query.sources.contains(SIV2Source.tasks) &&
          !snapshot.unavailableSources.contains(SIV2Source.tasks) &&
          tasks.isEmpty)
        question.isSpanish
            ? 'Ninguna tarea activa coincide con el filtro actual.'
            : 'No active task evidence matched the current lens.',
      if (query.sources.contains(SIV2Source.goals) &&
          !snapshot.unavailableSources.contains(SIV2Source.goals) &&
          goals.isEmpty)
        question.isSpanish
            ? 'Ninguna meta coincide con el filtro actual.'
            : 'No goal evidence matched the current lens.',
      if (query.sources.contains(SIV2Source.milestones) &&
          !snapshot.unavailableSources.contains(SIV2Source.milestones) &&
          milestones.isEmpty)
        question.isSpanish
            ? 'Ningún hito coincide con el filtro actual.'
            : 'No milestone evidence matched the current lens.',
      if (query.sources.contains(SIV2Source.timeline) &&
          !snapshot.unavailableSources.contains(SIV2Source.timeline) &&
          timeline.isEmpty)
        question.isSpanish
            ? 'Ningún evento del Historial coincide con el filtro actual.'
            : 'No Timeline evidence matched the current lens.',
      if (query.entityFilter != null &&
          tasks.isEmpty &&
          goals.isEmpty &&
          milestones.isEmpty &&
          timeline.isEmpty)
        question.isSpanish
            ? 'Ningún título coincide con "${query.entityFilter}".'
            : 'No entity title matched "${query.entityFilter}".',
      if (tasks.any(
        (SIV2TaskEvidence item) =>
            item.dueDate == null && item.scheduledFor == null,
      ))
        question.isSpanish
            ? 'Al menos una tarea coincidente no tiene fecha de vencimiento ni horario.'
            : 'At least one matched task has no due date or schedule.',
      if (question.focus == _SIV2QuestionFocus.unsupported)
        question.isSpanish
            ? 'La pregunta no corresponde a una decisión de planificación que estos datos de solo lectura puedan responder.'
            : 'The question does not identify a planning decision that this read-only evidence lens can answer.',
      ...?snapshot.personContext?.unknownKinds.map(
        (PersonContextKind kind) => question.isSpanish
            ? 'El Contexto personal no contiene ${kind.name} informado por la persona; SI no lo dedujo.'
            : 'Person Context has no user-provided ${kind.name}; SI did not infer it.',
      ),
      ...conflicts.map((SIV2Conflict item) => item.summary),
    ];
    final List<SIV2Statement> inferences = <SIV2Statement>[
      if (question.entityMatchStatement(
            task: focusTask,
            goal: focusGoal,
            milestone: focusMilestone,
            timeline: focusTimeline,
          )
          case final SIV2Statement statement)
        statement,
      if (overdueTasks + overdueGoals + overdueMilestones > 0)
        SIV2Statement(
          kind: SIV2StatementKind.inference,
          text: question.isSpanish
              ? 'La presión de fechas guardadas parece ser la señal de atención más fuerte.'
              : 'Recorded deadline pressure appears to be the strongest attention signal.',
          evidenceIds: conflicts
              .expand((SIV2Conflict item) => item.evidenceIds)
              .toSet()
              .toList(growable: false),
        )
      else
        SIV2Statement(
          kind: SIV2StatementKind.inference,
          text: question.isSpanish
              ? 'Ninguna fecha vencida domina este filtro; la prioridad y el orden de dependencias deben guiar la elección.'
              : 'No overdue deadline dominates this lens; priority and dependency order should drive the choice.',
          evidenceIds: focusTask == null
              ? const <String>[]
              : <String>['tasks:${focusTask.id}'],
        ),
    ];

    final String groundedAnswer = namedTaskMissing
        ? question.isSpanish
              ? 'No encuentro una tarea guardada que coincida con "${question.namedTaskPhrase}" en los datos seleccionados. No puedo explicar su posición ni afirmar que tenga una fecha guardada. Comprueba el título o amplía el filtro.'
              : 'I could not find a saved task matching "${question.namedTaskPhrase}" in the selected evidence lens. I cannot explain its rank or claim a saved date. Check the title or widen the filter.'
        : _directAnswer(
            question: question,
            focusTask: focusTask,
            focusGoal: focusGoal,
            focusMilestone: focusMilestone,
            focusTimeline: focusTimeline,
            tasks: tasks,
            goals: goals,
            milestones: milestones,
            timeline: timeline,
            conflicts: conflicts,
            scenarios: scenarios,
            now: observedNow,
            missingInformation: missing,
            totalMatched:
                tasks.length +
                goals.length +
                milestones.length +
                timeline.length,
          );
    final String directAnswer = namedTaskMissing || userReportedEvidence.isEmpty
        ? groundedAnswer
        : '$groundedAnswer ${userReportedEvidence.length} relevant user-reported context ${userReportedEvidence.length == 1 ? 'item is' : 'items are'} cited separately and not independently verified.';
    final String recommendation = namedTaskMissing
        ? question.isSpanish
              ? 'Comprueba el título exacto de la tarea o amplía el filtro antes de decidir. SI no cambió datos guardados.'
              : 'Check the exact task title or widen the evidence lens before deciding. SI has not changed saved data.'
        : _recommendation(
            question: question,
            focusTask: focusTask,
            focusGoal: focusGoal,
            focusMilestone: focusMilestone,
            focusTimeline: focusTimeline,
            conflicts: conflicts,
          );

    final int requiredSignals = query.sources.length;
    final int coveredSignals = <SIV2Source>[
      if (tasks.isNotEmpty) SIV2Source.tasks,
      if (goals.isNotEmpty) SIV2Source.goals,
      if (milestones.isNotEmpty) SIV2Source.milestones,
      if (timeline.isNotEmpty) SIV2Source.timeline,
    ].where(query.sources.contains).length;
    final Duration age = observedNow.difference(snapshot.observedAt.toUtc());
    final SIV2Freshness freshness = coveredSignals == 0
        ? SIV2Freshness.unavailable
        : age.isNegative || age <= const Duration(hours: 1)
        ? SIV2Freshness.current
        : age <= const Duration(hours: 24)
        ? SIV2Freshness.aging
        : SIV2Freshness.stale;
    final SIV2EvidenceStrength strength = namedTaskMissing
        ? SIV2EvidenceStrength.limited
        : coveredSignals > 0 && coveredSignals == requiredSignals
        ? (conflicts.length <= 1
              ? SIV2EvidenceStrength.strong
              : SIV2EvidenceStrength.moderate)
        : coveredSignals * 2 >= requiredSignals
        ? SIV2EvidenceStrength.moderate
        : SIV2EvidenceStrength.limited;

    final bool refusal =
        question.focus == _SIV2QuestionFocus.unsupported || namedTaskMissing;
    final focusScore = focusTask == null
        ? 0
        : question.titleScore(focusTask.title);
    final uniquelyNamedTask =
        !refusal &&
        focusTask != null &&
        focusScore > 0 &&
        tasks
                .where((task) => question.titleScore(task.title) == focusScore)
                .length ==
            1;
    final SIV2Response response = SIV2Response(
      query: query,
      snapshotRevision: snapshot.revision,
      directAnswer: directAnswer,
      observedFacts: facts,
      userReportedEvidence: userReportedEvidence,
      calculations: refusal ? const <SIV2Statement>[] : calculations,
      inferences: refusal ? const <SIV2Statement>[] : inferences,
      missingInformation: question.focus == _SIV2QuestionFocus.unsupported
          ? <String>[
              question.isSpanish
                  ? 'La pregunta no corresponde a una decisión de planificación que pueda responderse con estos datos.'
                  : 'The question does not identify a planning decision that this read-only evidence lens can answer.',
            ]
          : missing,
      conflicts: refusal ? const <SIV2Conflict>[] : conflicts,
      scenarios: refusal ? const <SIV2Scenario>[] : scenarios,
      scenarioAssumptions: refusal ? const <String>[] : scenarioAssumptions,
      recommendation: recommendation,
      confidence: SIV2ConfidenceAnatomy(
        strength: strength,
        coveredSignals: coveredSignals,
        requiredSignals: requiredSignals,
        freshness: freshness,
        conflictCount: conflicts.length,
        assumptionCount: scenarioAssumptions.length,
      ),
      evidenceLinks: links,
      focusTaskId: uniquelyNamedTask ? focusTask.id : null,
    );
    return question.isSpanish
        ? _localizeSpanishResponse(response, question: question)
        : response;
  }

  SIV2Response _localizeSpanishResponse(
    SIV2Response source, {
    required _SIV2Question question,
  }) {
    if (question.namedTaskPhrase != null &&
        source.missingInformation.any(
          (item) => item.startsWith('No se encontró una tarea guardada'),
        )) {
      return source;
    }
    final entityLinks = source.evidenceLinks
        .where((link) => link.entityId != 'collection')
        .toList(growable: false);
    SIV2EvidenceLink? subject = entityLinks
        .where((link) => source.directAnswer.contains(link.label))
        .firstOrNull;
    subject ??= entityLinks
        .where((link) => link.source == question.sourceHint)
        .firstOrNull;
    subject ??= entityLinks.firstOrNull;
    final subjectLabel = subject?.label;
    final subjectText = subjectLabel == null
        ? 'los datos guardados'
        : '"$subjectLabel"';
    final int matchedTasks = source.evidenceLinks
        .where(
          (link) =>
              link.evidenceId.startsWith('tasks:') &&
              link.entityId != 'collection',
        )
        .length;
    final int matchedGoals = source.evidenceLinks
        .where(
          (link) =>
              link.evidenceId.startsWith('goals:') &&
              link.entityId != 'collection',
        )
        .length;
    final int matchedMilestones = source.evidenceLinks
        .where(
          (link) =>
              link.evidenceId.startsWith('milestones:') &&
              link.entityId != 'collection',
        )
        .length;
    final int matchedTimeline = source.evidenceLinks
        .where(
          (link) =>
              link.evidenceId.startsWith('timeline:') &&
              link.entityId != 'collection',
        )
        .length;
    final int totalMatched =
        matchedTasks + matchedGoals + matchedMilestones + matchedTimeline;
    final String directAnswer;
    if (question.requestsListing) {
      final titles = entityLinks
          .where(
            (link) =>
                question.sourceHint == null ||
                link.source == question.sourceHint,
          )
          .map((link) => link.label)
          .toList();
      directAnswer = titles.isEmpty
          ? 'No hay registros guardados que coincidan con este filtro.'
          : '${titles.length} registros guardados coinciden:\n${titles.take(20).map((title) => '• $title').join('\n')}'
                '${titles.length > 20 ? '\nSe muestran los primeros 20; reduce el filtro para ver el resto.' : ''}';
    } else if (totalMatched == 0) {
      directAnswer = question.focus == _SIV2QuestionFocus.unsupported
          ? 'No puedo responder esa pregunta con las tareas, metas, hitos o eventos guardados. Puedo ayudarte con qué necesita atención, qué hacer después, el progreso, las fechas o los conflictos.'
          : 'Ningún dato guardado coincide con las fuentes, fechas y filtros seleccionados, así que no puedo responder esta pregunta con evidencia de la app.';
    } else {
      directAnswer = switch (question.focus) {
        _SIV2QuestionFocus.nextAction =>
          question.availableMinutes != null
              ? 'Usa los ${question.availableMinutes} ${question.availableMinutes == 1 ? 'minuto disponible' : 'minutos disponibles'} para empezar una parte concreta de $subjectText. No conozco la duración completa, así que esto es un inicio y no una promesa de terminar.'
              : 'La siguiente acción mejor respaldada por los datos guardados es revisar $subjectText y elegir una parte concreta para empezar.',
        _SIV2QuestionFocus.urgency =>
          'Lo que requiere atención primero según la prioridad y las fechas guardadas es $subjectText.',
        _SIV2QuestionFocus.workload =>
          'El filtro contiene $matchedTasks ${matchedTasks == 1 ? 'tarea activa' : 'tareas activas'}. Las fechas y prioridades guardadas describen la carga; no hay duraciones suficientes para afirmar capacidad total.',
        _SIV2QuestionFocus.progress =>
          'El progreso respaldado por los hitos guardados se refiere a $subjectText. Si faltan hitos, no puedo convertir la actividad general en un porcentaje fiable.',
        _SIV2QuestionFocus.goalAlignment =>
          'Los vínculos guardados de tareas, hitos y metas muestran la relación disponible para $subjectText; no se dedujo ninguna relación adicional.',
        _SIV2QuestionFocus.schedule =>
          'La información de horario y vencimiento guardada que mejor coincide con la pregunta corresponde a $subjectText. Una hora programada y una fecha de vencimiento se tratan como datos distintos.',
        _SIV2QuestionFocus.comparison =>
          'La comparación usa únicamente los registros guardados que coinciden con la pregunta. El primer elemento respaldado es $subjectText.',
        _SIV2QuestionFocus.explanation =>
          'La explicación disponible para $subjectText se limita a sus campos guardados, vínculos, prioridad y fechas; no se inventó una causa.',
        _SIV2QuestionFocus.forecast =>
          'Se calcularon escenarios condicionales para $subjectText usando el cambio solicitado de ${question.deferDays} ${question.deferDays == 1 ? 'día' : 'días'}. No son predicciones seguras.',
        _SIV2QuestionFocus.conflict =>
          source.conflicts.isEmpty
              ? 'No se encontró un conflicto explícito de horario, vínculo o dependencia que coincida con la pregunta.'
              : 'Se encontró un conflicto explícito relacionado con $subjectText. Revisa la evidencia citada antes de cambiar los datos.',
        _SIV2QuestionFocus.counterfactual =>
          'La respuesta sobre $subjectText cambiaría si cambian sus fechas, prioridad, vínculos o dependencias guardadas.',
        _SIV2QuestionFocus.timeline =>
          'El evento del Historial que mejor coincide con la pregunta es $subjectText.',
        _SIV2QuestionFocus.evidenceGaps =>
          source.missingInformation.isEmpty
              ? 'No se identificaron vacíos de evidencia en el filtro seleccionado.'
              : 'Hay información ausente o en conflicto. Revisa la sección correspondiente antes de tomar una decisión.',
        _SIV2QuestionFocus.overview =>
          question.requestsListing
              ? '$totalMatched ${totalMatched == 1 ? 'registro guardado coincide' : 'registros guardados coinciden'} con el filtro actual. Revisa la lista de evidencia para ver cada título.'
              : '$totalMatched ${totalMatched == 1 ? 'registro guardado coincide' : 'registros guardados coinciden'}. Pregunta por la siguiente acción, urgencia, progreso, horario, conflictos o un título concreto.',
        _SIV2QuestionFocus.unsupported =>
          'No puedo responder esa pregunta con las tareas, metas, hitos o eventos guardados. Puedo ayudarte con qué necesita atención, qué hacer después, el progreso, las fechas o los conflictos.',
      };
    }
    final String recommendation =
        question.focus == _SIV2QuestionFocus.unsupported
        ? 'Prueba una pregunta compatible, como “¿Qué necesita atención?” o “¿Qué debería hacer después?”.'
        : subjectLabel == null
        ? 'Ajusta las fuentes, fechas o el título buscado antes de confiar en esta respuesta. SI no cambió ningún dato guardado.'
        : 'Revisa $subjectText y decide de forma explícita si quieres actuar, posponer, editar o rechazar la recomendación. SI no cambió ningún dato guardado.';

    SIV2Statement localizeStatement(SIV2Statement statement) {
      if (!RegExp(
        r'\b(the|current|saved|recorded|wording|question|task|goal|milestone|timeline|user|evidence)\b',
        caseSensitive: false,
      ).hasMatch(statement.text)) {
        return statement;
      }
      return SIV2Statement(
        kind: statement.kind,
        text: statement.kind == SIV2StatementKind.inference
            ? 'La coincidencia se determinó a partir de las palabras de la pregunta y los títulos guardados citados.'
            : 'Este dato procede directamente de los registros citados de la app.',
        evidenceIds: statement.evidenceIds,
      );
    }

    return SIV2Response(
      schemaVersion: source.schemaVersion,
      query: source.query,
      snapshotRevision: source.snapshotRevision,
      directAnswer: directAnswer,
      observedFacts: source.observedFacts.map(localizeStatement).toList(),
      userReportedEvidence: source.userReportedEvidence
          .map(localizeStatement)
          .toList(),
      calculations: source.calculations.map(localizeStatement).toList(),
      inferences: source.inferences.map(localizeStatement).toList(),
      missingInformation: source.missingInformation
          .map(
            (item) =>
                RegExp(
                  r'\b(the|current|saved|recorded|task|goal|milestone|timeline|evidence|conflict)\b',
                  caseSensitive: false,
                ).hasMatch(item)
                ? 'Falta información pertinente o existe un conflicto en los datos citados.'
                : item,
          )
          .toSet()
          .toList(),
      conflicts: source.conflicts
          .map(
            (item) => SIV2Conflict(
              conflictId: item.conflictId,
              severity: item.severity,
              summary:
                  'Los datos citados contienen un conflicto explícito de fecha, vínculo o dependencia.',
              evidenceIds: item.evidenceIds,
            ),
          )
          .toList(),
      scenarios: source.scenarios,
      scenarioAssumptions: source.scenarioAssumptions,
      recommendation: recommendation,
      confidence: source.confidence,
      evidenceLinks: source.evidenceLinks,
      focusTaskId: source.focusTaskId,
      safetyReceipt: source.safetyReceipt,
    );
  }

  String _sourceLabelSpanish(SIV2Source source) => switch (source) {
    SIV2Source.tasks => 'tareas',
    SIV2Source.goals => 'metas',
    SIV2Source.milestones => 'hitos',
    SIV2Source.timeline => 'Historial',
  };

  List<SIV2EvidenceLink> _buildEvidenceLinks({
    required SIV2EvidenceSnapshot snapshot,
    required SIV2Query query,
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required List<SIV2TimelineEvidence> timeline,
  }) {
    final List<SIV2EvidenceLink> links = <SIV2EvidenceLink>[];
    void collection(SIV2Source source, int count) {
      if (!query.sources.contains(source)) return;
      links.add(
        SIV2EvidenceLink(
          evidenceId: '${source.name}:collection',
          source: source,
          label: '${source.label} lens ($count matched)',
          entityId: 'collection',
          observedAt: snapshot.observedAt,
          uri: 'chronospark://${source.name}',
        ),
      );
    }

    collection(SIV2Source.tasks, tasks.length);
    collection(SIV2Source.goals, goals.length);
    collection(SIV2Source.milestones, milestones.length);
    collection(SIV2Source.timeline, timeline.length);
    links.addAll(
      tasks.map(
        (SIV2TaskEvidence item) => SIV2EvidenceLink(
          evidenceId: 'tasks:${item.id}',
          source: SIV2Source.tasks,
          label: item.title,
          entityId: item.id,
          observedAt: snapshot.observedAt,
          uri: 'chronospark://tasks/${item.id}',
        ),
      ),
    );
    links.addAll(
      goals.map(
        (SIV2GoalEvidence item) => SIV2EvidenceLink(
          evidenceId: 'goals:${item.id}',
          source: SIV2Source.goals,
          label: item.title,
          entityId: item.id,
          observedAt: snapshot.observedAt,
          uri: 'chronospark://goals/${item.id}',
        ),
      ),
    );
    links.addAll(
      milestones.map(
        (SIV2MilestoneEvidence item) => SIV2EvidenceLink(
          evidenceId: 'milestones:${item.id}',
          source: SIV2Source.milestones,
          label: item.title,
          entityId: item.id,
          observedAt: item.updatedAt,
          uri: 'chronospark://milestones/${item.id}',
        ),
      ),
    );
    links.addAll(
      timeline.map(
        (SIV2TimelineEvidence item) => SIV2EvidenceLink(
          evidenceId: 'timeline:${item.id}',
          source: SIV2Source.timeline,
          label: item.title,
          entityId: item.id,
          observedAt: item.timestamp,
          uri: 'chronospark://timeline/${item.id}',
        ),
      ),
    );
    links.addAll(
      snapshot.personContext?.signals.map(
            (SIV2PersonContextSignalEvidence item) => SIV2EvidenceLink(
              evidenceId: 'person-context:${item.id}',
              source: null,
              label: 'User-reported ${item.kind.name}',
              entityId: item.id,
              observedAt: item.recordedAt,
              uri: 'chronospark://person-context/${item.id}',
              userReported: true,
            ),
          ) ??
          const <SIV2EvidenceLink>[],
    );
    return links;
  }

  List<SIV2Conflict> _detectConflicts({
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required DateTime now,
    required Map<String, SIV2EvidenceLink> linkById,
  }) {
    final Map<String, SIV2GoalEvidence> goalsById = <String, SIV2GoalEvidence>{
      for (final SIV2GoalEvidence goal in goals) goal.id: goal,
    };
    final Set<String> milestoneIds = milestones
        .map((SIV2MilestoneEvidence item) => item.id)
        .toSet();
    final List<SIV2Conflict> conflicts = <SIV2Conflict>[];
    for (final SIV2TaskEvidence task in tasks) {
      final String taskEvidence = 'tasks:${task.id}';
      if (_taskIsOverdue(task, now)) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'overdue-task:${task.id}',
            severity: task.priority >= 4
                ? SIV2ConflictSeverity.critical
                : SIV2ConflictSeverity.warning,
            summary: 'Task "${task.title}" is past its recorded due date.',
            evidenceIds: <String>[
              if (linkById.containsKey(taskEvidence)) taskEvidence,
            ],
          ),
        );
      }
      final String? goalId = task.goalId;
      if (goalId == null) continue;
      final SIV2GoalEvidence? goal = goalsById[goalId];
      if (goal == null) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'missing-goal:$goalId:${task.id}',
            severity: SIV2ConflictSeverity.warning,
            summary:
                'Task "${task.title}" references a goal outside the current evidence lens.',
            evidenceIds: <String>[
              if (linkById.containsKey(taskEvidence)) taskEvidence,
            ],
          ),
        );
        continue;
      }
      final DateTime? taskDate = task.dueDate ?? task.scheduledFor;
      if (taskDate != null &&
          goal.targetDate != null &&
          _localDay(taskDate).isAfter(_localDay(goal.targetDate!))) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'task-after-goal:${task.id}:$goalId',
            severity: SIV2ConflictSeverity.critical,
            summary:
                'Task "${task.title}" is scheduled after goal "${goal.title}" ends.',
            evidenceIds: <String>[
              if (linkById.containsKey(taskEvidence)) taskEvidence,
              if (linkById.containsKey('goals:$goalId')) 'goals:$goalId',
            ],
          ),
        );
      }
    }
    for (final SIV2MilestoneEvidence milestone in milestones) {
      final String evidence = 'milestones:${milestone.id}';
      final List<String> missingDependencies = milestone.dependencies
          .where((String id) => !milestoneIds.contains(id))
          .toList(growable: false);
      if (missingDependencies.isNotEmpty) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'missing-milestone-dependency:${milestone.id}',
            severity: SIV2ConflictSeverity.warning,
            summary:
                'Milestone "${milestone.title}" has ${missingDependencies.length} dependency reference${missingDependencies.length == 1 ? '' : 's'} outside the lens.',
            evidenceIds: <String>[if (linkById.containsKey(evidence)) evidence],
          ),
        );
      }
      final SIV2GoalEvidence? goal = milestone.goalId == null
          ? null
          : goalsById[milestone.goalId!];
      if (goal?.targetDate != null &&
          milestone.targetDate != null &&
          _localDay(
            milestone.targetDate!,
          ).isAfter(_localDay(goal!.targetDate!))) {
        conflicts.add(
          SIV2Conflict(
            conflictId: 'milestone-after-goal:${milestone.id}:${goal.id}',
            severity: SIV2ConflictSeverity.critical,
            summary:
                'Milestone "${milestone.title}" ends after goal "${goal.title}".',
            evidenceIds: <String>[
              if (linkById.containsKey(evidence)) evidence,
              if (linkById.containsKey('goals:${goal.id}')) 'goals:${goal.id}',
            ],
          ),
        );
      }
    }
    return conflicts;
  }

  List<SIV2Scenario> _buildScenarios({
    required SIV2TaskEvidence? task,
    required List<SIV2GoalEvidence> goals,
    required DateTime now,
    required List<String> userAssumptions,
    required int deferDays,
    required bool spanish,
    required Map<String, SIV2EvidenceLink> linkById,
  }) {
    if (task == null) return const <SIV2Scenario>[];
    final String evidenceId = 'tasks:${task.id}';
    final List<String> citations = <String>[
      if (linkById.containsKey(evidenceId)) evidenceId,
    ];
    final DateTime? recordedDate = task.dueDate ?? task.scheduledFor;
    final DateTime deferredDate = (recordedDate ?? now).add(
      Duration(days: deferDays),
    );
    final SIV2GoalEvidence? linkedGoal = task.goalId == null
        ? null
        : goals
              .where((SIV2GoalEvidence item) => item.id == task.goalId)
              .firstOrNull;
    final bool crossesGoalDate =
        linkedGoal?.targetDate != null &&
        _localDay(deferredDate).isAfter(_localDay(linkedGoal!.targetDate!));
    return <SIV2Scenario>[
      SIV2Scenario(
        kind: SIV2ScenarioKind.doNow,
        label: spanish ? 'Hacer ahora' : 'Do now',
        projectedEffect: spanish
            ? 'Escenario: actuar ahora sobre "${task.title}" evita añadir un retraso de $deferDays ${deferDays == 1 ? 'día' : 'días'}.'
            : 'Scenario: acting on "${task.title}" now avoids adding a $deferDays-${deferDays == 1 ? 'day' : 'day'} schedule delay.',
        assumptions: <String>[
          spanish
              ? 'La tarea puede iniciarse con la capacidad actual.'
              : 'The task can be started with current capacity.',
          ...userAssumptions,
        ],
        evidenceIds: citations,
      ),
      SIV2Scenario(
        kind: SIV2ScenarioKind.deferOneDay,
        label: spanish
            ? 'Posponer $deferDays ${deferDays == 1 ? 'día' : 'días'}'
            : 'Defer $deferDays ${deferDays == 1 ? 'day' : 'days'}',
        projectedEffect: crossesGoalDate
            ? (spanish
                  ? 'Escenario: posponer $deferDays ${deferDays == 1 ? 'día' : 'días'} cruza la fecha objetivo de la meta vinculada y aumenta el conflicto registrado.'
                  : 'Scenario: a $deferDays-${deferDays == 1 ? 'day' : 'day'} deferral crosses the linked goal target date and increases recorded schedule conflict.')
            : (spanish
                  ? 'Escenario: posponer $deferDays ${deferDays == 1 ? 'día' : 'días'} cambia la próxima fecha registrada sin cruzar una meta visible.'
                  : 'Scenario: a $deferDays-${deferDays == 1 ? 'day' : 'day'} deferral shifts the next recorded task date without crossing a visible goal target.'),
        assumptions: <String>[
          spanish
              ? 'La fecha de la tarea cambia exactamente $deferDays ${deferDays == 1 ? 'día' : 'días'}.'
              : 'The task date moves by exactly $deferDays ${deferDays == 1 ? 'day' : 'days'}.',
          ...userAssumptions,
        ],
        evidenceIds: <String>[
          ...citations,
          if (linkedGoal != null &&
              linkById.containsKey('goals:${linkedGoal.id}'))
            'goals:${linkedGoal.id}',
        ],
      ),
      SIV2Scenario(
        kind: SIV2ScenarioKind.skip,
        label: spanish ? 'Omitir' : 'Skip',
        projectedEffect: task.priority >= 4
            ? (spanish
                  ? 'Escenario: omitir quita esta tarea de hoy pero deja sin resolver un compromiso de alta prioridad.'
                  : 'Scenario: skipping removes this task from today while leaving a high-priority commitment unresolved.')
            : (spanish
                  ? 'Escenario: omitir quita esta tarea de hoy pero deja sin resolver el compromiso registrado.'
                  : 'Scenario: skipping removes this task from today while leaving its recorded commitment unresolved.'),
        assumptions: <String>[
          spanish
              ? 'Ninguna tarea alternativa satisface el mismo compromiso.'
              : 'No replacement task satisfies the same commitment.',
          ...userAssumptions,
        ],
        evidenceIds: citations,
      ),
    ];
  }

  String _directAnswer({
    required _SIV2Question question,
    required SIV2TaskEvidence? focusTask,
    required SIV2GoalEvidence? focusGoal,
    required SIV2MilestoneEvidence? focusMilestone,
    required SIV2TimelineEvidence? focusTimeline,
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required List<SIV2TimelineEvidence> timeline,
    required List<SIV2Conflict> conflicts,
    required List<SIV2Scenario> scenarios,
    required DateTime now,
    required List<String> missingInformation,
    required int totalMatched,
  }) {
    if (question.focus == _SIV2QuestionFocus.evidenceGaps) {
      return missingInformation.isEmpty
          ? 'No evidence gaps were identified in the selected lens.'
          : 'The selected lens has these missing or conflicting items: ${missingInformation.join(' ')}';
    }
    if (totalMatched == 0) {
      return switch (question.focus) {
        _SIV2QuestionFocus.counterfactual =>
          'The answer would change if the lens exposed a relevant dated or prioritized active task.',
        _SIV2QuestionFocus.forecast =>
          'No matched task supports the do, defer, and skip scenario requested in your question.',
        _SIV2QuestionFocus.comparison =>
          'The selected lens does not contain two matched records for the comparison you asked for.',
        _SIV2QuestionFocus.conflict =>
          'No explicit schedule, goal-link, or milestone-dependency conflict matching your question was found.',
        _SIV2QuestionFocus.progress =>
          'No milestone completion record matched, so SI cannot determine progress from this lens.',
        _SIV2QuestionFocus.unsupported =>
          'SI cannot answer that question from saved tasks, goals, milestones, or Timeline records. It will not substitute an unrelated planning report.',
        _ =>
          'No saved evidence item matched the selected sources, date range, and entity filter, so SI cannot answer this question from app data.',
      };
    }
    switch (question.focus) {
      case _SIV2QuestionFocus.nextAction:
        if (focusTask != null) {
          if (question.availableMinutes case final int minutes) {
            return 'Use the available $minutes ${minutes == 1 ? 'minute' : 'minutes'} to start one bounded part of "${focusTask.title}". SI does not know the full task duration, so this is a start, not a promise to finish it.';
          }
          final dateBasis =
              focusTask.dueDate != null || focusTask.scheduledFor != null
              ? 'recorded date, '
              : '';
          return 'For the next action you asked about, "${focusTask.title}" ranks first from its title relevance, ${dateBasis}and priority ${focusTask.priority}/5.';
        }
        final int goalMatch = focusGoal == null
            ? 0
            : question.titleScore(focusGoal.title);
        final int milestoneMatch = focusMilestone == null
            ? 0
            : question.titleScore(focusMilestone.title);
        if (focusGoal != null && goalMatch > milestoneMatch) {
          return 'No active task is linked in this lens, so the next grounded decision is to identify an action for goal "${focusGoal.title}".';
        }
        if (focusMilestone != null) {
          return 'No active task matched, but milestone "${focusMilestone.title}" is the clearest recorded place to inspect next.';
        }
        if (focusGoal != null) {
          return 'No active task matched, so the nearest grounded next decision is to identify an action for goal "${focusGoal.title}".';
        }
        return '$totalMatched evidence items matched, but none contains a task-level next action.';
      case _SIV2QuestionFocus.urgency:
        if (focusTask != null) {
          final DateTime? date = focusTask.dueDate ?? focusTask.scheduledFor;
          return '"${focusTask.title}" has the strongest urgency signal: priority ${focusTask.priority}/5 and ${_timingLabel(date, now)}.';
        }
        if (goals.length >= 2 && question.sourceHint != SIV2Source.milestones) {
          return _comparisonAnswer(
            question: question,
            tasks: const <SIV2TaskEvidence>[],
            goals: goals,
            milestones: milestones,
            now: now,
          );
        }
        if (focusGoal != null) {
          return 'Goal "${focusGoal.title}" has the strongest available urgency signal with ${_goalTargetLabel(focusGoal.targetDate, now)}.';
        }
        if (focusMilestone != null) {
          return 'Milestone "${focusMilestone.title}" has the strongest available urgency signal with ${_targetLabel(focusMilestone.targetDate, now)}.';
        }
        return 'The current evidence has no recorded date or priority signal that can answer which item is urgent.';
      case _SIV2QuestionFocus.workload:
        final int highPriority = tasks
            .where((SIV2TaskEvidence task) => task.priority >= 4)
            .length;
        final int datedWithinWeek = tasks.where((SIV2TaskEvidence task) {
          final DateTime? date = task.dueDate ?? task.scheduledFor;
          return date != null &&
              !date.toUtc().isAfter(now.add(const Duration(days: 7)));
        }).length;
        return 'The selected lens contains ${tasks.length} active task${tasks.length == 1 ? '' : 's'}: $highPriority high-priority and $datedWithinWeek recorded as due, scheduled, or overdue within seven days.';
      case _SIV2QuestionFocus.progress:
        final List<SIV2MilestoneEvidence> relevantMilestones = focusGoal == null
            ? focusMilestone == null
                  ? milestones
                  : <SIV2MilestoneEvidence>[focusMilestone]
            : milestones
                  .where(
                    (SIV2MilestoneEvidence item) => item.goalId == focusGoal.id,
                  )
                  .toList(growable: false);
        if (relevantMilestones.isEmpty) {
          final String subject = focusGoal == null
              ? 'the matched evidence'
              : 'goal "${focusGoal.title}"';
          return 'No milestone completion record is available for $subject, so SI cannot determine progress from the current lens.';
        }
        final double average =
            relevantMilestones
                .map((SIV2MilestoneEvidence item) => item.completionPercent)
                .reduce((double left, double right) => left + right) /
            relevantMilestones.length;
        final int completed = relevantMilestones
            .where((SIV2MilestoneEvidence item) => item.completed)
            .length;
        final String subject = focusGoal == null
            ? 'the matched milestone set'
            : 'goal "${focusGoal.title}"';
        return '$subject has ${relevantMilestones.length} recorded milestone${relevantMilestones.length == 1 ? '' : 's'}, $completed complete, with ${average.round()}% average recorded completion.';
      case _SIV2QuestionFocus.goalAlignment:
        if (focusTask?.goalId != null && focusGoal != null) {
          return 'Task "${focusTask!.title}" is explicitly linked to goal "${focusGoal.title}" in saved app data.';
        }
        if (focusGoal != null) {
          final int linkedTasks = tasks
              .where((SIV2TaskEvidence task) => task.goalId == focusGoal.id)
              .length;
          final int linkedMilestones = milestones
              .where(
                (SIV2MilestoneEvidence milestone) =>
                    milestone.goalId == focusGoal.id,
              )
              .length;
          return 'Goal "${focusGoal.title}" has $linkedTasks linked active task${linkedTasks == 1 ? '' : 's'} and $linkedMilestones linked milestone${linkedMilestones == 1 ? '' : 's'} in the current lens.';
        }
        return 'No task-to-goal or milestone-to-goal link in the current lens answers the alignment question.';
      case _SIV2QuestionFocus.schedule:
        if (focusTask != null) {
          return 'The relevant saved task is "${focusTask.title}", with ${_timingLabel(focusTask.dueDate ?? focusTask.scheduledFor, now)}.';
        }
        if (focusTimeline != null) {
          return 'The relevant Timeline record is "${focusTimeline.title}" from ${_dateLabel(focusTimeline.timestamp)} with status "${focusTimeline.status}".';
        }
        return 'No matched task or Timeline record contains a date that answers the scheduling question.';
      case _SIV2QuestionFocus.comparison:
        return _comparisonAnswer(
          question: question,
          tasks: tasks,
          goals: goals,
          milestones: milestones,
          now: now,
        );
      case _SIV2QuestionFocus.explanation:
        final SIV2Conflict? conflict = _relevantConflict(
          conflicts,
          question: question,
          task: focusTask,
          goal: focusGoal,
          milestone: focusMilestone,
          fallbackToAny: !_questionNamesFocus(
            question,
            task: focusTask,
            goal: focusGoal,
            milestone: focusMilestone,
          ),
        );
        if (conflict != null) {
          return '${conflict.summary} That recorded conflict is the clearest evidence-backed explanation for the risk in your question.';
        }
        if (focusTask != null) {
          final DateTime? savedTime =
              focusTask.dueDate ?? focusTask.scheduledFor;
          final timing = savedTime == null
              ? 'no saved due or scheduled time is available for this task'
              : 'its saved timing is ${_timingLabel(savedTime, now)}';
          final userDateLimit = savedTime == null
              ? ' A date supplied only in your question is not a saved task date.'
              : '';
          return '"${focusTask.title}" ranks where it does because its saved title matches the question and its recorded priority is ${focusTask.priority}/5; $timing.$userDateLimit No causal explanation beyond those fields is stored.';
        }
        return 'The current evidence contains no recorded conflict or causal field that can explain why this happened.';
      case _SIV2QuestionFocus.forecast:
        return scenarios.isEmpty
            ? 'No matched task supports the do, defer, and skip scenario requested in your question.'
            : 'Three bounded scenarios were calculated for "${focusTask!.title}" in response to your defer-or-change question; they are conditional, not predictions.';
      case _SIV2QuestionFocus.conflict:
        final SIV2Conflict? conflict = _relevantConflict(
          conflicts,
          question: question,
          task: focusTask,
          goal: focusGoal,
          milestone: focusMilestone,
          fallbackToAny: !_questionNamesFocus(
            question,
            task: focusTask,
            goal: focusGoal,
            milestone: focusMilestone,
          ),
        );
        return conflict == null
            ? 'No explicit schedule, goal-link, or milestone-dependency conflict matching your question was found.'
            : '${conflict.summary} ${conflicts.length == 1 ? 'This is the only explicit conflict in the lens.' : '${conflicts.length - 1} other explicit conflict(s) are also present.'}';
      case _SIV2QuestionFocus.counterfactual:
        return focusTask == null
            ? 'The answer would change if the selected lens exposed a relevant dated or prioritized active task.'
            : 'For "${focusTask.title}", the answer would change if another relevant task gained an earlier due date, higher priority, or blocking dependency.';
      case _SIV2QuestionFocus.timeline:
        return focusTimeline == null
            ? 'No Timeline record matches the event or history question in the current lens.'
            : 'Timeline records "${focusTimeline.title}" at ${_dateLabel(focusTimeline.timestamp)} with type "${focusTimeline.type}" and status "${focusTimeline.status}".';
      case _SIV2QuestionFocus.evidenceGaps:
        return missingInformation.isEmpty
            ? 'No evidence gaps were identified in the selected lens.'
            : 'The selected lens has these missing or conflicting items: ${missingInformation.join(' ')}';
      case _SIV2QuestionFocus.overview:
        if (question.requestsListing) {
          final List<String> titles = switch (question.sourceHint) {
            SIV2Source.goals => goals.map((item) => item.title).toList(),
            SIV2Source.tasks => tasks.map((item) => item.title).toList(),
            SIV2Source.milestones =>
              milestones.map((item) => item.title).toList(),
            _ => const <String>[],
          };
          final String label = question.sourceHint?.name ?? 'items';
          if (titles.isEmpty) {
            return 'No saved $label match the current evidence lens.';
          }
          return '${titles.length} saved $label match the current evidence lens:\n'
              '${titles.take(20).map((title) => '\u2022 $title').join('\n')}'
              '${titles.length > 20 ? '\nShowing the first 20; narrow the lens to inspect the rest.' : ''}';
        }
        if (focusTask != null && question.titleScore(focusTask.title) > 0) {
          return 'Your question most closely matches saved task "${focusTask.title}", recorded at priority ${focusTask.priority}/5 with ${_timingLabel(focusTask.dueDate ?? focusTask.scheduledFor, now)}.';
        }
        return '$totalMatched evidence item${totalMatched == 1 ? '' : 's'} matched. Ask about the next action, urgency, workload, progress, schedule, goal alignment, conflicts, or a named saved item for a more specific answer.';
      case _SIV2QuestionFocus.unsupported:
        return 'SI cannot answer that question from saved tasks, goals, milestones, or Timeline records. It will not substitute an unrelated planning report.';
    }
  }

  String _recommendation({
    required _SIV2Question question,
    required SIV2TaskEvidence? focusTask,
    required SIV2GoalEvidence? focusGoal,
    required SIV2MilestoneEvidence? focusMilestone,
    required SIV2TimelineEvidence? focusTimeline,
    required List<SIV2Conflict> conflicts,
  }) {
    final String noMutation = ' SI has not changed any saved data.';
    switch (question.focus) {
      case _SIV2QuestionFocus.progress:
        if (focusMilestone != null) {
          return 'Inspect milestone "${focusMilestone.title}" and decide whether its ${focusMilestone.completionPercent.round()}% record is still accurate.$noMutation';
        }
        if (focusGoal != null) {
          return 'Review the milestones linked to "${focusGoal.title}" before deciding the next action.$noMutation';
        }
        break;
      case _SIV2QuestionFocus.goalAlignment:
        if (focusGoal != null) {
          return 'Review the explicit links under goal "${focusGoal.title}" and decide whether the current task set still supports it.$noMutation';
        }
        break;
      case _SIV2QuestionFocus.timeline:
      case _SIV2QuestionFocus.schedule:
        if (focusTimeline != null && focusTask == null) {
          return 'Open Timeline record "${focusTimeline.title}" to verify its recorded status before acting.$noMutation';
        }
        break;
      case _SIV2QuestionFocus.explanation:
      case _SIV2QuestionFocus.conflict:
        if (conflicts.isNotEmpty) {
          return 'Inspect the cited conflict and correct the underlying date, link, or dependency only if the saved evidence is wrong.$noMutation';
        }
        break;
      case _SIV2QuestionFocus.unsupported:
        return 'Ask a planning question that can be checked against tasks, goals, milestones, or Timeline; SI will not invent an answer.';
      case _SIV2QuestionFocus.evidenceGaps:
        return 'Review the named evidence gaps before relying on this lens for a planning decision.$noMutation';
      case _SIV2QuestionFocus.workload:
      case _SIV2QuestionFocus.urgency:
      case _SIV2QuestionFocus.nextAction:
      case _SIV2QuestionFocus.comparison:
      case _SIV2QuestionFocus.forecast:
      case _SIV2QuestionFocus.counterfactual:
      case _SIV2QuestionFocus.overview:
        if (question.requestsListing) {
          return 'Review the listed saved records; narrow the evidence lens if needed.$noMutation';
        }
        break;
    }
    if (focusTask != null) {
      if (question.availableMinutes case final int minutes) {
        return 'Choose a stopping point that fits $minutes ${minutes == 1 ? 'minute' : 'minutes'}, then start that part of "${focusTask.title}". Review or defer the rest explicitly.$noMutation';
      }
      return 'Review "${focusTask.title}" first, then explicitly choose whether to act, defer, edit, or reject the recommendation.$noMutation';
    }
    if (focusGoal != null) {
      return 'Review goal "${focusGoal.title}" and choose its next concrete task in Creator.$noMutation';
    }
    if (focusMilestone != null) {
      return 'Review milestone "${focusMilestone.title}" before deciding what should happen next.$noMutation';
    }
    return 'Broaden the selected evidence sources or date range; the current lens does not support a grounded recommendation.$noMutation';
  }

  SIV2TaskEvidence? _selectFocusTask(
    List<SIV2TaskEvidence> tasks,
    _SIV2Question question,
  ) {
    if (tasks.isEmpty) return null;
    final List<SIV2TaskEvidence> ranked =
        tasks.where((task) => question.matchesNamedTask(task.title)).toList()
          ..sort((SIV2TaskEvidence left, SIV2TaskEvidence right) {
            final int relevanceOrder = question
                .titleScore(right.title)
                .compareTo(question.titleScore(left.title));
            if (relevanceOrder != 0) return relevanceOrder;
            if (question.ranksByPriority) {
              final int priorityOrder = right.priority.compareTo(left.priority);
              if (priorityOrder != 0) return priorityOrder;
            }
            final DateTime leftDate =
                left.dueDate ??
                left.scheduledFor ??
                DateTime.fromMillisecondsSinceEpoch(
                  8640000000000000,
                  isUtc: true,
                );
            final DateTime rightDate =
                right.dueDate ??
                right.scheduledFor ??
                DateTime.fromMillisecondsSinceEpoch(
                  8640000000000000,
                  isUtc: true,
                );
            final int dateOrder = leftDate.compareTo(rightDate);
            if (dateOrder != 0) return dateOrder;
            final int priorityOrder = right.priority.compareTo(left.priority);
            if (priorityOrder != 0) return priorityOrder;
            return left.title.toLowerCase().compareTo(
              right.title.toLowerCase(),
            );
          });
    return ranked.firstOrNull;
  }

  SIV2GoalEvidence? _selectFocusGoal(
    List<SIV2GoalEvidence> goals,
    _SIV2Question question,
  ) {
    if (goals.isEmpty) return null;
    final List<SIV2GoalEvidence> ranked = List<SIV2GoalEvidence>.of(goals)
      ..sort((SIV2GoalEvidence left, SIV2GoalEvidence right) {
        final int relevanceOrder = question
            .titleScore(right.title)
            .compareTo(question.titleScore(left.title));
        if (relevanceOrder != 0) return relevanceOrder;
        return _compareGoalTargets(left.targetDate, right.targetDate);
      });
    return ranked.first;
  }

  SIV2MilestoneEvidence? _selectFocusMilestone(
    List<SIV2MilestoneEvidence> milestones,
    _SIV2Question question,
  ) {
    if (milestones.isEmpty) return null;
    final List<SIV2MilestoneEvidence> ranked =
        List<SIV2MilestoneEvidence>.of(milestones)
          ..sort((SIV2MilestoneEvidence left, SIV2MilestoneEvidence right) {
            final int relevanceOrder = question
                .titleScore(right.title)
                .compareTo(question.titleScore(left.title));
            if (relevanceOrder != 0) return relevanceOrder;
            final int completionOrder = left.completionPercent.compareTo(
              right.completionPercent,
            );
            if (completionOrder != 0) return completionOrder;
            final DateTime leftDate = left.targetDate ?? _farFuture;
            final DateTime rightDate = right.targetDate ?? _farFuture;
            return leftDate.compareTo(rightDate);
          });
    return ranked.first;
  }

  SIV2TimelineEvidence? _selectFocusTimeline(
    List<SIV2TimelineEvidence> timeline,
    _SIV2Question question,
    DateTime now,
  ) {
    if (timeline.isEmpty) return null;
    final List<SIV2TimelineEvidence> ranked =
        List<SIV2TimelineEvidence>.of(timeline)
          ..sort((SIV2TimelineEvidence left, SIV2TimelineEvidence right) {
            final int relevanceOrder = question
                .titleScore(right.title)
                .compareTo(question.titleScore(left.title));
            if (relevanceOrder != 0) return relevanceOrder;
            final Duration leftDistance = now
                .difference(left.timestamp.toUtc())
                .abs();
            final Duration rightDistance = now
                .difference(right.timestamp.toUtc())
                .abs();
            return leftDistance.compareTo(rightDistance);
          });
    return ranked.first;
  }

  String _comparisonAnswer({
    required _SIV2Question question,
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required DateTime now,
  }) {
    if (question.sourceHint == SIV2Source.tasks ||
        (question.sourceHint == null && tasks.length >= 2)) {
      if (tasks.length < 2) {
        return 'A grounded task comparison needs at least two matched tasks; ${tasks.length} is available.';
      }
      final List<SIV2TaskEvidence> ranked = List<SIV2TaskEvidence>.of(tasks)
        ..sort((SIV2TaskEvidence left, SIV2TaskEvidence right) {
          final int relevanceOrder = question
              .titleScore(right.title)
              .compareTo(question.titleScore(left.title));
          if (relevanceOrder != 0) return relevanceOrder;
          final DateTime leftDate =
              left.dueDate ?? left.scheduledFor ?? _farFuture;
          final DateTime rightDate =
              right.dueDate ?? right.scheduledFor ?? _farFuture;
          final int dateOrder = leftDate.compareTo(rightDate);
          if (dateOrder != 0) return dateOrder;
          return right.priority.compareTo(left.priority);
        });
      final SIV2TaskEvidence first = ranked[0];
      final SIV2TaskEvidence second = ranked[1];
      return '"${first.title}" ranks ahead of "${second.title}" for this question: ${_timingLabel(first.dueDate ?? first.scheduledFor, now)}, priority ${first.priority}/5, versus ${_timingLabel(second.dueDate ?? second.scheduledFor, now)}, priority ${second.priority}/5.';
    }
    if (question.sourceHint == SIV2Source.milestones) {
      if (milestones.length < 2) {
        return 'A grounded milestone comparison needs at least two matched milestones; ${milestones.length} is available.';
      }
      final List<SIV2MilestoneEvidence> ranked =
          List<SIV2MilestoneEvidence>.of(milestones)..sort(
            (SIV2MilestoneEvidence left, SIV2MilestoneEvidence right) =>
                question
                    .titleScore(right.title)
                    .compareTo(question.titleScore(left.title)),
          );
      return '"${ranked[0].title}" is recorded at ${ranked[0].completionPercent.round()}% completion; "${ranked[1].title}" is at ${ranked[1].completionPercent.round()}%.';
    }
    if (goals.length < 2) {
      return 'A grounded goal comparison needs at least two matched goals; ${goals.length} is available.';
    }
    final List<SIV2GoalEvidence> ranked = List<SIV2GoalEvidence>.of(goals)
      ..sort((SIV2GoalEvidence left, SIV2GoalEvidence right) {
        final int relevanceOrder = question
            .titleScore(right.title)
            .compareTo(question.titleScore(left.title));
        if (relevanceOrder != 0) return relevanceOrder;
        return _compareGoalTargets(left.targetDate, right.targetDate);
      });
    final SIV2GoalEvidence first = ranked[0];
    final SIV2GoalEvidence second = ranked[1];
    if (question.titleScore(first.title) != question.titleScore(second.title)) {
      return '"${first.title}" ranks ahead of "${second.title}" because its title more closely matches this question. Recorded targets: ${_goalTargetLabel(first.targetDate, now)} versus ${_goalTargetLabel(second.targetDate, now)}; dates did not decide this ordering.';
    }
    if (_compareGoalTargets(first.targetDate, second.targetDate) != 0) {
      return '"${first.title}" ranks ahead of "${second.title}" because title relevance is tied and its recorded target is ${_goalTargetLabel(first.targetDate, now)} versus ${_goalTargetLabel(second.targetDate, now)}.';
    }
    return '"${first.title}" and "${second.title}" are tied on title relevance and recorded targets (${_goalTargetLabel(first.targetDate, now)}). These signals do not establish a higher priority for either goal.';
  }

  SIV2Conflict? _relevantConflict(
    List<SIV2Conflict> conflicts, {
    required _SIV2Question question,
    required SIV2TaskEvidence? task,
    required SIV2GoalEvidence? goal,
    required SIV2MilestoneEvidence? milestone,
    required bool fallbackToAny,
  }) {
    if (conflicts.isEmpty) return null;
    final Set<String> allFocusIds = <String>{
      if (task != null) 'tasks:${task.id}',
      if (goal != null) 'goals:${goal.id}',
      if (milestone != null) 'milestones:${milestone.id}',
    };
    final Set<String> namedFocusIds = <String>{
      if (task != null && question.titleScore(task.title) > 0)
        'tasks:${task.id}',
      if (goal != null && question.titleScore(goal.title) > 0)
        'goals:${goal.id}',
      if (milestone != null && question.titleScore(milestone.title) > 0)
        'milestones:${milestone.id}',
    };
    final Set<String> focusIds = namedFocusIds.isEmpty
        ? allFocusIds
        : namedFocusIds;
    for (final SIV2Conflict conflict in conflicts) {
      if (conflict.evidenceIds.any(focusIds.contains)) return conflict;
    }
    return fallbackToAny ? conflicts.first : null;
  }

  bool _questionNamesFocus(
    _SIV2Question question, {
    required SIV2TaskEvidence? task,
    required SIV2GoalEvidence? goal,
    required SIV2MilestoneEvidence? milestone,
  }) {
    return (task != null && question.titleScore(task.title) > 0) ||
        (goal != null && question.titleScore(goal.title) > 0) ||
        (milestone != null && question.titleScore(milestone.title) > 0);
  }

  String _timingLabel(DateTime? date, DateTime now) {
    if (date == null) return 'no saved due or scheduled date';
    final bool dateOnly =
        date.hour == 0 &&
        date.minute == 0 &&
        date.second == 0 &&
        date.millisecond == 0 &&
        date.microsecond == 0;
    final bool past = dateOnly
        ? _localDay(date).isBefore(_localDay(now))
        : date.toLocal().isBefore(now.toLocal());
    if (past) return 'recorded date ${_dateLabel(date)}, now past';
    return 'recorded date ${_dateLabel(date)}';
  }

  String _targetLabel(DateTime? date, DateTime now) {
    if (date == null) return 'no saved target date';
    final DateTime utc = date.toUtc();
    return utc.isBefore(now)
        ? 'target ${_dateLabel(utc)}, now past'
        : 'target ${_dateLabel(utc)}';
  }

  // Goal targets are local calendar dates, like Home and Timeline. UTC here
  // is only a day key, so comparing days remains safe across DST transitions.
  DateTime _localDay(DateTime value) {
    if (value.hour == 0 &&
        value.minute == 0 &&
        value.second == 0 &&
        value.millisecond == 0 &&
        value.microsecond == 0) {
      return DateTime.utc(value.year, value.month, value.day);
    }
    final local = value.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  int _compareGoalTargets(DateTime? left, DateTime? right) {
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return _localDay(left).compareTo(_localDay(right));
  }

  String _goalTargetLabel(DateTime? date, DateTime now) {
    if (date == null) return 'no saved target date';
    final day = _localDay(date);
    final order = day.compareTo(_localDay(now));
    final suffix = order < 0 ? ', now past' : (order == 0 ? ', due today' : '');
    return 'target ${_dateLabel(day)}$suffix';
  }

  bool _withinGoalRange(
    DateTime? date,
    SIV2TimeRange range,
    DateTime now, {
    required bool undatedMatches,
  }) {
    if (range == SIV2TimeRange.all) return true;
    if (date == null) return undatedMatches;
    final day = _localDay(date);
    final start = _localDay(now);
    if (day.isBefore(start)) return true;
    return _withinRange(day, range, start, undatedMatches: undatedMatches);
  }

  String _dateLabel(DateTime value) {
    final bool dayKey =
        value.isUtc &&
        value.hour == 0 &&
        value.minute == 0 &&
        value.second == 0 &&
        value.millisecond == 0 &&
        value.microsecond == 0;
    final display = dayKey ? value : value.toLocal();
    return display.toIso8601String().split('T').first;
  }

  bool _taskIsOverdue(SIV2TaskEvidence task, DateTime now) {
    final due = task.dueDate;
    if (due == null) return false;
    final bool dateOnly =
        due.hour == 0 &&
        due.minute == 0 &&
        due.second == 0 &&
        due.millisecond == 0 &&
        due.microsecond == 0;
    return dateOnly
        ? _localDay(due).isBefore(_localDay(now))
        : due.toLocal().isBefore(now.toLocal());
  }

  bool _withinTaskRange(
    SIV2TaskEvidence task,
    SIV2TimeRange range,
    DateTime now,
  ) {
    if (range == SIV2TimeRange.all) return true;
    if (_taskIsOverdue(task, now)) return true;
    final dates = <DateTime?>[
      task.scheduledFor,
      task.dueDate,
    ].whereType<DateTime>();
    if (dates.isEmpty) return true;
    return dates.any(
      (date) => _withinRange(date, range, now, undatedMatches: false),
    );
  }

  bool _withinDeadlineRange(
    DateTime? date,
    SIV2TimeRange range,
    DateTime now, {
    required bool undatedMatches,
  }) {
    if (date != null && date.toUtc().isBefore(now)) {
      return true;
    }
    return _withinRange(date, range, now, undatedMatches: undatedMatches);
  }

  bool _withinTimelineRange(
    SIV2TimelineEvidence event,
    SIV2TimeRange range,
    DateTime now,
  ) {
    if (range == SIV2TimeRange.all) return true;
    final DateTime date = event.dueAt ?? event.timestamp;
    final Duration pastAge = now.difference(date.toUtc());
    if (!pastAge.isNegative) {
      final int days = switch (range) {
        SIV2TimeRange.today => 1,
        SIV2TimeRange.sevenDays => 7,
        SIV2TimeRange.thirtyDays => 30,
        SIV2TimeRange.all => 365000,
      };
      return pastAge <= Duration(days: days);
    }
    return _withinRange(date, range, now, undatedMatches: false);
  }

  bool _withinRange(
    DateTime? date,
    SIV2TimeRange range,
    DateTime now, {
    required bool undatedMatches,
  }) {
    if (range == SIV2TimeRange.all) return true;
    if (date == null) return undatedMatches;
    final DateTime start = _localDay(now);
    final int days = switch (range) {
      SIV2TimeRange.today => 1,
      SIV2TimeRange.sevenDays => 7,
      SIV2TimeRange.thirtyDays => 30,
      SIV2TimeRange.all => 365000,
    };
    final DateTime end = start.add(Duration(days: days));
    final DateTime day = _localDay(date);
    return !day.isBefore(start) && day.isBefore(end);
  }
}

enum _SIV2QuestionFocus {
  nextAction,
  urgency,
  workload,
  progress,
  goalAlignment,
  schedule,
  comparison,
  explanation,
  forecast,
  conflict,
  counterfactual,
  timeline,
  evidenceGaps,
  overview,
  unsupported,
}

final class _SIV2Question {
  const _SIV2Question({
    required this.focus,
    required this.sourceHint,
    required this.normalizedInput,
    required this.currentTerms,
    required this.priorTerms,
    required this.hasPriorContext,
    required this.requestsListing,
    required this.namedTaskPhrase,
    required this.scenarioAssumptions,
  });

  factory _SIV2Question.parse(SIV2Query query) {
    final String current = _normalizeQuestion(query.rawText);
    final String prior = query.usesPriorDecisionContext
        ? _normalizeQuestion(query.priorUserTurns.join(' '))
        : '';
    final String filter = _normalizeQuestion(query.entityFilter ?? '');
    final String? namedTaskPhrase = query.requestsListing
        ? null
        : _namedTaskPhrase(current);
    return _SIV2Question(
      focus: query.requestsListing
          ? _SIV2QuestionFocus.overview
          : _focusFor(current, query.intent),
      sourceHint: _sourceFor(current) ?? _sourceFor('$prior $filter'.trim()),
      normalizedInput: current,
      currentTerms: _questionTerms('$current $filter'),
      priorTerms: _questionTerms(prior),
      hasPriorContext: query.usesPriorDecisionContext,
      requestsListing: query.requestsListing,
      namedTaskPhrase: namedTaskPhrase,
      scenarioAssumptions: query.assumptions.join(' '),
    );
  }

  final _SIV2QuestionFocus focus;
  final SIV2Source? sourceHint;
  final String normalizedInput;
  final Set<String> currentTerms;
  final Set<String> priorTerms;
  final bool hasPriorContext;
  final bool requestsListing;
  final String? namedTaskPhrase;
  final String scenarioAssumptions;

  bool matchesNamedTask(String title) {
    final phrase = namedTaskPhrase;
    if (phrase == null) return true;
    final Set<String> requested = _questionTerms(phrase);
    final Set<String> titleTerms = _questionTerms(_normalizeQuestion(title));
    if (requested.length < 2) return true;
    return requested.difference(titleTerms).isEmpty;
  }

  static String? _namedTaskPhrase(String input) {
    final match = RegExp(
      r'^(?:why does|why is|how does|por que)\s+(.+?)\s+(?:rank(?:s)?(?: here)?|se prioriza|tiene prioridad|ocupa este lugar)\b',
    ).firstMatch(input);
    if (match == null) return null;
    final phrase = match
        .group(1)!
        .replaceFirst(RegExp(r'^(?:the|my|a|la|el|mi|una?)\s+'), '');
    return _questionTerms(phrase).length >= 2 ? phrase : null;
  }

  bool get isSpanish => RegExp(
    r'\b(que|cual|cuales|deberia|hacer|despues|necesita|atencion|meta|metas|tarea|tareas|hito|hitos|hoy|manana|posponer|retrasar|conflicto|explica)\b',
  ).hasMatch(normalizedInput);

  bool get ranksByPriority =>
      normalizedInput.contains('highest priority') ||
      normalizedInput.contains('prioridad mas alta') ||
      normalizedInput.contains('mayor prioridad');

  int get deferDays {
    final match =
        RegExp(
          r'\b(\d+)\s*(?:day|days|dia|dias)\b',
        ).firstMatch(normalizedInput) ??
        RegExp(
          r'\b(?:defer|delay|postpone|posponer|pospongo|retrasar|retraso)\b[^.!?]*?\b(\d+)\s*(?:days?|d[ií]as?)\b',
          caseSensitive: false,
        ).firstMatch(scenarioAssumptions);
    return int.tryParse(match?.group(1) ?? '')?.clamp(1, 365) ?? 1;
  }

  int? get availableMinutes {
    final match = RegExp(
      r'\b(?:only\s+have|have|in|for|tengo|solo\s+tengo|en|durante)\s+(\d+)\s*(?:minute|minutes|minuto|minutos)\b',
    ).firstMatch(normalizedInput);
    return int.tryParse(match?.group(1) ?? '');
  }

  bool excludes(String title) {
    final normalizedTitle = _normalizeQuestion(title);
    if (normalizedTitle.isEmpty) return false;
    return <String>[
      'not $normalizedTitle',
      'except $normalizedTitle',
      'exclude $normalizedTitle',
      'no $normalizedTitle',
      'excepto $normalizedTitle',
      'excluye $normalizedTitle',
    ].any(normalizedInput.contains);
  }

  int titleScore(String title) {
    final Set<String> titleTerms = _questionTokens(title);
    int matches(Set<String> terms) {
      int score = 0;
      for (final String term in terms) {
        for (final String titleTerm in titleTerms) {
          if (term == titleTerm) {
            score += 4;
            break;
          }
          if (term.length >= 4 &&
              titleTerm.length >= 4 &&
              (term.startsWith(titleTerm) || titleTerm.startsWith(term))) {
            score += 2;
            break;
          }
        }
      }
      return score;
    }

    return matches(currentTerms) * 4 + matches(priorTerms);
  }

  SIV2Statement? entityMatchStatement({
    required SIV2TaskEvidence? task,
    required SIV2GoalEvidence? goal,
    required SIV2MilestoneEvidence? milestone,
    required SIV2TimelineEvidence? timeline,
  }) {
    final List<_SIV2QuestionMatch> matches = <_SIV2QuestionMatch>[];
    void add({
      required String title,
      required String evidenceId,
      required String kind,
      required SIV2Source source,
    }) {
      final int relevance = titleScore(title);
      if (relevance <= 0) return;
      matches.add(
        _SIV2QuestionMatch(
          title: title,
          evidenceId: evidenceId,
          kind: kind,
          score: relevance + (sourceHint == source ? 1 : 0),
        ),
      );
    }

    if (task != null) {
      add(
        title: task.title,
        evidenceId: 'tasks:${task.id}',
        kind: 'task',
        source: SIV2Source.tasks,
      );
    }
    if (goal != null) {
      add(
        title: goal.title,
        evidenceId: 'goals:${goal.id}',
        kind: 'goal',
        source: SIV2Source.goals,
      );
    }
    if (milestone != null) {
      add(
        title: milestone.title,
        evidenceId: 'milestones:${milestone.id}',
        kind: 'milestone',
        source: SIV2Source.milestones,
      );
    }
    if (timeline != null) {
      add(
        title: timeline.title,
        evidenceId: 'timeline:${timeline.id}',
        kind: 'Timeline record',
        source: SIV2Source.timeline,
      );
    }
    if (matches.isEmpty) return null;
    matches.sort(
      (_SIV2QuestionMatch left, _SIV2QuestionMatch right) =>
          right.score.compareTo(left.score),
    );
    final _SIV2QuestionMatch best = matches.first;
    return SIV2Statement(
      kind: SIV2StatementKind.inference,
      text:
          'The wording in ${hasPriorContext ? 'the current question and recent user context' : 'the current question'} most closely matches saved ${best.kind} "${best.title}".',
      evidenceIds: <String>[best.evidenceId],
    );
  }

  static _SIV2QuestionFocus _focusFor(String input, SIV2Intent intent) {
    final bool asksForWeather = RegExp(
      r'^(?:(?:will|does|did|is) it (?:rain|snow|hail|storm)\b|'
      r'(?:what(?: s| is| will(?: be)?)?|how(?: s| is)?) (?:the )?(?:weather|temperature)\b|'
      r'(?:the )?weather(?: forecast)?\b|(?:forecast|predict) (?:the )?weather\b)',
    ).hasMatch(input);
    if (asksForWeather) {
      return _SIV2QuestionFocus.unsupported;
    }
    if (intent != SIV2Intent.answer) {
      return switch (intent) {
        SIV2Intent.answer => _SIV2QuestionFocus.overview,
        SIV2Intent.explain => _SIV2QuestionFocus.explanation,
        SIV2Intent.compare => _SIV2QuestionFocus.comparison,
        SIV2Intent.forecast => _SIV2QuestionFocus.forecast,
        SIV2Intent.findConflict => _SIV2QuestionFocus.conflict,
        SIV2Intent.counterfactual => _SIV2QuestionFocus.counterfactual,
      };
    }
    bool hasAny(List<String> patterns) => patterns.any(input.contains);
    if (input.contains('missing') && input.contains('evidence')) {
      return _SIV2QuestionFocus.evidenceGaps;
    }
    if (hasAny(<String>['what would change', 'counterfactual'])) {
      return _SIV2QuestionFocus.counterfactual;
    }
    if (hasAny(<String>[
      'what happens',
      'que pasa',
      'if i defer',
      'if i delay',
      'si pospongo',
      'si retraso',
      'forecast',
      'scenario',
    ])) {
      return _SIV2QuestionFocus.forecast;
    }
    if (hasAny(<String>[
      'overload',
      'overwhelm',
      'too much',
      'too many',
      'workload',
      'capacity',
      'how busy',
      'how many tasks',
      'how many commitments',
      'demasiado trabajo',
      'sobrecarga',
      'capacidad',
      'cuantas tareas',
    ])) {
      return _SIV2QuestionFocus.workload;
    }
    if (hasAny(<String>[
      'what happened',
      'timeline',
      'history',
      'last event',
      'recent event',
      'que paso',
      'historial',
      'ultimo evento',
    ])) {
      return _SIV2QuestionFocus.timeline;
    }
    if (hasAny(<String>[
      'conflict',
      'contradict',
      'overlap',
      'dependency',
      'blocked by',
      'collide',
      'conflicto',
      'contradic',
      'superpone',
    ])) {
      return _SIV2QuestionFocus.conflict;
    }
    if (hasAny(<String>[
      'compare',
      ' versus ',
      ' vs ',
      'between',
      'compara',
      'comparar',
      'entre',
    ])) {
      return _SIV2QuestionFocus.comparison;
    }
    if (hasAny(<String>[
      'progress',
      'on track',
      'where do i stand',
      'how far',
      'completion',
      'completed',
      'status',
      'progreso',
      'como voy',
      'estado',
      'completado',
    ])) {
      return _SIV2QuestionFocus.progress;
    }
    if (hasAny(<String>[
      'most urgent',
      'urgent',
      'overdue',
      'past due',
      'deadline',
      'highest priority',
      'need attention',
      'needs attention',
      'at risk',
      'risk first',
      'mas urgente',
      'urgente',
      'atrasad',
      'vencid',
      'mayor prioridad',
      'prioridad mas alta',
      'necesita atencion',
    ])) {
      return _SIV2QuestionFocus.urgency;
    }
    if (hasAny(<String>[
      'why',
      'explain',
      'reason',
      'cause',
      'por que',
      'explica',
      'razon',
      'causa',
    ])) {
      return _SIV2QuestionFocus.explanation;
    }
    final bool asksForAvailableAction = RegExp(
      r'^what can i (?:do|work on)(?: next| now)?(?:$| (?:in|for|with) '
      r'(?:\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|fifteen|twenty|thirty|sixty) '
      r'(?:minutes?|hours?)\b)',
    ).hasMatch(input);
    final bool asksForSmallAction = RegExp(
      r'\bwhat is (?:one|a) (?:small |quick |practical )?(?:[a-z]+ )?'
      r'(?:action|task|step) (?:that )?i can (?:do|take) (?:now|next)\b',
    ).hasMatch(input);
    if (asksForAvailableAction ||
        asksForSmallAction ||
        hasAny(<String>[
          'what should i do',
          'what do i do',
          'what should i work',
          'what now',
          'next action',
          'next task',
          'start first',
          'focus on',
          'do first',
          'que deberia hacer',
          'que hago',
          'que sigue',
          'siguiente accion',
          'siguiente tarea',
          'hacer primero',
          'empezar primero',
        ])) {
      return _SIV2QuestionFocus.nextAction;
    }
    if (hasAny(<String>[
      'aligned',
      'alignment',
      'support my goal',
      'supports the goal',
      'linked to',
      'contribute to',
      'alinead',
      'apoya mi meta',
      'vinculad',
      'contribuye',
    ])) {
      return _SIV2QuestionFocus.goalAlignment;
    }
    if (hasAny(<String>[
      'schedule',
      'calendar',
      'when is',
      'due when',
      'what is due',
      'what is coming up',
      'coming up',
      'today',
      'tomorrow',
      'this week',
      'horario',
      'calendario',
      'cuando',
      'que vence',
      'hoy',
      'manana',
      'esta semana',
    ])) {
      return _SIV2QuestionFocus.schedule;
    }
    if (hasAny(<String>[
      'summary',
      'summarize',
      'tell me about',
      'details about',
      'what do you know about',
      'review my',
      'analyze my',
      'evidence',
      'planning state',
      'resumen',
      'resume',
      'dime sobre',
      'detalles',
      'que sabes',
      'revisa',
      'analiza',
      'evidencia',
    ])) {
      return _SIV2QuestionFocus.overview;
    }
    return _SIV2QuestionFocus.unsupported;
  }

  static SIV2Source? _sourceFor(String input) {
    if (input.contains('milestone') || input.contains('hito')) {
      return SIV2Source.milestones;
    }
    if (input.contains('timeline') || input.contains('event')) {
      return SIV2Source.timeline;
    }
    if (input.contains('historial') || input.contains('evento')) {
      return SIV2Source.timeline;
    }
    if (input.contains('goal') || input.contains('meta')) {
      return SIV2Source.goals;
    }
    if (input.contains('task') ||
        input.contains('work item') ||
        input.contains('tarea')) {
      return SIV2Source.tasks;
    }
    return null;
  }
}

final class _SIV2QuestionMatch {
  const _SIV2QuestionMatch({
    required this.title,
    required this.evidenceId,
    required this.kind,
    required this.score,
  });

  final String title;
  final String evidenceId;
  final String kind;
  final int score;
}

String _normalizeQuestion(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _sentence(String value) {
  final String trimmed = value.trimRight();
  return RegExp(r'[.!?]$').hasMatch(trimmed) ? trimmed : '$trimmed.';
}

Set<String> _questionTerms(String input) => _questionTokens(
  input,
).where((String term) => !_questionStopWords.contains(term)).toSet();

Set<String> _questionTokens(String input) => RegExp(r'[a-z0-9]+')
    .allMatches(input.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where((String term) => term.length >= 3)
    .toSet();

const Set<String> _questionStopWords = <String>{
  'about',
  'active',
  'answer',
  'app',
  'can',
  'compare',
  'console',
  'could',
  'current',
  'date',
  'days',
  'does',
  'evidence',
  'explain',
  'first',
  'from',
  'goal',
  'goals',
  'have',
  'help',
  'how',
  'into',
  'lens',
  'make',
  'milestone',
  'milestones',
  'most',
  'next',
  'now',
  'plan',
  'planning',
  'please',
  'question',
  'should',
  'show',
  'task',
  'tasks',
  'that',
  'the',
  'their',
  'them',
  'this',
  'timeline',
  'today',
  'what',
  'when',
  'which',
  'why',
  'will',
  'with',
  'would',
  'your',
};

final DateTime _farFuture = DateTime.fromMillisecondsSinceEpoch(
  8640000000000000,
  isUtc: true,
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
