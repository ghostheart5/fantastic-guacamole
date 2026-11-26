part of 'trajectory_engine_screen.dart';

/// The two lines under the switch: estimates, not promises, and what changed.
class _EstimatesLine extends StatelessWidget {
  const _EstimatesLine();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final PlainPalette colors = PlainPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          journeyText(
            context,
            'These are estimates, not promises.',
            'Son estimaciones, no promesas.',
          ),
          style: text.bodyLarge?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: 4),
        Text(
          journeyText(
            context,
            'Since this update, the time range changes the estimate and workload uses your free time and task dates.',
            'Desde esta actualización, el periodo cambia la estimación y la carga de trabajo usa tu tiempo libre y las fechas de las tareas.',
          ),
          style: text.bodyMedium?.copyWith(color: colors.secondary),
        ),
      ],
    );
  }
}

/// "If you keep going as you are": every figure for the selected range.
class _KeepGoingSection extends StatelessWidget {
  const _KeepGoingSection({
    required this.baseline,
    required this.horizonDays,
    required this.habitLines,
  });

  final TrajectoryBaseline baseline;
  final int horizonDays;
  final TrajectoryHabitLines habitLines;

  @override
  Widget build(BuildContext context) {
    final int load = baseline.pressureInHorizon;
    final TrajectoryExpectedCompletions done =
        baseline.expectedCompletionsInHorizon;
    final int inRange = baseline.tasksInHorizon;
    return PlainSection(
      title: journeyText(
        context,
        'If you keep going as you are',
        'Si sigues como vas',
      ),
      description: journeyText(
        context,
        'Over the next $horizonDays days.',
        'En los próximos $horizonDays días.',
      ),
      children: <Widget>[
        PlainCard(
          key: const Key('future-outcomes-keep-going'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PlainMetricRow(
                key: const Key('keep-going-workload'),
                label: journeyText(context, 'Workload', 'Carga de trabajo'),
                value: '${_workloadBand(context, load)}, $load%',
                caption: journeyText(
                  context,
                  'Share of your free time the tasks in this range need.',
                  'Parte de tu tiempo libre que necesitan las tareas de este periodo.',
                ),
                provenance: ProvenanceKind.estimate,
              ),
              PlainMetricRow(
                key: const Key('keep-going-tasks'),
                label: journeyText(
                  context,
                  'Tasks in this range',
                  'Tareas en este periodo',
                ),
                value: '$inRange',
                provenance: ProvenanceKind.recorded,
              ),
              PlainMetricRow(
                key: const Key('keep-going-finish'),
                label: journeyText(
                  context,
                  'Expected to finish',
                  'Previsto terminar',
                ),
                value: journeyText(
                  context,
                  'about ${done.mid} of $inRange',
                  'unas ${done.mid} de $inRange',
                ),
                caption: done.low == done.high
                    ? journeyText(
                        context,
                        'At your recent pace.',
                        'A tu ritmo reciente.',
                      )
                    : journeyText(
                        context,
                        'Likely ${done.low} to ${done.high}, at your recent pace.',
                        'Probablemente de ${done.low} a ${done.high}, a tu ritmo reciente.',
                      ),
                provenance: ProvenanceKind.estimate,
              ),
              const SizedBox(height: 8),
              _HabitLinesBlock(lines: habitLines, horizonDays: horizonDays),
            ],
          ),
        ),
      ],
    );
  }
}

/// Habit check-ins over the range, one row per habit, from the habit lines
/// provider. Shown only: nothing here reaches the comparison.
class _HabitLinesBlock extends StatelessWidget {
  const _HabitLinesBlock({required this.lines, required this.horizonDays});

  final TrajectoryHabitLines lines;
  final int horizonDays;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final PlainPalette colors = PlainPalette.of(context);
    Widget note(String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: text.bodyMedium?.copyWith(color: colors.secondary),
      ),
    );
    final bool current = lines.horizonDays == horizonDays;
    final List<Widget> body = switch (lines.status) {
      // A line for another range is about to be replaced: wait quietly.
      TrajectoryHabitLinesStatus.loading => <Widget>[
        note(
          journeyText(
            context,
            'Checking your habits…',
            'Revisando tus hábitos…',
          ),
        ),
      ],
      TrajectoryHabitLinesStatus.unavailable => <Widget>[
        note(
          journeyText(
            context,
            "Habits aren't available right now.",
            'Los hábitos no están disponibles ahora.',
          ),
        ),
      ],
      TrajectoryHabitLinesStatus.ready when !current => <Widget>[
        note(
          journeyText(
            context,
            'Checking your habits…',
            'Revisando tus hábitos…',
          ),
        ),
      ],
      TrajectoryHabitLinesStatus.ready when lines.nodes.isEmpty => <Widget>[
        note(
          journeyText(context, 'No active habits.', 'No hay hábitos activos.'),
        ),
      ],
      TrajectoryHabitLinesStatus.ready => <Widget>[
        for (final TrajectoryHabitNode node in lines.nodes)
          _HabitLineRow(
            key: ValueKey<String>('habit-line-${node.habitId}'),
            node: node,
          ),
      ],
    };
    return Column(
      key: const Key('keep-going-habits'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          journeyText(context, 'Habit check-ins', 'Registros de hábitos'),
          style: text.titleSmall?.copyWith(color: colors.primary),
        ),
        ...body,
      ],
    );
  }
}

class _HabitLineRow extends StatelessWidget {
  const _HabitLineRow({required this.node, super.key});

  final TrajectoryHabitNode node;

  @override
  Widget build(BuildContext context) {
    final TrajectoryExpectedCompletions? projected = node.projectedCheckIns;
    if (node.evidence == TrajectoryHabitEvidence.notEnoughHistory ||
        projected == null) {
      return PlainMetricRow(
        label: node.title,
        value: journeyText(
          context,
          'Needs more history',
          'Necesita más historial',
        ),
        caption: journeyText(
          context,
          '${node.closedPeriodsJudged} of ${node.historyNeeded} periods so far.',
          '${node.closedPeriodsJudged} de ${node.historyNeeded} periodos hasta ahora.',
        ),
        provenance: ProvenanceKind.recorded,
      );
    }
    final int of = node.expectedPeriods;
    return PlainMetricRow(
      label: node.title,
      value: journeyText(
        context,
        'about ${projected.mid} of $of check-ins',
        'unos ${projected.mid} de $of registros',
      ),
      caption: projected.low == projected.high
          ? journeyText(context, 'This is an estimate.', 'Es una estimación.')
          : journeyText(
              context,
              'Likely ${projected.low} to ${projected.high}. This is an estimate.',
              'Probablemente de ${projected.low} a ${projected.high}. Es una estimación.',
            ),
      provenance: ProvenanceKind.estimate,
    );
  }
}

/// The options to compare, each a selectable card with plain text only.
class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.comparison,
    required this.selected,
    required this.canRecommend,
    required this.onSelected,
  });

  final TrajectoryComparison comparison;
  final TrajectoryScenarioOutcome? selected;
  final bool canRecommend;
  final ValueChanged<TrajectoryScenarioOutcome> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<TrajectoryScenarioOutcome> visible = comparison.outcomes
        .take(3)
        .toList();
    if (selected case final TrajectoryScenarioOutcome chosen) {
      if (!visible.any((TrajectoryScenarioOutcome o) => o.id == chosen.id)) {
        visible.add(chosen);
      }
    }
    final Map<String, String> reasons = _equalWorkloadReasons(
      context,
      comparison,
      visible,
    );
    return PlainSection(
      title: journeyText(context, 'Options', 'Opciones'),
      description: journeyText(
        context,
        'Pick one to compare it with keeping going. Wider ranges are less reliable.',
        'Elige una para compararla con seguir como vas. Los rangos más amplios son menos fiables.',
      ),
      children: <Widget>[
        for (final TrajectoryScenarioOutcome outcome in visible)
          _OptionCard(
            key: ValueKey<String>('option-${outcome.intervention.id}'),
            outcome: outcome,
            isRecommended:
                canRecommend && outcome.id == comparison.recommendedScenarioId,
            selected: outcome.id == selected?.id,
            reason: reasons[outcome.id],
            onTap: () => onSelected(outcome),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.outcome,
    required this.isRecommended,
    required this.selected,
    required this.reason,
    required this.onTap,
    super.key,
  });

  final TrajectoryScenarioOutcome outcome;
  final bool isRecommended;
  final bool selected;
  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final _Band workload = _Band.of(
      outcome.projectedPressure,
      outcome.uncertainty,
    );
    final _Band pace = _Band.of(outcome.projectedMomentum, outcome.uncertainty);
    final String confidence = _trajectoryConfidenceLabel(
      context,
      outcome.confidence.band,
    );
    return PlainCard(
      selected: selected,
      onTap: onTap,
      child: Builder(
        builder: (BuildContext context) {
          final PlainPalette colors = PlainPalette.of(context);
          final TextStyle? small = text.bodyMedium?.copyWith(
            color: colors.secondary,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _trajectoryGeneratedText(context, outcome.intervention.title),
                style: text.titleSmall?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                journeyText(
                  context,
                  'Workload about ${workload.mid}% (${workload.low}–${workload.high}%)',
                  'Carga de alrededor del ${workload.mid}% (${workload.low}–${workload.high}%)',
                ),
                style: small,
              ),
              Text(
                journeyText(
                  context,
                  'Pace about ${pace.mid} of 100 (${pace.low}–${pace.high})',
                  'Ritmo de alrededor de ${pace.mid} de 100 (${pace.low}–${pace.high})',
                ),
                style: small,
              ),
              // The recommendation shares this line, so withholding it (for
              // example during a refresh) never changes the card's height.
              Text(
                isRecommended
                    ? journeyText(
                        context,
                        'Recommended · Confidence: $confidence',
                        'Recomendada · Confianza: $confidence',
                      )
                    : journeyText(
                        context,
                        'Confidence: $confidence',
                        'Confianza: $confidence',
                      ),
                style: isRecommended
                    ? small?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : small,
              ),
              if (reason != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(reason!, style: small),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A whole-number estimate with its range, clamped to 0..100.
class _Band {
  const _Band(this.mid, this.low, this.high);

  factory _Band.of(int value, int uncertainty) => _Band(
    value,
    (value - uncertainty).clamp(0, 100),
    (value + uncertainty).clamp(0, 100),
  );

  final int mid;
  final int low;
  final int high;
}

/// When options show the same whole workload percent, the order comes from
/// the rest of the estimate. Says, for each such option, the minutes it takes
/// out of the range and its pace change against keeping going.
Map<String, String> _equalWorkloadReasons(
  BuildContext context,
  TrajectoryComparison comparison,
  List<TrajectoryScenarioOutcome> visible,
) {
  final Map<int, int> shown = <int, int>{};
  for (final TrajectoryScenarioOutcome outcome in visible) {
    shown.update(
      outcome.projectedPressure,
      (int count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  final int keepGoingPace =
      _keepGoingOutcome(comparison)?.projectedMomentum ??
      comparison.baseline.momentum;
  return <String, String>{
    for (final TrajectoryScenarioOutcome outcome in visible)
      if ((shown[outcome.projectedPressure] ?? 0) > 1)
        outcome.id: _rankReason(
          context,
          minutes: _minutesFreed(comparison.baseline, outcome),
          paceChange: outcome.projectedMomentum - keepGoingPace,
        ),
  };
}

String _rankReason(
  BuildContext context, {
  required int minutes,
  required int paceChange,
}) {
  final String freed = minutes > 0
      ? journeyText(
          context,
          'frees about $minutes minutes in this range',
          'libera unos $minutes minutos en este periodo',
        )
      : journeyText(
          context,
          'frees no time in this range',
          'no libera tiempo en este periodo',
        );
  final String pace = paceChange == 0
      ? journeyText(context, 'pace unchanged', 'ritmo sin cambios')
      : journeyText(
          context,
          'pace ${paceChange > 0 ? '+' : ''}$paceChange',
          'ritmo ${paceChange > 0 ? '+' : ''}$paceChange',
        );
  return journeyText(
    context,
    'Same workload as another option; the order comes from the rest: this one $freed, $pace.',
    'Misma carga que otra opción; el orden depende del resto: esta $freed, $pace.',
  );
}

/// Minutes an option takes out of its range: finishing or removing a task in
/// the range frees its minutes; other options free none (as the forecast
/// counts them).
int _minutesFreed(TrajectoryBaseline baseline, TrajectoryScenarioOutcome o) {
  final TrajectoryIntervention intervention = o.intervention;
  if (intervention.type != TrajectoryInterventionType.completeTask &&
      intervention.type != TrajectoryInterventionType.reduceScope) {
    return 0;
  }
  final TrajectoryTaskNode? subject = baseline.tasks
      .where((TrajectoryTaskNode t) => t.id == intervention.subjectId)
      .firstOrNull;
  if (subject == null) return 0;
  final TrajectoryHorizonWorkload range =
      FutureConsequenceEngine.horizonWorkload(
        tasks: baseline.tasks,
        now: baseline.observedAt,
        horizonDays: intervention.horizon.inDays,
        completedLast7Days: baseline.completedInWindow,
      );
  if (!range.taskIds.contains(subject.id)) return 0;
  return subject.estimatedMinutes < 0 ? 0 : subject.estimatedMinutes;
}

/// The "keep going" option of a comparison, if it has one.
TrajectoryScenarioOutcome? _keepGoingOutcome(TrajectoryComparison comparison) =>
    comparison.outcomes
        .where(
          (TrajectoryScenarioOutcome o) =>
              o.intervention.type ==
                  TrajectoryInterventionType.maintainCourse &&
              !_isCustomOutcome(o),
        )
        .firstOrNull;

bool _isCustomOutcome(TrajectoryScenarioOutcome outcome) =>
    outcome.intervention.id.startsWith('custom-');

/// The chosen option: by its intervention id when that still exists, else by
/// the same kind of option (for the built-in options).
class _OptionSelection {
  const _OptionSelection(
    this.interventionId,
    this.type, {
    this.isCustom = false,
  });

  factory _OptionSelection.of(TrajectoryScenarioOutcome outcome) =>
      _OptionSelection(
        outcome.intervention.id,
        outcome.intervention.type,
        isCustom: _isCustomOutcome(outcome),
      );

  const _OptionSelection.custom(this.interventionId)
    : type = null,
      isCustom = true;

  final String interventionId;
  final TrajectoryInterventionType? type;
  final bool isCustom;
}

TrajectoryScenarioOutcome? _selectedOutcome(
  TrajectoryComparison? comparison,
  _OptionSelection? selection,
) {
  if (comparison == null || comparison.outcomes.isEmpty) return null;
  if (selection != null) {
    for (final TrajectoryScenarioOutcome outcome in comparison.outcomes) {
      if (outcome.intervention.id == selection.interventionId) return outcome;
    }
    if (!selection.isCustom) {
      for (final TrajectoryScenarioOutcome outcome in comparison.outcomes) {
        if (!_isCustomOutcome(outcome) &&
            outcome.intervention.type == selection.type) {
          return outcome;
        }
      }
    }
  }
  return comparison.recommended ?? comparison.outcomes.first;
}

/// The selected option: its changes against keeping going, goal dates with
/// their assumption, details, and the Review, Track and Exclude actions.
class _SelectedOptionSection extends StatelessWidget {
  const _SelectedOptionSection({
    required this.baseline,
    required this.outcome,
    required this.keepGoing,
    required this.isRecommended,
    required this.onOpen,
    required this.onTrack,
    required this.onCorrect,
  });

  final TrajectoryBaseline baseline;
  final TrajectoryScenarioOutcome outcome;
  final TrajectoryScenarioOutcome? keepGoing;
  final bool isRecommended;
  final VoidCallback onOpen;
  final VoidCallback onTrack;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int keepLoad =
        keepGoing?.projectedPressure ?? baseline.pressureInHorizon;
    final int keepPace = keepGoing?.projectedMomentum ?? baseline.momentum;
    final _Band workload = _Band.of(
      outcome.projectedPressure,
      outcome.uncertainty,
    );
    final _Band pace = _Band.of(outcome.projectedMomentum, outcome.uncertainty);
    return PlainSection(
      title: journeyText(context, 'Selected option', 'Opción elegida'),
      children: <Widget>[
        PlainCard(
          key: const Key('future-outcomes-selected'),
          child: Builder(
            builder: (BuildContext context) {
              final PlainPalette colors = PlainPalette.of(context);
              final TextStyle? secondary = text.bodyMedium?.copyWith(
                color: colors.secondary,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    isRecommended
                        ? journeyText(
                            context,
                            'Recommended adjustment',
                            'Ajuste recomendado',
                          )
                        : _isCustomOutcome(outcome)
                        ? journeyText(
                            context,
                            'Your what-if',
                            'Tu escenario hipotético',
                          )
                        : journeyText(
                            context,
                            'Option you picked',
                            'Opción que elegiste',
                          ),
                    style: text.labelLarge?.copyWith(color: colors.secondary),
                  ),
                  Text(
                    _trajectoryGeneratedText(
                      context,
                      outcome.intervention.title,
                    ),
                    style: text.titleMedium?.copyWith(color: colors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _trajectoryGeneratedText(
                      context,
                      outcome.intervention.description,
                    ),
                    style: secondary,
                  ),
                  PlainMetricRow(
                    key: const Key('selected-workload'),
                    label: journeyText(context, 'Workload', 'Carga de trabajo'),
                    value: journeyText(
                      context,
                      'about ${workload.mid}%',
                      'alrededor del ${workload.mid}%',
                    ),
                    caption: journeyText(
                      context,
                      'Range ${workload.low}–${workload.high}%. Keep going: $keepLoad% (${_changeWords(context, outcome.projectedPressure - keepLoad)}).',
                      'Rango ${workload.low}–${workload.high}%. Si sigues como vas: $keepLoad% (${_changeWords(context, outcome.projectedPressure - keepLoad)}).',
                    ),
                    provenance: ProvenanceKind.estimate,
                  ),
                  PlainMetricRow(
                    key: const Key('selected-pace'),
                    label: journeyText(context, 'Pace', 'Ritmo'),
                    value: journeyText(
                      context,
                      'about ${pace.mid} of 100',
                      'alrededor de ${pace.mid} de 100',
                    ),
                    caption: journeyText(
                      context,
                      '${_paceBand(context, outcome.projectedMomentum)}. Range ${pace.low}–${pace.high}. Keep going: $keepPace (${_changeWords(context, outcome.projectedMomentum - keepPace)}).',
                      '${_paceBand(context, outcome.projectedMomentum)}. Rango ${pace.low}–${pace.high}. Si sigues como vas: $keepPace (${_changeWords(context, outcome.projectedMomentum - keepPace)}).',
                    ),
                    provenance: ProvenanceKind.estimate,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _conciseOutcomeSummary(
                      context: context,
                      keepLoad: keepLoad,
                      keepPace: keepPace,
                      outcome: outcome,
                    ),
                    style: secondary,
                  ),
                  _GoalDates(baseline: baseline, outcome: outcome),
                  const SizedBox(height: 8),
                  _ResultAssumptions(
                    key: ValueKey<String>(
                      'trajectory-assumptions-${outcome.id}',
                    ),
                    assumptions: outcome.assumptions,
                    sharedInformationWarnings: baseline.personContextWarnings,
                  ),
                  PlainDisclosure(
                    key: ValueKey<String>('trajectory-details-${outcome.id}'),
                    title: journeyText(
                      context,
                      'Full impact and evidence',
                      'Impacto completo y datos',
                    ),
                    children: <Widget>[
                      _ScenarioFullDetails(
                        baseline: baseline,
                        outcome: outcome,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                    ),
                    icon: Icon(
                      outcome.intervention.type ==
                              TrajectoryInterventionType.applySmartPlanner
                          ? Icons.auto_awesome_rounded
                          : Icons.timeline_rounded,
                    ),
                    label: Text(
                      outcome.intervention.type ==
                              TrajectoryInterventionType.applySmartPlanner
                          ? journeyText(
                              context,
                              'Review adjustment',
                              'Revisar ajuste',
                            )
                          : journeyText(
                              context,
                              'Review on Schedule',
                              'Revisar en agenda',
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onTrack,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                    ),
                    icon: const Icon(Icons.query_stats_rounded),
                    label: Text(
                      journeyText(
                        context,
                        'Track this option for monitoring',
                        'Supervisar esta opción',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('trajectory-correct-assumptions'),
                    onPressed: onCorrect,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                    ),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: Text(
                      journeyText(
                        context,
                        'Exclude this forecast from monitoring',
                        'Excluir esta previsión del seguimiento',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

String _conciseOutcomeSummary({
  required BuildContext context,
  required int keepLoad,
  required int keepPace,
  required TrajectoryScenarioOutcome outcome,
}) {
  final int days = outcome.intervention.horizon.inDays;
  final int paceDelta = outcome.projectedMomentum - keepPace;
  final int loadDelta = outcome.projectedPressure - keepLoad;
  String change(int delta, String en, String es, {required bool spanish}) {
    final int size = delta.abs();
    if (spanish) {
      return delta == 0
          ? '$es sin cambios'
          : '$es ${delta > 0 ? 'subiendo' : 'bajando'} $size punto${size == 1 ? '' : 's'}';
    }
    return delta == 0
        ? '$en unchanged'
        : '$en ${delta > 0 ? 'up' : 'down'} $size point${size == 1 ? '' : 's'}';
  }

  if (Localizations.localeOf(context).languageCode == 'es') {
    return 'Frente a seguir como vas, esta opción estima '
        '${change(paceDelta, 'pace', 'el ritmo', spanish: true)} y '
        '${change(loadDelta, 'workload', 'la carga', spanish: true)} en los '
        'próximos $days días. El periodo cambia la estimación: decide qué '
        'tareas cuentan y cuánto tiempo libre hay, y cuanto más lejos, menos '
        'fiable, por eso los rangos son más amplios.';
  }
  return 'Compared with keeping going, this option estimates '
      '${change(paceDelta, 'pace', 'el ritmo', spanish: false)} and '
      '${change(loadDelta, 'workload', 'la carga', spanish: false)} over the '
      'next $days days. The range changes the estimate: it sets which tasks '
      'count and how much free time there is, and further ahead is less '
      'reliable, so the ranges are wider.';
}

/// Goal dates of the selected option, each beside its stated assumption, or
/// why they are held back.
class _GoalDates extends StatelessWidget {
  const _GoalDates({required this.baseline, required this.outcome});

  final TrajectoryBaseline baseline;
  final TrajectoryScenarioOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final PlainPalette colors = PlainPalette.of(context);
    final MaterialLocalizations dates = MaterialLocalizations.of(context);
    if (outcome.goals.isEmpty) {
      if (baseline.hasObservedAvailability || baseline.goals.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          journeyText(
            context,
            'Goal dates and the recommendation are held back until your working hours are set.',
            'Las fechas de las metas y la recomendación se omiten hasta que configures tu horario de trabajo.',
          ),
          style: text.bodyMedium?.copyWith(color: colors.secondary),
        ),
      );
    }
    return Column(
      key: const Key('selected-goal-dates'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          journeyText(context, 'Goal dates', 'Fechas de las metas'),
          style: text.titleSmall?.copyWith(color: colors.primary),
        ),
        for (final GoalDelayProjection goal in outcome.goals)
          PlainMetricRow(
            label: goal.goalTitle,
            value: journeyText(
              context,
              'about ${dates.formatMediumDate(goal.projectedCompletion.toLocal())}',
              'hacia el ${dates.formatMediumDate(goal.projectedCompletion.toLocal())}',
            ),
            caption:
                '${dates.formatMediumDate(goal.lowerCompletion.toLocal())}–${dates.formatMediumDate(goal.upperCompletion.toLocal())}. ${_trajectoryGeneratedText(context, goal.explanation)}',
            provenance: ProvenanceKind.estimate,
          ),
        Text(
          _trajectoryGeneratedText(context, trajectoryGoalDateAssumption),
          key: const Key('selected-goal-date-assumption'),
          style: text.bodyMedium?.copyWith(color: colors.secondary),
        ),
      ],
    );
  }
}
