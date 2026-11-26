part of 'trajectory_engine_screen.dart';

/// The forecast's status, shown unless the estimate is simply ready.
class _TrajectoryStateNotice extends StatelessWidget {
  const _TrajectoryStateNotice({
    required this.status,
    required this.detail,
    required this.onRetry,
    required this.onCreate,
  });

  final TrajectoryEngineStatus status;
  final String detail;
  final VoidCallback onRetry;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (status == TrajectoryEngineStatus.ready) return const SizedBox.shrink();
    final String label = _trajectoryStatusLabel(context, status);
    final String localizedDetail = _trajectoryStatusDetail(
      context,
      status,
      detail,
    );
    final bool needsAction =
        status == TrajectoryEngineStatus.error ||
        status == TrajectoryEngineStatus.empty;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: PlainCard(
        key: const Key('future-outcomes-status'),
        child: Builder(
          builder: (BuildContext context) {
            final PlainPalette colors = PlainPalette.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  label,
                  style: text.titleSmall?.copyWith(color: colors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  localizedDetail,
                  style: text.bodyMedium?.copyWith(color: colors.secondary),
                ),
                if (needsAction) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton(
                      onPressed: status == TrajectoryEngineStatus.empty
                          ? onCreate
                          : onRetry,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          AppSizes.touchTarget,
                          AppSizes.touchTarget,
                        ),
                      ),
                      child: Text(
                        status == TrajectoryEngineStatus.empty
                            ? journeyText(
                                context,
                                'Add a task',
                                'Añadir una tarea',
                              )
                            : journeyText(context, 'Retry', 'Reintentar'),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Secondary text in the card palette.
TextStyle? _secondaryText(BuildContext context) => Theme.of(
  context,
).textTheme.bodyMedium?.copyWith(color: PlainPalette.of(context).secondary);

/// A small heading inside a card.
Widget _cardHeading(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 4),
  child: Text(
    title,
    // At least as large as the row labels under it.
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: PlainPalette.of(context).primary),
  ),
);

/// Bulleted lines in the card palette.
Widget _bullets(BuildContext context, List<String> lines) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    for (final String line in lines)
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('• $line', style: _secondaryText(context)),
      ),
  ],
);

/// "What this is based on": the records and assumptions behind the estimate.
class _BasedOnDetails extends StatelessWidget {
  const _BasedOnDetails({required this.baseline, required this.model});

  final TrajectoryBaseline baseline;
  final TrajectoryEngineModel model;

  @override
  Widget build(BuildContext context) {
    final bool isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final String freeTime =
        baseline.dailyFreeOrigin == PredictiveEvidenceOrigin.observed
        ? journeyText(
            context,
            'From your working hours.',
            'De tu horario de trabajo.',
          )
        : journeyText(
            context,
            'From an assumed workday (no working hours set).',
            'De una jornada supuesta (sin horario de trabajo).',
          );
    final String energy = baseline.hasObservedEnergy
        ? (isSpanish ? 'registrada' : 'recorded')
        : isSpanish
        ? _spanishUnobservedEvidenceState(baseline.energyOrigin)
        : _englishUnobservedEvidenceState(baseline.energyOrigin);
    final String availability = baseline.hasObservedAvailability
        ? (isSpanish ? 'registrada' : 'recorded')
        : isSpanish
        ? _spanishUnobservedEvidenceState(baseline.availabilityOrigin)
        : _englishUnobservedEvidenceState(baseline.availabilityOrigin);
    final List<String> assumptions = _trajectoryAssumptionTexts(
      context,
      baseline.assumptions,
      const <String>[],
    ).where((String a) => a.trim().isNotEmpty).toList(growable: false);
    return Column(
      key: const Key('future-outcomes-based-on-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PlainMetricRow(
          label: journeyText(
            context,
            'Task outcomes recorded',
            'Resultados de tareas registrados',
          ),
          value: '${baseline.observationCount}',
          caption: journeyText(
            context,
            'In the last ${baseline.evidenceWindow.inDays} days: ${baseline.completedInWindow} finished, ${baseline.deferredInWindow} put off.',
            'En los últimos ${baseline.evidenceWindow.inDays} días: ${baseline.completedInWindow} terminadas, ${baseline.deferredInWindow} aplazadas.',
          ),
          provenance: ProvenanceKind.recorded,
        ),
        PlainMetricRow(
          label: journeyText(context, 'Free time a day', 'Tiempo libre al día'),
          value: journeyText(
            context,
            '${baseline.dailyFreeMinutes} min',
            '${baseline.dailyFreeMinutes} min',
          ),
          caption: freeTime,
          provenance:
              baseline.dailyFreeOrigin == PredictiveEvidenceOrigin.observed
              ? ProvenanceKind.plan
              : ProvenanceKind.estimate,
        ),
        PlainMetricRow(
          label: journeyText(
            context,
            'Work needed in this range',
            'Trabajo necesario en este periodo',
          ),
          value: '${baseline.requiredMinutesInHorizon} min',
          provenance: ProvenanceKind.plan,
        ),
        PlainMetricRow(
          label: journeyText(context, 'Pace now', 'Ritmo actual'),
          value: journeyText(
            context,
            '${_paceBand(context, baseline.momentum)}, ${baseline.momentum} of 100',
            '${_paceBand(context, baseline.momentum)}, ${baseline.momentum} de 100',
          ),
          provenance: ProvenanceKind.estimate,
        ),
        PlainMetricRow(
          label: journeyText(context, 'Energy', 'Energía'),
          value: baseline.hasObservedEnergy
              ? '${baseline.energy}%'
              : journeyText(context, 'Not recorded', 'Sin registro'),
          provenance: baseline.hasObservedEnergy
              ? ProvenanceKind.recorded
              : null,
        ),
        PlainMetricRow(
          label: journeyText(
            context,
            'Unscheduled work',
            'Trabajo sin programar',
          ),
          value: baseline.hasObservedAvailability
              ? '${baseline.unscheduledMinutes} min'
              : journeyText(context, 'Not worked out', 'Sin calcular'),
          // The planner's capacity for today, not the selected range.
          caption: journeyText(
            context,
            'Today, not the selected range.',
            'Hoy, no el periodo elegido.',
          ),
          provenance: baseline.hasObservedAvailability
              ? ProvenanceKind.plan
              : null,
        ),
        PlainMetricRow(
          label: journeyText(context, 'Progress', 'Progreso'),
          value: journeyText(
            context,
            'Level ${baseline.progression.level}, ${baseline.progression.streak}-day streak',
            'Nivel ${baseline.progression.level}, racha de ${baseline.progression.streak} días',
          ),
          provenance: ProvenanceKind.recorded,
        ),
        const SizedBox(height: 4),
        Text(
          isSpanish
              ? '${baseline.tasks.length} tarea(s), ${baseline.goals.length} meta(s) activa(s), '
                    '${baseline.blocks.length} bloque(s) planificado(s) y ${baseline.timelineSignals.length} señal(es) vinculada(s) de la agenda.'
              : '${baseline.tasks.length} task(s), ${baseline.goals.length} active goal(s), '
                    '${baseline.blocks.length} planned block(s), and ${baseline.timelineSignals.length} linked Schedule signal(s).',
          style: _secondaryText(context),
        ),
        const SizedBox(height: 4),
        Text(
          isSpanish
              ? 'Energía: $energy. Disponibilidad: $availability. Las duraciones de las tareas son estimaciones y los efectos de las fechas límite son proyecciones.'
              : 'Energy: $energy. Availability: $availability. Task durations are estimates and deadline effects are projections.',
          style: _secondaryText(context),
        ),
        const SizedBox(height: 4),
        Text(
          isSpanish
              ? 'Confianza ${_trajectoryConfidenceLabel(context, baseline.confidence.band)} • datos de los últimos ${baseline.evidenceWindow.inDays} días'
              : '${_trajectoryConfidenceLabel(context, baseline.confidence.band)} confidence • records from the last ${baseline.evidenceWindow.inDays} days',
          style: _secondaryText(context),
        ),
        if (baseline.personContextWarnings.isNotEmpty) ...<Widget>[
          _cardHeading(
            context,
            journeyText(
              context,
              'Information you shared',
              'Información que compartiste',
            ),
          ),
          Text(
            isSpanish
                ? 'Esta estimación: ${baseline.availableMinutes} min disponibles / ${baseline.unscheduledMinutes} min sin programar. '
                      'Comparación sin información compartida: ${baseline.noContextAvailableMinutes} min disponibles / ${baseline.noContextUnscheduledMinutes} min sin programar.'
                : 'This estimate: ${baseline.availableMinutes}m available / ${baseline.unscheduledMinutes}m unscheduled. '
                      'Comparison without shared information: ${baseline.noContextAvailableMinutes}m available / ${baseline.noContextUnscheduledMinutes}m unscheduled.',
            style: _secondaryText(context),
          ),
          const SizedBox(height: 4),
          _bullets(context, <String>[
            for (final String warning in baseline.personContextWarnings)
              _trajectorySharedInformationWarningText(context, warning),
          ]),
        ],
        _cardHeading(context, journeyText(context, 'Assumptions', 'Supuestos')),
        if (assumptions.isEmpty)
          Text(
            journeyText(
              context,
              'No extra assumptions for your plan now.',
              'No hay supuestos adicionales para tu plan actual.',
            ),
            style: _secondaryText(context),
          )
        else
          _bullets(context, assumptions),
        _cardHeading(
          context,
          journeyText(
            context,
            'Follow-through on your tasks',
            'Cumplimiento de tus tareas',
          ),
        ),
        _TaskPredictionDetails(model: model),
      ],
    );
  }
}

/// Today's planning summary (the decision provider's snapshot), in plain
/// rows. Its figures are today's, not the selected range's, and say so.
class _PlanningSummary extends StatelessWidget {
  const _PlanningSummary({required this.intelligence, required this.onAction});

  final DecisionIntelligence intelligence;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final OperatingSnapshot snapshot = intelligence.snapshot;
    final OperatingDecisionReceipt decision = intelligence.decision;
    final bool isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final String today = journeyText(
      context,
      'Today, not the selected range.',
      'Hoy, no el periodo elegido.',
    );
    final String confidence = switch (decision.confidence) {
      OperatingConfidence.high => journeyText(context, 'high', 'alta'),
      OperatingConfidence.moderate => journeyText(
        context,
        'moderate',
        'moderada',
      ),
      OperatingConfidence.low => journeyText(context, 'low', 'baja'),
      OperatingConfidence.insufficientEvidence => journeyText(
        context,
        'insufficient',
        'insuficiente',
      ),
    };
    return Column(
      key: const Key('future-outcomes-planning-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _cardHeading(
          context,
          journeyText(
            context,
            "Today's planning summary",
            'Resumen de planificación de hoy',
          ),
        ),
        Text(
          journeyText(
            context,
            'From your records and plan today. Confidence: $confidence.',
            'De tus registros y tu plan de hoy. Confianza: $confidence.',
          ),
          style: _secondaryText(context),
        ),
        PlainMetricRow(
          label: journeyText(context, 'To do', 'Por hacer'),
          value: '${snapshot.actionableCount}',
          provenance: ProvenanceKind.recorded,
        ),
        PlainMetricRow(
          label: journeyText(context, 'Overdue', 'Vencidas'),
          value: '${snapshot.overdueCount}',
          provenance: ProvenanceKind.recorded,
        ),
        PlainMetricRow(
          label: journeyText(context, 'Finished today', 'Terminadas hoy'),
          value: '${snapshot.completedToday}',
          provenance: ProvenanceKind.recorded,
        ),
        // No "workload" row here: the planning summary's score counts open
        // tasks, which is a different measure from the forecast's
        // capacity-based workload, the only figure this screen calls workload.
        PlainMetricRow(
          label: journeyText(context, 'Pace today', 'Ritmo hoy'),
          value: journeyText(
            context,
            '${_paceBand(context, snapshot.momentum)}, ${snapshot.momentum} of 100',
            '${_paceBand(context, snapshot.momentum)}, ${snapshot.momentum} de 100',
          ),
          caption: today,
          provenance: ProvenanceKind.estimate,
        ),
        _cardHeading(
          context,
          journeyText(context, 'What changed', 'Qué cambió'),
        ),
        Text(
          _planningChanges(context, intelligence.delta, isSpanish),
          style: _secondaryText(context),
        ),
        _cardHeading(
          context,
          journeyText(context, 'What matters next', 'Qué importa ahora'),
        ),
        Text(
          decision.recommendedAction,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: PlainPalette.of(context).primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        _cardHeading(context, journeyText(context, 'Why', 'Por qué')),
        Text(
          '${decision.rationale} ${decision.whyItMatters}',
          style: _secondaryText(context),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton(
            onPressed: decision.isExpired ? null : onAction,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                AppSizes.touchTarget,
                AppSizes.touchTarget,
              ),
            ),
            child: Text(_planningActionLabel(decision.actionIntent, isSpanish)),
          ),
        ),
      ],
    );
  }
}

/// What changed since the last summary, in the glossary's words.
String _planningChanges(
  BuildContext context,
  OperatingDelta delta,
  bool isSpanish,
) {
  if (delta.isBaseline) {
    return journeyText(
      context,
      'This is the first summary; later ones show what changed.',
      'Es el primer resumen; los siguientes muestran qué cambió.',
    );
  }
  // The summary's risk score counts open tasks; it is not the forecast's
  // workload, so its change is not listed under that name (or any other).
  final List<OperatingChange> changes = delta.materialChanges
      .where((OperatingChange item) => item.kind != OperatingChangeKind.risk)
      .toList(growable: false);
  if (changes.isEmpty) {
    return delta.previousSnapshotId == delta.currentSnapshotId
        ? journeyText(
            context,
            'No important changes since the last check.',
            'No hubo cambios importantes desde la última revisión.',
          )
        : journeyText(
            context,
            'Your records changed, but nothing important for this choice.',
            'Tus registros cambiaron, pero nada importante para esta elección.',
          );
  }
  return changes
      .take(3)
      .map((OperatingChange item) {
        final String label = switch (item.kind) {
          OperatingChangeKind.priority => journeyText(
            context,
            'Top action',
            'Acción principal',
          ),
          OperatingChangeKind.schedule => journeyText(
            context,
            'Overdue',
            'Vencidas',
          ),
          OperatingChangeKind.momentum => journeyText(context, 'Pace', 'Ritmo'),
          // Filtered out above.
          OperatingChangeKind.risk => '',
          OperatingChangeKind.progression => journeyText(
            context,
            'Finished today',
            'Terminadas hoy',
          ),
          OperatingChangeKind.evidence => journeyText(
            context,
            'Records available',
            'Registros disponibles',
          ),
        };
        return '$label: ${item.previousValue} ${isSpanish ? 'a' : 'to'} ${item.currentValue}';
      })
      .join('. ');
}

String _planningActionLabel(OperatingActionIntent intent, bool isSpanish) {
  // This action opens My plan (not the Schedule), so it says so; the
  // selected option's "Review on Schedule" is the one that opens Schedule.
  if (intent.type == OperatingActionType.openTimeline) {
    return isSpanish ? 'Abrir Mi plan' : 'Open My plan';
  }
  if (!isSpanish) return intent.label;
  return switch (intent.type) {
    OperatingActionType.openCreator => 'Añadir algo',
    OperatingActionType.openSmartPlanner => 'Revisar en Elegir un paso',
    OperatingActionType.openSiConsole => 'Revisar evidencia en Chat',
    OperatingActionType.openTrajectoryEngine =>
      'Revisar riesgo en Perspectivas',
    OperatingActionType.openProgression => 'Revisar recuperación en Patrones',
    OperatingActionType.openTimeline => 'Revisar en agenda',
    _ => intent.label,
  };
}

/// How often tasks like the next one were finished, from recorded outcomes.
class _TaskPredictionDetails extends StatelessWidget {
  const _TaskPredictionDetails({required this.model});

  final TrajectoryEngineModel model;

  @override
  Widget build(BuildContext context) {
    final summary = model.summary;
    if (!summary.hasPrediction) {
      return Text(
        _trajectoryGeneratedText(context, summary.statusDetail),
        style: _secondaryText(context),
      );
    }
    final bool pooledHistory = (summary.predictionExplanation ?? '').startsWith(
      'No exact task history exists,',
    );
    final int probability = ((summary.predictionProbability ?? 0) * 100)
        .round();
    final int lower = ((summary.predictionLowerBound ?? 0) * 100).round();
    final int upper = ((summary.predictionUpperBound ?? 1) * 100).round();
    final PlainPalette colors = PlainPalette.of(context);
    return Column(
      key: const Key('future-outcomes-follow-through'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          summary.predictionSampleSize == 0
              ? journeyText(
                  context,
                  'No recorded task outcomes are available for this estimate.',
                  'No hay resultados de tareas registrados disponibles para esta estimación.',
                )
              : pooledHistory
              ? journeyText(
                  context,
                  'Across ${summary.predictionSampleSize} recorded task outcomes — no history for this task.',
                  'Basado en ${summary.predictionSampleSize} resultados de otras tareas; sin historial para esta tarea.',
                )
              : journeyText(
                  context,
                  'Based on ${summary.predictionSampleSize} recorded task outcomes.',
                  'Basado en ${summary.predictionSampleSize} resultados de tareas registrados.',
                ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.predictionTitle}: ${_trajectoryGeneratedText(context, summary.predictionOutcome ?? '')}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: 4),
        Text(
          Localizations.localeOf(context).languageCode == 'es'
              ? '$probability% de finalización estimada • intervalo $lower–$upper% • ${summary.predictionSampleSize} resultados'
              : '$probability% smoothed completion estimate • $lower–$upper% interval • ${summary.predictionSampleSize} outcomes',
          style: _secondaryText(context),
        ),
        const SizedBox(height: 4),
        Text(
          _trajectoryGeneratedText(
            context,
            summary.predictionExplanation ?? '',
          ),
          style: _secondaryText(context),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.predictionEvidenceSufficient ? journeyText(context, 'Established history', 'Historial consolidado') : journeyText(context, 'Limited history', 'Historial limitado')} • ${summary.predictionModelVersion ?? journeyText(context, 'method unavailable', 'método no disponible')}',
          style: _secondaryText(context),
        ),
        const SizedBox(height: 4),
        const ProvenanceLabel(ProvenanceKind.estimate),
      ],
    );
  }
}

/// "Forecast monitoring": what recorded accuracy does to the ranges, and that
/// the keep-going forecast is recorded automatically on this device.
class _MonitoringDetails extends StatelessWidget {
  const _MonitoringDetails({required this.summary});

  final AsyncValue<TrajectoryCalibrationSummary> summary;

  @override
  Widget build(BuildContext context) {
    final bool isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final TrajectoryCalibrationSummary? value = summary.asData?.value;
    // Label and text follow the rule actually applied to the ranges.
    final bool adjusting =
        value != null &&
        !TrajectoryCalibrationAdjustment.fromSummary(value).isProvisional;
    final String state = value == null
        ? (summary.isLoading
              ? (isSpanish ? 'cargando' : 'loading')
              : (isSpanish ? 'no disponible' : 'unavailable'))
        : !adjusting
        ? 'provisional'
        : (isSpanish ? 'supervisado' : 'monitored');
    final String? earlier = value == null || value.earlierMethodForecasts == 0
        ? null
        : isSpanish
        ? 'Conservadas de un método anterior pero no usadas: ${value.earlierMethodForecasts}.'
        : 'Kept from an earlier method but not used: ${value.earlierMethodForecasts}.';
    final List<String> lines = <String>[
      if (value == null)
        isSpanish
            ? 'La información de seguimiento no está disponible ahora.'
            : 'Monitoring information is not available right now.'
      else if (value.resolvedForecasts == 0)
        isSpanish
            ? 'Ninguna previsión registrada ha llegado aún a su fecha final, así que los rangos se mantienen como se estimaron.'
            : 'No recorded forecast has reached its end date yet, so the ranges stay as estimated.'
      else ...<String>[
        isSpanish
            ? '${value.resolvedForecasts} previsiones comprobadas • error medio de ritmo ${value.momentumMeanAbsoluteError.toStringAsFixed(1)} puntos • error medio de carga ${value.pressureMeanAbsoluteError.toStringAsFixed(1)} puntos • ${(value.intervalCoverage * 100).round()}% dentro de su rango.'
            : '${value.resolvedForecasts} forecasts checked • average pace error ${value.momentumMeanAbsoluteError.toStringAsFixed(1)} points • average workload error ${value.pressureMeanAbsoluteError.toStringAsFixed(1)} points • ${(value.intervalCoverage * 100).round()}% inside their range.',
        isSpanish
            ? 'La parte dentro del rango usa solo el ritmo y se promedia por los días en que se comprobaron las previsiones.'
            : 'The share inside the range uses pace only and is averaged over the days forecasts were checked.',
        adjusting
            ? (isSpanish
                  ? 'Los rangos se amplían según la precisión registrada cuando hay al menos 3 previsiones comprobadas en 2 o más días, y solo se estrechan tras comprobaciones en 5 o más días repartidos en al menos 14 días. Previsiones usadas: ${value.resolvedForecasts}.'
                  : 'Ranges are widened from recorded accuracy once at least 3 forecasts have been checked on 2 or more days, and narrowed only after checks on 5 or more days spread over at least 14 days. Forecasts used: ${value.resolvedForecasts}.')
            : (isSpanish
                  ? 'Los rangos se mantienen como se estimaron hasta que haya al menos 3 previsiones comprobadas en 2 o más días. Comprobadas hasta ahora: ${value.resolvedForecasts}.'
                  : 'Ranges stay as estimated until at least 3 forecasts have been checked on 2 or more days. Checked so far: ${value.resolvedForecasts}.'),
      ],
      ?earlier,
      isSpanish
          ? 'La previsión de “seguir como vas” se registra automáticamente en este dispositivo: como mucho una vez al día para 7 días y una vez a la semana para 30 y 90 días. Nada sale de este dispositivo.'
          : 'The “keep going” forecast is recorded automatically on this device: at most once a day for 7 days, and once a week for 30 and 90 days. Nothing leaves this device.',
    ];
    final PlainPalette colors = PlainPalette.of(context);
    return Column(
      key: const Key('future-outcomes-monitoring-details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isSpanish ? 'Estado: $state' : 'Status: $state',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: 4),
        for (final String line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: _secondaryText(context)),
          ),
      ],
    );
  }
}

/// "How this helps you", in plain words, true of the current forecast.
class _HowThisHelps extends StatelessWidget {
  const _HowThisHelps();

  @override
  Widget build(BuildContext context) {
    return _bullets(context, <String>[
      journeyText(
        context,
        'It reads what you already put in Axiomara: your tasks with their dates and times, your goals, your working hours and your energy check-ins.',
        'Lee lo que ya pusiste en Axiomara: tus tareas con sus fechas y horas, tus metas, tu horario de trabajo y tus registros de energía.',
      ),
      journeyText(
        context,
        'It shows a few options: keep going as you are, let the planner rearrange your day, finish a task, put one off, cut something, or catch up on something you missed.',
        'Muestra algunas opciones: seguir como vas, dejar que el planificador reorganice tu día, terminar una tarea, aplazar una, recortar algo o ponerte al día con algo pendiente.',
      ),
      journeyText(
        context,
        'Pick an option to see how your workload and pace could change. The time range (7, 30 or 90 days) changes the estimate: it sets which tasks count and how much free time there is. Further ahead is less reliable, so the ranges are wider. “Recommended adjustment” marks the option that looks best right now, once there is enough history.',
        'Elige una opción para ver cómo podrían cambiar tu carga de trabajo y tu ritmo. El periodo (7, 30 o 90 días) cambia la estimación: decide qué tareas cuentan y cuánto tiempo libre hay. Cuanto más lejos, menos fiable, por eso los rangos son más amplios. “Ajuste recomendado” marca la opción que mejor se ve ahora, cuando hay suficiente historial.',
      ),
      journeyText(
        context,
        'Nothing changes until you tap Review to act on an option. These are estimates, not promises.',
        'Nada cambia hasta que tocas Revisar para actuar. Son estimaciones, no promesas.',
      ),
      journeyText(
        context,
        '${InsightsCopy.patternsEn} shows what you have actually done: tasks finished, habits and streaks. Use the switch at the top to open it.',
        'En ${InsightsCopy.patternsEs} ves lo que de verdad hiciste: tareas terminadas, hábitos y rachas. Usa el selector de arriba para abrir esa parte.',
      ),
      journeyText(
        context,
        'It needs a few tasks with times and some recorded outcomes before it has much to show. The more you use Axiomara, the more useful it gets.',
        'Necesita algunas tareas con horario y algunos resultados registrados antes de mostrar mucho. Cuanto más uses Axiomara, más útil es.',
      ),
    ]);
  }
}

/// "Exploring does not change your plan", plus the option's assumptions.
class _ResultAssumptions extends StatelessWidget {
  const _ResultAssumptions({
    super.key,
    required this.assumptions,
    required this.sharedInformationWarnings,
  });

  final List<String> assumptions;
  final List<String> sharedInformationWarnings;

  @override
  Widget build(BuildContext context) {
    final List<String> visible =
        _trajectoryAssumptionTexts(
              context,
              assumptions,
              sharedInformationWarnings,
            )
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          journeyText(
            context,
            'Exploring this estimate does not change your saved plan.',
            'Explorar esta estimación no cambia tu plan guardado.',
          ),
          style: _secondaryText(context),
        ),
        if (sharedInformationWarnings.any(
          (String warning) => warning.trim().isNotEmpty,
        )) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            journeyText(
              context,
              'Review the assumptions for limits or missing details in information you shared.',
              'Revisa los supuestos para conocer los límites o datos que faltan en la información que compartiste.',
            ),
            style: _secondaryText(context),
          ),
        ],
        PlainDisclosure(
          title: journeyText(
            context,
            'What this estimate assumes',
            'Supuestos de esta estimación',
          ),
          children: <Widget>[
            if (visible.isEmpty)
              Text(
                journeyText(
                  context,
                  'No additional assumptions were listed. Task durations and future free time are estimates.',
                  'No se indicaron supuestos adicionales. Las duraciones y el tiempo libre futuro son estimaciones.',
                ),
                style: _secondaryText(context),
              )
            else
              _bullets(context, visible),
          ],
        ),
      ],
    );
  }
}

/// Everything else about the selected option, behind "Full impact and
/// evidence".
class _ScenarioFullDetails extends StatelessWidget {
  const _ScenarioFullDetails({required this.baseline, required this.outcome});

  final TrajectoryBaseline baseline;
  final TrajectoryScenarioOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final _Band risk = _Band.of(
      outcome.risk.projectedScore,
      outcome.uncertainty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${journeyText(context, 'Confidence', 'Confianza')}: ${_trajectoryConfidenceLabel(context, outcome.confidence.band)} · ±${outcome.uncertainty} ${journeyText(context, 'points', 'puntos')}',
          style: _secondaryText(context),
        ),
        PlainMetricRow(
          label: journeyText(context, 'Risk building up', 'Riesgo acumulado'),
          value: journeyText(
            context,
            'about ${risk.mid} of 100',
            'alrededor de ${risk.mid} de 100',
          ),
          caption: journeyText(
            context,
            'Range ${risk.low}–${risk.high}. Now: ${outcome.risk.currentScore}.',
            'Rango ${risk.low}–${risk.high}. Ahora: ${outcome.risk.currentScore}.',
          ),
          provenance: ProvenanceKind.estimate,
        ),
        _cardHeading(
          context,
          journeyText(
            context,
            'Why this changes the estimate',
            'Por qué cambia la estimación',
          ),
        ),
        Text(
          _trajectoryGeneratedText(context, outcome.explanation),
          style: _secondaryText(context),
        ),
        _cardHeading(
          context,
          journeyText(
            context,
            'Effect on your Schedule',
            'Efecto en tu agenda',
          ),
        ),
        Text(
          _trajectoryGeneratedText(context, outcome.timeline.summary),
          style: _secondaryText(context),
        ),
        _cardHeading(
          context,
          journeyText(context, 'Effect on progress', 'Efecto en el progreso'),
        ),
        Text(
          _trajectoryGeneratedText(context, outcome.progression.summary),
          style: _secondaryText(context),
        ),
        _cardHeading(
          context,
          journeyText(
            context,
            'What adds to the risk',
            'Qué aumenta el riesgo',
          ),
        ),
        _bullets(context, <String>[
          for (final TrajectoryRiskContribution item
              in outcome.risk.contributions)
            '${_trajectoryGeneratedText(context, item.label)}: ${item.isScored ? '${item.currentScore}/100 → ${item.projectedScore}/100' : journeyText(context, 'not scored', 'sin calcular')}. ${_trajectoryGeneratedText(context, item.explanation)}',
        ]),
        _cardHeading(
          context,
          journeyText(
            context,
            'What this option is based on',
            'En qué se basa esta opción',
          ),
        ),
        _bullets(context, <String>[
          journeyText(
            context,
            '${baseline.observationCount} recorded outcomes in the last ${baseline.evidenceWindow.inDays} days.',
            '${baseline.observationCount} resultados registrados en los últimos ${baseline.evidenceWindow.inDays} días.',
          ),
          journeyText(
            context,
            '${baseline.completedInWindow} completed and ${baseline.deferredInWindow} deferred outcomes.',
            '${baseline.completedInWindow} resultados completados y ${baseline.deferredInWindow} aplazados.',
          ),
          journeyText(
            context,
            baseline.hasObservedAvailability
                ? '${baseline.availableMinutes} minutes of configured working time.'
                : 'Working availability has not been provided.',
            baseline.hasObservedAvailability
                ? '${baseline.availableMinutes} minutos de tiempo de trabajo configurado.'
                : 'No se ha indicado la disponibilidad de trabajo.',
          ),
        ]),
        Text(
          '${journeyText(context, 'Generated', 'Generado')} ${localizations.formatMediumDate(outcome.generatedAt.toLocal())}',
          style: _secondaryText(context),
        ),
        const SizedBox(height: 8),
        Text(
          journeyText(
            context,
            'Simulation only: no task, Schedule block, goal or progress reward is changed here.',
            'Solo simulación: aquí no cambia ninguna tarea, bloque, meta ni recompensa.',
          ),
          style: _secondaryText(context),
        ),
      ],
    );
  }
}

class _CustomScenarioComposer extends StatefulWidget {
  const _CustomScenarioComposer({
    required this.baseline,
    required this.horizonDays,
    required this.onComposed,
    required this.onClear,
    required this.onDraftChanged,
    this.feedback,
  });

  final Widget? feedback;
  final TrajectoryBaseline baseline;
  final int horizonDays;
  final ValueChanged<TrajectoryCustomScenarioDraft> onComposed;
  final VoidCallback onClear;
  final VoidCallback onDraftChanged;

  @override
  State<_CustomScenarioComposer> createState() =>
      _CustomScenarioComposerState();
}

class _CustomScenarioComposerState extends State<_CustomScenarioComposer> {
  String? _subjectId;
  TrajectoryCustomAdjustment _adjustment = TrajectoryCustomAdjustment.complete;
  double _delayDays = 1;
  bool _draftChanged = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.baseline.tasks.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant _CustomScenarioComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.baseline.tasks.any(
      (TrajectoryTaskNode task) => task.id == _subjectId,
    )) {
      final nextSubjectId = widget.baseline.tasks.firstOrNull?.id;
      if (nextSubjectId != _subjectId) {
        _subjectId = nextSubjectId;
        _draftChanged = true;
        widget.onDraftChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.baseline.tasks.isEmpty) return const SizedBox.shrink();
    final bool showsDelay = _adjustment == TrajectoryCustomAdjustment.delay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          journeyText(
            context,
            'Choose one change. Axiomara compares its effect on workload, risk, goal dates, Schedule and progress without changing your real plan.',
            'Elige un cambio concreto. Axiomara compara su efecto en la carga, el riesgo, las fechas de las metas, la agenda y el progreso sin cambiar tu plan real.',
          ),
          style: _secondaryText(context),
        ),
        const SizedBox(height: 12),
        DropdownRouteKeyboardGuard(
          child: DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: journeyText(
                context,
                'Commitment to change',
                'Compromiso que quieres cambiar',
              ),
            ),
            items: widget.baseline.tasks
                .map(
                  (TrajectoryTaskNode task) => DropdownMenuItem<String>(
                    value: task.id,
                    child: Text(task.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value == _subjectId) return;
              widget.onDraftChanged();
              setState(() {
                _subjectId = value;
                _draftChanged = true;
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<TrajectoryCustomAdjustment>(
          segments: <ButtonSegment<TrajectoryCustomAdjustment>>[
            ButtonSegment<TrajectoryCustomAdjustment>(
              value: TrajectoryCustomAdjustment.complete,
              label: Text(journeyText(context, 'Complete', 'Completar')),
              icon: const Icon(Icons.check_rounded),
            ),
            ButtonSegment<TrajectoryCustomAdjustment>(
              value: TrajectoryCustomAdjustment.delay,
              label: Text(journeyText(context, 'Delay', 'Aplazar')),
              icon: const Icon(Icons.schedule_rounded),
            ),
            ButtonSegment<TrajectoryCustomAdjustment>(
              value: TrajectoryCustomAdjustment.reduceScope,
              label: Text(journeyText(context, 'Remove', 'Quitar')),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ],
          selected: <TrajectoryCustomAdjustment>{_adjustment},
          showSelectedIcon: false,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              final colors = Theme.of(context).colorScheme;
              return states.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.onSurface;
            }),
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              final colors = Theme.of(context).colorScheme;
              return states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surface;
            }),
            minimumSize: const WidgetStatePropertyAll<Size>(
              Size(0, AppSizes.touchTarget),
            ),
            textStyle: const WidgetStatePropertyAll<TextStyle>(
              TextStyle(letterSpacing: 0),
            ),
          ),
          onSelectionChanged: (Set<TrajectoryCustomAdjustment> selected) {
            if (selected.first == _adjustment) return;
            widget.onDraftChanged();
            setState(() {
              _adjustment = selected.first;
              _draftChanged = true;
            });
          },
        ),
        if (showsDelay) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            Localizations.localeOf(context).languageCode == 'es'
                ? 'Aplazar: ${_delayDays.round()} ${_delayDays.round() == 1 ? 'día' : 'días'}'
                : 'Put off by: ${_delayDays.round()} day${_delayDays.round() == 1 ? '' : 's'}',
            style: _secondaryText(context),
          ),
          Slider(
            value: _delayDays,
            min: 1,
            max: 14,
            divisions: 13,
            label: Localizations.localeOf(context).languageCode == 'es'
                ? '${_delayDays.round()} días'
                : '${_delayDays.round()} days',
            onChanged: (double value) {
              if (value == _delayDays) return;
              widget.onDraftChanged();
              setState(() {
                _delayDays = value;
                _draftChanged = true;
              });
            },
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _subjectId == null
                  ? null
                  : () {
                      setState(() => _draftChanged = false);
                      widget.onComposed(
                        TrajectoryCustomScenarioDraft(
                          subjectId: _subjectId!,
                          adjustment: _adjustment,
                          delayDays: _delayDays.round(),
                        ),
                      );
                    },
              icon: const Icon(Icons.alt_route_rounded),
              label: Text(
                journeyText(
                  context,
                  'Compare over ${widget.horizonDays} days',
                  'Comparar en ${widget.horizonDays} días',
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
            TextButton(
              onPressed: widget.onClear,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
              child: Text(
                journeyText(
                  context,
                  'Clear my scenario',
                  'Borrar mi escenario',
                ),
              ),
            ),
          ],
        ),
        if (!_draftChanged && widget.feedback != null) ...[
          const SizedBox(height: 10),
          widget.feedback!,
        ],
      ],
    );
  }
}

enum _CustomComparisonState { pending, ready, unavailable }

class _CustomComparisonRequest {
  const _CustomComparisonRequest({
    required this.draft,
    required this.scenarioId,
    required this.previous,
    required this.context,
  });
  final TrajectoryCustomScenarioDraft draft;
  final String scenarioId;
  final TrajectoryComparison? previous;
  final (String?, int, int) context;
}

class _CustomComparisonFeedback extends StatelessWidget {
  const _CustomComparisonFeedback({
    super.key,
    required this.state,
    this.onView,
  });
  final _CustomComparisonState state;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (state) {
          _CustomComparisonState.pending => journeyText(
            context,
            'Updating your comparison…',
            'Actualizando tu comparación…',
          ),
          _CustomComparisonState.ready => journeyText(
            context,
            'Your comparison is ready. Preview only; no changes saved.',
            'Tu comparación está lista. Solo es una vista previa; no se guardaron cambios.',
          ),
          _CustomComparisonState.unavailable => journeyText(
            context,
            'This change could not be compared with the current information. Try another task or change.',
            'No se pudo comparar este cambio con la información actual. Prueba otra tarea u otro cambio.',
          ),
        }),
        if (state == _CustomComparisonState.ready && onView != null)
          TextButton.icon(
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined),
            label: Text(
              journeyText(context, 'View comparison', 'Ver comparación'),
            ),
          ),
      ],
    ),
  );
}
