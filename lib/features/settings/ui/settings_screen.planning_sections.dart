part of 'settings_screen.dart';

class _PersonalizationSection extends ConsumerWidget {
  const _PersonalizationSection();

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    PersonalizationProfile next,
  ) async {
    await ref.read(personalizationProfileProvider.notifier).update(next);
    if (!context.mounted) return;
    _showSaved(context);
  }

  // Waits for the stored profile, so turning AI chat on or off never writes
  // defaults over the other stored choices.
  Future<void> _saveAiChat(
    BuildContext context,
    WidgetRef ref,
    bool allowed,
  ) async {
    await ref
        .read(personalizationProfileProvider.notifier)
        .setExternalAiAllowed(allowed);
    if (!context.mounted) return;
    _showSaved(context);
  }

  void _showSaved(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Planning preferences updated.',
            'Preferencias de planificación actualizadas.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PersonalizationProfile profile = ref.watch(
      personalizationProfileProvider,
    );
    final ObservedPlanningPatterns patterns = ref.watch(
      observedPlanningPatternsProvider,
    );
    final PersonalizationDecision decision = ref.watch(
      personalizationDecisionProvider('settings'),
    );
    final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
    final List<String> spanishDecisionSignals = <String>[
      if (profile.goalCategory.isNotEmpty) 'categoría de meta',
      'estilo ${_planningStyleLabel(profile.planningStyle.name, isSpanish: true).toLowerCase()}',
      'prioridad ${_priorityStrategyLabel(profile.priorityStrategy.name, isSpanish: true).toLowerCase()}',
      if (patterns.completed + patterns.skipped > 0)
        'historial de finalización (${(patterns.completionRate * 100).round()}%)',
    ];
    final String localizedDecisionExplanation = isSpanish
        ? 'Usa ${spanishDecisionSignals.join(', ')}. Puedes cambiar estas opciones en Ajustes.'
        : decision.explanation;

    return _Section(
      label: journeyText(
        context,
        'PLANNING PERSONALIZATION',
        'PERSONALIZACIÓN DE LA PLANIFICACIÓN',
      ),
      accentColor: AppColors.neonCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              journeyText(
                context,
                'These choices tune guidance. You can change them at any time; learned patterns remain separate from your explicit preferences.',
                'Estas opciones ajustan la orientación. Puedes cambiarlas cuando quieras; los patrones aprendidos permanecen separados de tus preferencias explícitas.',
              ),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _PreferenceDropdown<String>(
            label: journeyText(
              context,
              'Planning style',
              'Estilo de planificación',
            ),
            value: profile.planningStyle.name,
            items: const <String>[
              'flexible',
              'timeBlocked',
              'energyMatched',
              'singleTask',
            ],
            itemLabel: (String value) =>
                _planningStyleLabel(value, isSpanish: isSpanish),
            onChanged: (String value) => _save(
              context,
              ref,
              profile.copyWith(
                planningStyle: PlanningStyle.values.byName(value),
              ),
            ),
          ),
          _PreferenceDropdown<String>(
            label: journeyText(
              context,
              'Priority strategy',
              'Estrategia de prioridades',
            ),
            value: profile.priorityStrategy.name,
            items: const <String>[
              'balanced',
              'deadlineFirst',
              'energyFirst',
              'goalFirst',
              'quickWins',
            ],
            itemLabel: (String value) =>
                _priorityStrategyLabel(value, isSpanish: isSpanish),
            onChanged: (String value) => _save(
              context,
              ref,
              profile.copyWith(
                priorityStrategy: PriorityStrategy.values.byName(value),
              ),
            ),
          ),
          _PreferenceDropdown<String>(
            label: journeyText(
              context,
              'Missed-task recovery',
              'Recuperación de tareas incumplidas',
            ),
            value: profile.recoveryPolicy.name,
            items: const <String>[
              'askFirst',
              'reschedule',
              'reduceScope',
              'recoveryQueue',
            ],
            itemLabel: (String value) =>
                _recoveryPolicyLabel(value, isSpanish: isSpanish),
            onChanged: (String value) => _save(
              context,
              ref,
              profile.copyWith(
                recoveryPolicy: RecoveryPolicy.values.byName(value),
              ),
            ),
          ),
          _NeonToggleTile(
            title: journeyText(
              context,
              'Use emotional state in guidance',
              'Usar el estado emocional en la orientación',
            ),
            value: profile.useEmotionSignals,
            onChanged: (bool value) =>
                _save(context, ref, profile.copyWith(useEmotionSignals: value)),
          ),
          _NeonToggleTile(
            title: journeyText(
              context,
              'Allow saved preferences in future guidance',
              'Usar las preferencias guardadas en orientaciones futuras',
            ),
            value: profile.useMemoryContext,
            onChanged: (bool value) =>
                _save(context, ref, profile.copyWith(useMemoryContext: value)),
          ),
          // The same explanation as Chat's consent sheet, beside the switch
          // for everyone who can see it.
          if (ref.watch(externalAiAvailableProvider)) ...[
            _NeonStatusTile(
              title: AiChatDisclosure(spanish: isSpanish).featureName,
              subtitle: AiChatDisclosure(spanish: isSpanish).summary,
              subtitleMaxLines: null,
            ),
            _NeonToggleTile(
              title: isSpanish ? 'Permitir el chat con IA' : 'Allow AI chat',
              value: profile.externalAiAllowed,
              onChanged: (bool value) => _saveAiChat(context, ref, value),
            ),
          ] else
            _NeonStatusTile(
              title: isSpanish
                  ? 'Asistencia de IA externa'
                  : 'External AI assistance',
              subtitle: isSpanish
                  ? 'La asistencia de IA externa no está habilitada para esta cuenta. Tu trabajo de planificación guardado permanece disponible.'
                  : 'External AI assistance is not enabled for this account. Your saved planning work remains available.',
            ),
          if (ref.watch(internalCreditTestEnabledProvider))
            const InternalCreditTestPanel(),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Why suggestions appear',
              'Por qué aparecen las sugerencias',
            ),
            subtitle: localizedDecisionExplanation,
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Learned evidence',
              'Evidencia aprendida',
            ),
            subtitle: journeyText(
              context,
              '${patterns.completed} completed · ${patterns.skipped} skipped · ${(patterns.completionRate * 100).round()}% completion rate',
              '${patterns.completed} completadas · ${patterns.skipped} omitidas · ${(patterns.completionRate * 100).round()}% de finalización',
            ),
          ),
          _NeonNavTile(
            title: journeyText(
              context,
              'Reset learned planning patterns',
              'Restablecer patrones de planificación aprendidos',
            ),
            subtitle: journeyText(
              context,
              'Deletes inferred completion/skip evidence only.',
              'Elimina solo la evidencia inferida de finalización y omisión.',
            ),
            onTap: () => unawaited(
              ref.read(observedPlanningPatternsProvider.notifier).reset(),
            ),
          ),
        ],
      ),
    );
  }
}

String _planningStyleLabel(String value, {required bool isSpanish}) {
  if (!isSpanish) {
    return switch (value) {
      'flexible' => 'Flexible',
      'timeBlocked' => 'Time blocks',
      'energyMatched' => 'Match my energy',
      'singleTask' => 'One task at a time',
      _ => value,
    };
  }
  return switch (value) {
    'flexible' => 'Flexible',
    'timeBlocked' => 'Por bloques de tiempo',
    'energyMatched' => 'Adaptado a la energía',
    'singleTask' => 'Una tarea a la vez',
    _ => value,
  };
}

String _priorityStrategyLabel(String value, {required bool isSpanish}) {
  if (!isSpanish) {
    return switch (value) {
      'balanced' => 'Balanced',
      'deadlineFirst' => 'Deadlines first',
      'energyFirst' => 'Energy first',
      'goalFirst' => 'Goals first',
      'quickWins' => 'Quick wins',
      _ => value,
    };
  }
  return switch (value) {
    'balanced' => 'Equilibrada',
    'deadlineFirst' => 'Primero las fechas límite',
    'energyFirst' => 'Primero la energía',
    'goalFirst' => 'Primero las metas',
    'quickWins' => 'Victorias rápidas',
    _ => value,
  };
}

String _recoveryPolicyLabel(String value, {required bool isSpanish}) {
  if (!isSpanish) {
    return switch (value) {
      'askFirst' => 'Ask me first',
      'reschedule' => 'Reschedule',
      'reduceScope' => 'Make it smaller',
      'recoveryQueue' => 'Save for later',
      _ => value,
    };
  }
  return switch (value) {
    'askFirst' => 'Preguntar primero',
    'reschedule' => 'Reprogramar',
    'reduceScope' => 'Reducir el alcance',
    'recoveryQueue' => 'Cola de recuperación',
    _ => value,
  };
}

class _LearningLedgerSection extends ConsumerWidget {
  const _LearningLedgerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DecisionOutcomeEntity>> outcomesAsync = ref.watch(
      decisionOutcomesProvider,
    );
    final bool paused = ref.watch(learningPausedProvider).asData?.value ?? true;
    final LearningLedgerSummary summary = ref.watch(
      learningLedgerSummaryProvider,
    );
    final List<DecisionOutcomeEntity> outcomes =
        outcomesAsync.asData?.value ?? const <DecisionOutcomeEntity>[];
    final List<DecisionOutcomeEntity> recent = outcomes.reversed
        .take(8)
        .toList(growable: false);

    return _Section(
      label: journeyText(
        context,
        'WHAT CHANGED FROM YOUR FEEDBACK',
        'QUÉ CAMBIÓ CON TUS COMENTARIOS',
      ),
      accentColor: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              journeyText(
                context,
                'Axiomara learns only bounded support preferences from the outcomes below. These are not facts about you, and low-confidence patterns do not change recommendations.',
                'Axiomara aprende solo preferencias limitadas de apoyo a partir de los resultados siguientes. No son datos sobre ti, y los patrones de baja confianza no cambian las recomendaciones.',
              ),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          _NeonToggleTile(
            key: const Key('learning-feedback-toggle'),
            title: journeyText(
              context,
              'Use feedback for learning',
              'Usar comentarios para aprender',
            ),
            value: !paused,
            onChanged: outcomesAsync.isLoading
                ? null
                : (bool enabled) => unawaited(
                    ref
                        .read(decisionOutcomeActionsProvider)
                        .setPaused(!enabled),
                  ),
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Reviewable observations',
              'Observaciones revisables',
            ),
            subtitle: outcomesAsync.when(
              loading: () => journeyText(
                context,
                'Loading this account’s feedback history...',
                'Cargando el registro de esta cuenta...',
              ),
              error: (_, _) => journeyText(
                context,
                'Feedback history unavailable. No learning is applied.',
                'El registro no está disponible. No se aplica ningún aprendizaje.',
              ),
              data: (List<DecisionOutcomeEntity> values) => journeyText(
                context,
                '${values.length} saved locally · maximum 256 · recent evidence decays with a 30-day half-life.',
                '${values.length} guardadas localmente · máximo 256 · la evidencia reciente pierde peso con una semivida de 30 días.',
              ),
            ),
          ),
          if (outcomesAsync.hasValue && summary.patterns.isEmpty)
            _NeonStatusTile(
              title: journeyText(
                context,
                'Learned preferences',
                'Preferencias aprendidas',
              ),
              subtitle: journeyText(
                context,
                'None yet. At least three recent outcomes are required before a pattern may influence guidance.',
                'Todavía no hay ninguna. Se requieren al menos tres resultados recientes antes de que un patrón pueda influir en la orientación.',
              ),
            )
          else if (outcomesAsync.hasValue)
            ...summary.patterns
                .take(3)
                .map(
                  (LearnedPreferencePattern pattern) => _NeonStatusTile(
                    title:
                        '${_learningLabel(pattern.surface, isSpanish: ChronoSparkLocalizations.of(context).isSpanish)} · ${_learningGeneratedText(pattern.situation, isSpanish: ChronoSparkLocalizations.of(context).isSpanish)}',
                    subtitle: _learningPatternDetail(
                      pattern,
                      isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
                    ),
                  ),
                ),
          if (recent.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                journeyText(
                  context,
                  'RECENT RAW OBSERVATIONS',
                  'OBSERVACIONES RECIENTES SIN PROCESAR',
                ),
                style: const TextStyle(
                  color: AppColors.neonViolet,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...recent.map(
              (DecisionOutcomeEntity outcome) => ListTile(
                key: ValueKey<String>('learning-ledger-${outcome.id}'),
                title: Text(
                  '${_learningLabel(outcome.surface, isSpanish: ChronoSparkLocalizations.of(context).isSpanish)} · ${ChronoSparkLocalizations.of(context).isSpanish ? _learningLabel(outcome.kind.name, isSpanish: true) : outcome.kind.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  _learningObservationDetail(
                    outcome,
                    isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
                  ),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: journeyText(
                    context,
                    'Correct or remove this observation',
                    'Corregir o eliminar esta observación',
                  ),
                  onSelected: (String value) => unawaited(
                    _applyLearningLedgerAction(context, ref, outcome, value),
                  ),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'helped',
                          child: Text(
                            journeyText(
                              context,
                              'Correct: it helped',
                              'Corregir: sí ayudó',
                            ),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'not_helpful',
                          child: Text(
                            journeyText(
                              context,
                              'Correct: not helpful',
                              'Corregir: no ayudó',
                            ),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Text(
                            journeyText(
                              context,
                              'Undo / remove',
                              'Deshacer / eliminar',
                            ),
                          ),
                        ),
                      ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: outcomes.isEmpty
                      ? null
                      : () async {
                          final String export = ref
                              .read(decisionOutcomeActionsProvider)
                              .exportJson(outcomes);
                          await Clipboard.setData(ClipboardData(text: export));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                journeyText(
                                  context,
                                  'Feedback history copied as JSON.',
                                  'Registro de aprendizaje copiado como JSON.',
                                ),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.download_outlined),
                  label: Text(journeyText(context, 'Export', 'Exportar')),
                ),
                OutlinedButton.icon(
                  onPressed: outcomes.isEmpty
                      ? null
                      : () => unawaited(
                          _confirmClearLearningLedger(context, ref),
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    journeyText(context, 'Delete all', 'Eliminar todo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _learningLabel(String value, {required bool isSpanish}) {
  final String normalized = value.replaceAll('-', '_');
  if (normalized == 'smart_planner') {
    return isSpanish ? 'Elegir un paso' : 'Choose a step';
  }
  if (normalized == 'daily_rhythm') {
    return isSpanish ? 'Hábito' : 'Habit';
  }
  if (normalized == 'daily_rhythm_occurrence') {
    return isSpanish ? 'registro de hábito' : 'Habit occurrence';
  }
  if (isSpanish) {
    final String? translated = <String, String>{
      'task_lifecycle': 'Ciclo de la tarea',
      'task_execution': 'ejecución de tareas',
      'smart_planner': 'Elegir un paso',
      'shown': 'mostrada',
      'accepted': 'aceptada',
      'rejected': 'rechazada',
      'completed': 'completada',
      'skipped': 'omitida',
    }[normalized];
    if (translated != null) return translated;
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _learningGeneratedText(String value, {required bool isSpanish}) {
  // Exact app-authored historical template only; never rewrite user text.
  if (value == 'daily rhythm occurrence') {
    return isSpanish ? 'registro de hábito' : 'habit occurrence';
  }
  if (!isSpanish) return value;
  return switch (value) {
    'task execution' => 'ejecución de tareas',
    'bounded planning choice' => 'elección de planificación limitada',
    'Completed the task.' => 'Completó la tarea.',
    'minimum' => 'mínima',
    _ => value,
  };
}

String _learningOptionLabel(String value, {required bool isSpanish}) {
  if (!isSpanish) return value;
  return switch (value) {
    'minimum' => 'mínima',
    'bestFit' => 'más adecuada',
    'stretch' => 'de mayor esfuerzo',
    _ => value,
  };
}

String _learningPatternDetail(
  LearnedPreferencePattern pattern, {
  required bool isSpanish,
}) {
  if (!isSpanish) {
    return '${pattern.confidence.name} confidence · ${pattern.explanation}';
  }
  final String confidence = switch (pattern.confidence.name) {
    'established' => 'confianza consolidada',
    'developing' => 'confianza en desarrollo',
    'low' => 'confianza baja',
    final String value => 'confianza $value',
  };
  if (!pattern.canInfluenceRecommendations) {
    final String outcomes = pattern.observationCount == 1
        ? '1 resultado revisable'
        : '${pattern.observationCount} resultados revisables';
    return '$confidence · Aún está aprendiendo: $outcomes. Todavía no se aplica ninguna preferencia.';
  }
  final int helpfulPercent = pattern.decayedWeight == 0
      ? 0
      : ((pattern.helpfulWeight / pattern.decayedWeight).clamp(0.0, 1.0) * 100)
            .round();
  final String option = pattern.preferredOption == null
      ? ''
      : ' La opción repetida con mayor respaldo es «${_learningOptionLabel(pattern.preferredOption!, isSpanish: true)}».';
  return '$confidence · $helpfulPercent% de los resultados recientes ponderados ayudaron.$option';
}

String _learningObservationDetail(
  DecisionOutcomeEntity outcome, {
  required bool isSpanish,
}) {
  final List<String> details = <String>[
    outcome.situation == null
        ? (outcome.subjectId == null
              ? (isSpanish ? 'orientación general' : 'general guidance')
              : (isSpanish ? 'orientación de tareas' : 'task guidance'))
        : _learningGeneratedText(outcome.situation!, isSpanish: isSpanish),
    if (outcome.optionChosen != null)
      '${isSpanish ? 'opción' : 'option'} ${_learningOptionLabel(outcome.optionChosen!, isSpanish: isSpanish)}',
    if (outcome.optionSizeMinutes != null)
      '${outcome.optionSizeMinutes} ${isSpanish ? 'minutos' : 'minutes'}',
    if (outcome.deferralReason != null)
      '${isSpanish ? 'aplazada' : 'deferred'}: ${outcome.deferralReason}',
    if (outcome.completionResult != null)
      _learningGeneratedText(outcome.completionResult!, isSpanish: isSpanish),
    if (outcome.correction != null)
      '${isSpanish ? 'corregida a' : 'corrected to'} ${outcome.correction}',
    if (outcome.recommendationHelped != null)
      outcome.recommendationHelped!
          ? (isSpanish ? 'ayudó' : 'helped')
          : (isSpanish ? 'no ayudó' : 'did not help'),
  ];
  return details.join(' · ');
}

Future<void> _applyLearningLedgerAction(
  BuildContext context,
  WidgetRef ref,
  DecisionOutcomeEntity outcome,
  String action,
) async {
  final DecisionOutcomeActions actions = ref.read(
    decisionOutcomeActionsProvider,
  );
  if (action == 'remove') {
    await actions.remove(outcome);
  } else {
    final bool helped = action == 'helped';
    await actions.correctOutcome(
      original: outcome,
      replacementKind: helped
          ? DecisionOutcomeKind.accepted
          : DecisionOutcomeKind.rejected,
      reason: helped
          ? 'User corrected this observation to helpful in feedback history.'
          : 'User corrected this observation to not helpful in feedback history.',
    );
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        action == 'remove'
            ? journeyText(
                context,
                'Observation removed and its learning undone.',
                'Observación eliminada y su aprendizaje revertido.',
              )
            : journeyText(
                context,
                'Observation corrected. The learned preference was updated.',
                'Observación corregida. Se actualizó la preferencia aprendida.',
              ),
      ),
    ),
  );
}

Future<void> _confirmClearLearningLedger(
  BuildContext context,
  WidgetRef ref,
) async {
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            journeyText(
              context,
              'Delete all learning observations?',
              '¿Eliminar todas las observaciones de aprendizaje?',
            ),
          ),
          content: Text(
            journeyText(
              context,
              'This permanently removes the feedback history and reverses the preference learning created from it. Tasks, goals, personal information, and user-authored facts are not changed.',
              'Esto elimina permanentemente el registro de resultados de decisiones y revierte las preferencias aprendidas. Las tareas, metas, la información personal y los datos escritos por ti no cambian.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(journeyText(context, 'Cancel', 'Cancelar')),
            ),
            FilledButton(
              key: const Key('confirm-delete-learning-ledger'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                journeyText(
                  context,
                  'Delete feedback history',
                  'Eliminar registro',
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return;
  await ref.read(decisionOutcomeActionsProvider).clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        journeyText(
          context,
          'Feedback history deleted.',
          'Registro de aprendizaje eliminado.',
        ),
      ),
    ),
  );
}
