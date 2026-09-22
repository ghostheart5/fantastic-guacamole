part of 'smart_planner_query_controller.dart';

enum _PlannerFollowUpKind { explain, smaller, timing, completed, rejected }

// These are operations on the displayed proposal, not new life objectives.
// Keep them separate from extracting a new action from free-form text.
_PlannerFollowUpKind? _plannerFollowUpKind(String input) {
  final text = input.trim().toLowerCase().replaceAll('’', "'");
  if (RegExp(
    r'^(?:why(?: this(?: one| plan)?| that(?: one)?| do you suggest that)?|explain (?:that|this|it)|por qu[eé](?: este(?: plan)?| eso)?|explica (?:eso|esto))[?!. ]*$',
  ).hasMatch(text)) {
    return _PlannerFollowUpKind.explain;
  }
  if (RegExp(
    r'^(?:(?:can you |please )?make (?:it|this|that|the plan) (?:smaller|shorter|easier)|(?:hazlo|haz esto|haz el plan) m[aá]s (?:peque[nñ]o|corto|f[aá]cil))(?: please| por favor)?[?!. ]*$',
  ).hasMatch(text)) {
    return _PlannerFollowUpKind.smaller;
  }
  if (RegExp(
        r'\b(?:should|do|can)\s+i\s+leave\s+(?:any\s+)?earlier\b|\b(?:debo|puedo)\s+salir\s+m[aá]s\s+temprano\b',
        caseSensitive: false,
      ).hasMatch(text) &&
      _plannerDepartureClock(text) != null) {
    return _PlannerFollowUpKind.timing;
  }
  if (RegExp(
    r'^(?:i (?:already )?(?:did|finished|completed) (?:it|that|this)|(?:it|that|this) is (?:already )?done|done|ya (?:lo )?(?:hice|termin[eé])|listo)(?:[.! ]+(?:what(?: is)? next|what else|now what|qu[eé] sigue|ahora qu[eé]))?[?!. ]*$',
  ).hasMatch(text)) {
    return _PlannerFollowUpKind.completed;
  }
  if (RegExp(
    r"^(?:(?:that|this|it) (?:won't|will not|doesn't|does not) work(?: for me)?|i (?:can't|cannot) do (?:that|this|it)|(?:eso|esto) no (?:funciona|me sirve)|no puedo hacer (?:eso|esto))[?!. ]*$",
  ).hasMatch(text)) {
    return _PlannerFollowUpKind.rejected;
  }
  return null;
}

PlannerV2Response? _answerDisplayedPlanFollowUp({
  required String input,
  required PlannerConversationSnapshot? snapshot,
  required _PlannerConversationContext conversation,
}) {
  if (snapshot == null ||
      snapshot.currentPlan.isClarification ||
      !conversation.continuesPriorSubject) {
    return null;
  }
  final kind = _plannerFollowUpKind(input);
  if (kind == null) return null;
  final plan = snapshot.currentPlan;
  final option = plan.recommendedOption;
  String copy(String en, String es) => plan.isSpanish ? es : en;
  final context = conversation.userContext;
  switch (kind) {
    case _PlannerFollowUpKind.explain:
      final explanation = <String>[
        copy(
          'You asked why this step fits.',
          'Quieres saber por qué encaja este paso.',
        ),
        plan.recommendationReason,
        copy(
          'The proposed step is: ${plan.nextStep}',
          'El paso propuesto es: ${plan.nextStep}',
        ),
        copy(
          'Its tradeoff: ${option.tradeoff}',
          'Lo que implica: ${option.tradeoff}',
        ),
        copy(
          'The time is a suggested limit, not a prediction of how long the whole task will take.',
          'El tiempo es un límite sugerido, no una predicción de cuánto tardará toda la tarea.',
        ),
      ].join('\n\n');
      return plan.copyWith(
        whatIHeard: copy(
          'You asked why this step fits.',
          'Quieres saber por qué encaja este paso.',
        ),
        conversationReply: explanation,
        clearUsefulQuestion: true,
        userContext: context,
      );
    case _PlannerFollowUpKind.smaller:
      final previousSeconds =
          option.estimatedSeconds ?? option.estimatedMinutes * 60;
      final seconds = math.max(15, (previousSeconds / 2).floor());
      final minutes = (seconds / 60).ceil();
      final minimum = plan.optionByKind[PlannerOptionKind.minimum]!;
      final reduced = minimum.copyWith(
        estimatedMinutes: minutes,
        estimatedSeconds: seconds < 60 ? seconds : null,
        clearEstimatedSeconds: seconds >= 60,
      );
      final duration = seconds < 60
          ? copy('$seconds seconds', '$seconds segundos')
          : copy(
              _plannerMinutes(minutes),
              '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}',
            );
      return plan.copyWith(
        whatIHeard: copy(
          'You need a smaller start on the same objective.',
          'Necesitas un inicio más pequeño para el mismo objetivo.',
        ),
        options: [
          reduced,
          ...plan.options.where((o) => o.kind != PlannerOptionKind.minimum),
        ],
        recommendedKind: PlannerOptionKind.minimum,
        nextStep: reduced.description,
        recommendationReason: copy(
          'Stop after $duration even if the task is unfinished; this is a starting limit, not a promise to finish.',
          'Para después de $duration aunque no hayas terminado; es un límite para empezar, no una promesa de terminar.',
        ),
        clearConversationReply: true,
        clearUsefulQuestion: true,
        userContext: PlannerUserContext(
          objective: context.objective,
          corrections: context.corrections,
          savedContextDeclined: context.savedContextDeclined,
          // A smaller proposed step does not rewrite the user's time budget.
          timeLimitMinutes: context.timeLimitMinutes,
          timeLimitSeconds: context.timeLimitSeconds,
        ),
      );
    case _PlannerFollowUpKind.timing:
      final String departure =
          _plannerDepartureClock(input) ?? copy('that time', 'esa hora');
      return plan.copyWith(
        whatIHeard: copy(
          'You are checking whether leaving at $departure gives the plan enough buffer.',
          'Quieres comprobar si salir a las $departure deja margen suficiente para el plan.',
        ),
        conversationReply: copy(
          'I cannot verify traffic, travel time, time in the store, or your dinner deadline from the current evidence. Leaving before $departure creates more buffer. To judge whether that is necessary, compare your expected round-trip and shopping time with the time remaining before dinner.',
          'No puedo verificar el tráfico, el tiempo de viaje, el tiempo dentro de la tienda ni la hora límite de la cena con la información actual. Salir antes de las $departure deja más margen. Para decidir si hace falta, compara el viaje de ida y vuelta y el tiempo de compra previstos con el tiempo disponible antes de cenar.',
        ),
        usefulQuestion: copy(
          'How many minutes do you expect for travel and shopping, and what time must you be home?',
          '¿Cuántos minutos calculas para el viaje y la compra, y a qué hora necesitas estar en casa?',
        ),
        userContext: context,
      );
    case _PlannerFollowUpKind.completed:
    case _PlannerFollowUpKind.rejected:
      final completed = kind == _PlannerFollowUpKind.completed;
      return PlannerV2Response.clarification(
        whatIHeard: completed
            ? copy(
                'You reported that you completed the proposed step. I will not ask you to repeat it.',
                'Has indicado que completaste el paso propuesto. No te pediré que lo repitas.',
              )
            : copy(
                'That approach does not work for you. Let’s keep your objective and change the method.',
                'Ese método no te sirve. Mantengamos tu objetivo y cambiemos el método.',
              ),
        mattersMost: copy(
          'Your latest update changes what is useful next.',
          'Tu actualización cambia lo que resulta útil ahora.',
        ),
        question: completed
            ? copy(
                'What remains unfinished for this objective, if anything?',
                '¿Qué queda por hacer para este objetivo, si queda algo?',
              )
            : copy(
                'What prevents this step: time, access to something, or the method itself?',
                '¿Qué impide este paso: el tiempo, el acceso a algo o el método en sí?',
              ),
        verifiedEvidence: [
          copy(
            'Your update applies to this conversation only. Saved tasks and progress were not changed.',
            'Tu actualización solo se aplica a esta conversación. No se cambiaron las tareas guardadas ni el progreso.',
          ),
        ],
        adaptationReceipt: plan.adaptationReceipt,
        origin: plan.origin,
        languageCode: plan.languageCode,
        userContext: context,
      );
  }
}

String? _plannerDepartureClock(String input) {
  const String clock =
      r'(\d{1,2}:\d{2}\s*(?:a\.?\s*m\.?|p\.?\s*m\.?)?|\d{1,2}\s*(?:a\.?\s*m\.?|p\.?\s*m\.?))';
  final List<RegExp> afterLeave = <RegExp>[
    RegExp(
      r'\bleave\s+(?:any\s+)?earlier\b[^.!?;]{0,35}?\b(?:than|at|by)?\s*' +
          clock,
      caseSensitive: false,
    ),
    RegExp(
      r'\bsalir\s+m[aá]s\s+temprano\b[^.!?;]{0,35}?\b(?:que|de|a\s+las)?\s*' +
          clock,
      caseSensitive: false,
    ),
  ];
  for (final RegExp pattern in afterLeave) {
    final String? value = pattern.firstMatch(input)?.group(1)?.trim();
    if (value != null) return value;
  }
  final RegExp beforeLeave = RegExp(
    clock +
        r'[^.!?;]{0,60}\b(?:leave\s+(?:any\s+)?earlier|salir\s+m[aá]s\s+temprano)\b',
    caseSensitive: false,
  );
  return beforeLeave.firstMatch(input)?.group(1)?.trim();
}
