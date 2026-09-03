part of 'trajectory_engine_screen.dart';

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
    final bool needsAction =
        status == TrajectoryEngineStatus.error ||
        status == TrajectoryEngineStatus.empty;
    final Color accent = switch (status) {
      TrajectoryEngineStatus.error => const Color(0xFFFF5D73),
      TrajectoryEngineStatus.offline ||
      TrajectoryEngineStatus.learning ||
      TrajectoryEngineStatus.partial ||
      TrajectoryEngineStatus.empty => const Color(0xFFFFC857),
      _ => const Color(0xFF6EE7F9),
    };
    final String label = switch (status) {
      TrajectoryEngineStatus.loading => 'BUILDING BASELINE',
      TrajectoryEngineStatus.learning => 'LEARNING YOUR PATTERN',
      TrajectoryEngineStatus.ready => 'BASELINE READY',
      TrajectoryEngineStatus.empty => 'EVIDENCE NEEDED',
      TrajectoryEngineStatus.partial => 'PARTIAL EVIDENCE',
      TrajectoryEngineStatus.offline => 'LOCAL EVIDENCE',
      TrajectoryEngineStatus.error => 'RECALCULATION NEEDED',
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label. $detail',
      child: TemporalGlassSurface(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        accent: accent,
        opacity: .9,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.route_rounded, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFFD8E2FF),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (needsAction)
              TextButton(
                onPressed: status == TrajectoryEngineStatus.empty
                    ? onCreate
                    : onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    AppSizes.touchTarget,
                    AppSizes.touchTarget,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  status == TrajectoryEngineStatus.empty
                      ? 'Open Creator'
                      : 'Retry',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  const _BaselineCard({required this.baseline});

  final TrajectoryBaseline baseline;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Current trajectory baseline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _BaselineMetric(
                label: 'Momentum',
                value: 'modeled ${baseline.momentum}%',
              ),
              _BaselineMetric(
                label: 'Pressure',
                value: 'modeled ${baseline.pressure}%',
              ),
              _BaselineMetric(
                label: 'Energy',
                value: baseline.hasObservedEnergy
                    ? '${baseline.energy}% observed'
                    : 'not observed',
              ),
              _BaselineMetric(
                label: 'Observed outcomes',
                value: '${baseline.observationCount}',
              ),
              _BaselineMetric(
                label: 'Capacity gap',
                value: baseline.hasObservedAvailability
                    ? '${baseline.unscheduledMinutes}m'
                    : 'not scored',
              ),
              _BaselineMetric(
                label: 'Progression',
                value:
                    'L${baseline.progression.level} • ${baseline.progression.streak}d',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (baseline.personContextWarnings.isNotEmpty) ...<Widget>[
            Text(
              'Governed Person Context: ${baseline.availableMinutes}m available / ${baseline.unscheduledMinutes}m unscheduled. '
              'No-context comparison: ${baseline.noContextAvailableMinutes}m available / ${baseline.noContextUnscheduledMinutes}m unscheduled.',
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            ...baseline.personContextWarnings.map(
              (String warning) => Text(
                '• $warning',
                style: const TextStyle(
                  color: Color(0xFFD8E2FF),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            '${baseline.tasks.length} task(s), ${baseline.goals.length} active goal(s), '
            '${baseline.blocks.length} planned block(s), and ${baseline.timelineSignals.length} linked Timeline signal(s).',
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Revision ${baseline.revision} • ${baseline.confidence.band.name} confidence • ${baseline.evidenceWindow.inDays}-day evidence window',
            style: const TextStyle(
              color: Color(0xFF93A4D6),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskPredictionCard extends StatelessWidget {
  const _TaskPredictionCard({required this.model});

  final TrajectoryEngineModel model;

  @override
  Widget build(BuildContext context) {
    final summary = model.summary;
    if (!summary.hasPrediction) {
      return _Panel(
        title: 'Observed follow-through',
        child: Text(
          summary.statusDetail,
          style: const TextStyle(
            color: Color(0xFFD8E2FF),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      );
    }
    final int probability = ((summary.predictionProbability ?? 0) * 100)
        .round();
    final int lower = ((summary.predictionLowerBound ?? 0) * 100).round();
    final int upper = ((summary.predictionUpperBound ?? 1) * 100).round();
    return _Panel(
      title: 'Observed follow-through',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${summary.predictionTitle}: ${summary.predictionOutcome}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$probability% smoothed completion estimate • $lower–$upper% interval • ${summary.predictionSampleSize} outcomes',
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.predictionExplanation ?? '',
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.predictionEvidenceSufficient ? 'Established history' : 'Limited history'} • ${summary.predictionModelVersion ?? 'method unavailable'}',
            style: const TextStyle(color: Color(0xFF93A4D6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HorizonSelector extends StatelessWidget {
  const _HorizonSelector({
    required this.selectedDays,
    required this.onSelected,
  });

  final int selectedDays;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Forecast horizon. $selectedDays days selected.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final int days in const <int>[7, 30, 90])
            ChoiceChip(
              label: Text('$days DAYS'),
              selected: selectedDays == days,
              showCheckmark: false,
              onSelected: (_) => onSelected(days),
              labelStyle: TextStyle(
                color: selectedDays == days
                    ? AppColors.background
                    : Colors.white70,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              backgroundColor: AppColors.bgSecondary.withValues(alpha: .82),
              selectedColor: AppColors.neonCyan,
              side: BorderSide(
                color: AppColors.neonCyan.withValues(alpha: .42),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ],
      ),
    );
  }
}

String _conciseOutcomeSummary({
  required TrajectoryBaseline baseline,
  required TrajectoryScenarioOutcome outcome,
}) {
  final int momentumDelta = outcome.projectedMomentum - baseline.momentum;
  final int pressureDelta = outcome.projectedPressure - baseline.pressure;
  final String momentumChange = momentumDelta == 0
      ? 'momentum holding steady'
      : 'momentum ${momentumDelta > 0 ? 'rising' : 'falling'} by ${momentumDelta.abs()} points';
  final String pressureChange = pressureDelta == 0
      ? 'pressure holding steady'
      : 'pressure ${pressureDelta > 0 ? 'rising' : 'falling'} by ${pressureDelta.abs()} points';

  return 'Over ${outcome.intervention.horizon.inDays} days, this path projects '
      '$momentumChange and $pressureChange. Open the full report for uncertainty '
      'and supporting evidence.';
}

class _ScenarioComparisonCard extends StatelessWidget {
  const _ScenarioComparisonCard({
    required this.baseline,
    required this.outcome,
    required this.isRecommended,
    required this.onOpen,
    required this.onTrack,
    required this.onCorrect,
  });

  final TrajectoryBaseline baseline;
  final TrajectoryScenarioOutcome outcome;
  final bool isRecommended;
  final VoidCallback onOpen;
  final VoidCallback onTrack;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: isRecommended ? 'Recommended adjustment' : 'Custom forecast',
      accent: isRecommended ? AppColors.neonViolet : AppColors.neonCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            outcome.intervention.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            outcome.intervention.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetricDelta(
                label: 'Momentum',
                current: baseline.momentum,
                projected: outcome.projectedMomentum,
                uncertainty: outcome.uncertainty,
              ),
              _MetricDelta(
                label: 'Pressure',
                current: baseline.pressure,
                projected: outcome.projectedPressure,
                uncertainty: outcome.uncertainty,
                lowerIsBetter: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _conciseOutcomeSummary(baseline: baseline, outcome: outcome),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB8C7E8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _ResultAssumptions(assumptions: outcome.assumptions),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                    ? 'Review adjustment'
                    : 'Review on Timeline',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('trajectory-correct-assumptions'),
            onPressed: onCorrect,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Correct assumptions'),
          ),
          const SizedBox(height: 4),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            title: const Text(
              'Full impact and evidence',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${outcome.confidence.band.name} confidence · ±${outcome.uncertainty} points',
              style: const TextStyle(color: Color(0xFF93A4C9), fontSize: 11),
            ),
            children: <Widget>[
              _ScenarioFullDetails(
                baseline: baseline,
                outcome: outcome,
                onOpen: onOpen,
                onTrack: onTrack,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioFullDetails extends StatelessWidget {
  const _ScenarioFullDetails({
    required this.baseline,
    required this.outcome,
    required this.onOpen,
    required this.onTrack,
  });

  final TrajectoryBaseline baseline;
  final TrajectoryScenarioOutcome outcome;
  final VoidCallback onOpen;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'FULL IMPACT REPORT',
            style: TextStyle(
              color: AppColors.neonViolet,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            outcome.intervention.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            outcome.intervention.description,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetricDelta(
                label: 'Momentum',
                current: baseline.momentum,
                projected: outcome.projectedMomentum,
                uncertainty: outcome.uncertainty,
              ),
              _MetricDelta(
                label: 'Pressure',
                current: baseline.pressure,
                projected: outcome.projectedPressure,
                uncertainty: outcome.uncertainty,
                lowerIsBetter: true,
              ),
              _MetricDelta(
                label: 'Accumulated risk',
                current: outcome.risk.currentScore,
                projected: outcome.risk.projectedScore,
                uncertainty: outcome.uncertainty,
                lowerIsBetter: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            label: 'WHY THIS CHANGES THE FUTURE',
            value: outcome.explanation,
          ),
          _Section(label: 'TIMELINE IMPACT', value: outcome.timeline.summary),
          _Section(
            label: 'PROGRESSION IMPACT',
            value: outcome.progression.summary,
          ),
          if (outcome.goals.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            const Text(
              'GOAL DELAY PROJECTIONS',
              style: TextStyle(
                color: Color(0xFF6EE7F9),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            for (final GoalDelayProjection goal in outcome.goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${goal.goalTitle}: ${localizations.formatMediumDate(goal.lowerCompletion.toLocal())}–${localizations.formatMediumDate(goal.upperCompletion.toLocal())}; ${goal.explanation}',
                  style: const TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 4),
          const Text(
            'RISK CONTRIBUTORS',
            style: TextStyle(
              color: Color(0xFF6EE7F9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          for (final TrajectoryRiskContribution risk
              in outcome.risk.contributions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${risk.label}: ${risk.currentScore}% → ${risk.projectedScore}%. ${risk.explanation}',
                style: const TextStyle(
                  color: Color(0xFFB8C7FF),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'Evidence and assumptions',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              '${outcome.confidence.band.name} confidence • ±${outcome.uncertainty} points • ${outcome.modelVersion}',
              style: const TextStyle(color: Color(0xFF93A4D6), fontSize: 11),
            ),
            children: <Widget>[
              _EvidenceList(title: 'Evidence', values: outcome.evidence),
              _EvidenceList(title: 'Assumptions', values: outcome.assumptions),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Generated ${localizations.formatMediumDate(outcome.generatedAt.toLocal())} • baseline ${outcome.baselineRevision}',
                  style: const TextStyle(
                    color: Color(0xFF7F91C8),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label:
                'Simulation only. Opening a feature does not apply or award the projected outcome.',
            child: const Text(
              'SIMULATION ONLY — no task, Timeline block, goal, or Progression reward is changed here.',
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
                  ? 'Review in Smart Planner'
                  : 'Review affected work on Timeline',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onTrack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.query_stats_rounded),
            label: const Text('Track this path for monitoring'),
          ),
        ],
      ),
    );
  }
}

class _MetricDelta extends StatelessWidget {
  const _MetricDelta({
    required this.label,
    required this.current,
    required this.projected,
    required this.uncertainty,
    this.lowerIsBetter = false,
  });

  final String label;
  final int current;
  final int projected;
  final int uncertainty;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final int delta = projected - current;
    final bool favorable = lowerIsBetter ? delta <= 0 : delta >= 0;
    final int low = (projected - uncertainty).clamp(0, 100);
    final int high = (projected + uncertainty).clamp(0, 100);
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF10182A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF24345B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF93A4D6),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            uncertainty == 0
                ? '$current% → $projected%'
                : '$current% → $low–$high%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${delta >= 0 ? '+' : ''}$delta points',
            style: TextStyle(
              color: favorable
                  ? const Color(0xFF6EE7F9)
                  : const Color(0xFFFFC857),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselineMetric extends StatelessWidget {
  const _BaselineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112, minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6EE7F9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD8E2FF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceList extends StatelessWidget {
  const _EvidenceList({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '$title:\n${values.map((String value) => '• $value').join('\n')}',
          style: const TextStyle(
            color: Color(0xFFB8C7FF),
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.accent = AppColors.neonCyan,
  });

  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      accent: accent,
      opacity: .9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 10,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
