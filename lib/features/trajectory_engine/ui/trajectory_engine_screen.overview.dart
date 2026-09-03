part of 'trajectory_engine_screen.dart';

class _TrajectoryOverviewCard extends StatelessWidget {
  const _TrajectoryOverviewCard({
    required this.baseline,
    required this.horizonDays,
  });

  final TrajectoryBaseline baseline;
  final int horizonDays;

  @override
  Widget build(BuildContext context) {
    final String direction = baseline.pressure >= 80
        ? 'High pressure'
        : baseline.pressure >= 50
        ? 'Needs attention'
        : 'Steady direction';
    final Color accent = baseline.pressure >= 80
        ? const Color(0xFFFF6B88)
        : baseline.pressure >= 50
        ? const Color(0xFFFFC857)
        : const Color(0xFF6EE7F9);
    final String momentumBand = baseline.momentum >= 72
        ? 'STRONG'
        : baseline.momentum >= 45
        ? 'STEADY'
        : 'BUILDING';
    return _Panel(
      title: 'Current direction',
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: .35)),
                ),
                child: Icon(Icons.route_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      direction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${baseline.tasks.length} active commitment${baseline.tasks.length == 1 ? '' : 's'} across the next $horizonDays days.',
                      style: const TextStyle(
                        color: Color(0xFFD8E2FF),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _OverviewMetric(
                  label: 'MODELED LOAD',
                  value: baseline.pressure >= 80
                      ? 'HIGH'
                      : baseline.pressure >= 50
                      ? 'WATCH'
                      : 'LOW',
                  accent: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  label: 'MOMENTUM',
                  value: momentumBand,
                  accent: const Color(0xFF6EE7F9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  label: 'ENERGY',
                  value: baseline.hasObservedEnergy
                      ? '${baseline.energy}%'
                      : 'NOT SET',
                  accent: const Color(0xFFA78BFA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _EvidenceOriginBoundary(baseline: baseline),
        ],
      ),
    );
  }
}

class _EvidenceOriginBoundary extends StatelessWidget {
  const _EvidenceOriginBoundary({required this.baseline});

  final TrajectoryBaseline baseline;

  @override
  Widget build(BuildContext context) {
    final String energy = baseline.hasObservedEnergy
        ? 'recorded'
        : '${baseline.energyOrigin.name}; not observed';
    final String availability = baseline.hasObservedAvailability
        ? 'recorded'
        : '${baseline.availabilityOrigin.name}; not observed';
    return Text(
      'Evidence boundary: energy is $energy; availability is $availability. '
      'Task durations remain estimates and deadline effects remain projections.',
      style: const TextStyle(
        color: Color(0xFFB8C7E8),
        fontSize: 11,
        height: 1.35,
      ),
    );
  }
}

class _ResultAssumptions extends StatelessWidget {
  const _ResultAssumptions({required this.assumptions});

  final List<String> assumptions;

  @override
  Widget build(BuildContext context) {
    final List<String> visible = assumptions
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: .24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ASSUMPTIONS FOR THIS RESULT',
            style: TextStyle(
              color: Color(0xFFFFC857),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          if (visible.isEmpty)
            const Text(
              'No additional scenario assumptions were listed. Task durations and future availability remain modeled.',
              style: TextStyle(
                color: Color(0xFFD8E2FF),
                fontSize: 10,
                height: 1.3,
              ),
            )
          else
            for (final String assumption in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $assumption',
                  style: const TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FutureBranches extends StatelessWidget {
  const _FutureBranches({
    required this.outcomes,
    required this.selectedId,
    required this.recommendedId,
    required this.canRecommend,
    required this.onSelected,
  });

  final List<TrajectoryScenarioOutcome> outcomes;
  final String? selectedId;
  final String recommendedId;
  final bool canRecommend;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<TrajectoryScenarioOutcome> visible = outcomes.take(3).toList();
    TrajectoryScenarioOutcome? selected;
    for (final TrajectoryScenarioOutcome item in outcomes) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }
    if (selected case final TrajectoryScenarioOutcome selectedOutcome) {
      if (!visible.any(
        (TrajectoryScenarioOutcome item) => item.id == selectedOutcome.id,
      )) {
        visible.add(selectedOutcome);
      }
    }

    return TemporalGlassSurface(
      accent: AppColors.neonViolet,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'FUTURE BRANCHES',
            style: TextStyle(
              color: AppColors.neonViolet,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a path to preview its projected consequences.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          for (int index = 0; index < visible.length; index++) ...<Widget>[
            _BranchRow(
              outcome: visible[index],
              label: canRecommend && visible[index].id == recommendedId
                  ? 'BEST-FIT'
                  : 'MODELED PATH ${index + 1}',
              accent: switch (index % 3) {
                0 => AppColors.neonCyan,
                1 => AppColors.neonViolet,
                _ => AppColors.memoryAmber,
              },
              selected: visible[index].id == selectedId,
              onTap: () => onSelected(visible[index].id),
            ),
            if (index != visible.length - 1)
              Divider(color: Colors.white.withValues(alpha: .09), height: 1),
          ],
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.outcome,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final TrajectoryScenarioOutcome outcome;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int momentumLow = (outcome.projectedMomentum - outcome.uncertainty)
        .clamp(0, 100);
    final int momentumHigh = (outcome.projectedMomentum + outcome.uncertainty)
        .clamp(0, 100);
    final int pressureLow = (outcome.projectedPressure - outcome.uncertainty)
        .clamp(0, 100);
    final int pressureHigh = (outcome.projectedPressure + outcome.uncertainty)
        .clamp(0, 100);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. ${outcome.intervention.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(color: Colors.white70),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: selected ? .72 : .32),
                          blurRadius: selected ? 12 : 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          outcome.intervention.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Momentum $momentumLow–$momentumHigh%  ·  Pressure $pressureLow–$pressureHigh%  ·  ${outcome.confidence.band.name} evidence',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            height: 1.3,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ResultAssumptions(assumptions: outcome.assumptions),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: accent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF93A4C9),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclosurePanel extends StatelessWidget {
  const _DisclosurePanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: .2),
          ),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        iconColor: AppColors.neonCyan,
        collapsedIconColor: const Color(0xFF93A4C9),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF93A4C9), fontSize: 11),
        ),
        children: <Widget>[child],
      ),
    );
  }
}

class _CustomScenarioComposer extends StatefulWidget {
  const _CustomScenarioComposer({
    required this.baseline,
    required this.horizonDays,
    required this.onComposed,
    required this.onClear,
  });

  final TrajectoryBaseline baseline;
  final int horizonDays;
  final ValueChanged<TrajectoryCustomScenarioDraft> onComposed;
  final VoidCallback onClear;

  @override
  State<_CustomScenarioComposer> createState() =>
      _CustomScenarioComposerState();
}

class _CustomScenarioComposerState extends State<_CustomScenarioComposer> {
  String? _subjectId;
  TrajectoryCustomAdjustment _adjustment = TrajectoryCustomAdjustment.complete;
  double _delayDays = 1;

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
      _subjectId = widget.baseline.tasks.firstOrNull?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.baseline.tasks.isEmpty) return const SizedBox.shrink();
    final bool showsDelay = _adjustment == TrajectoryCustomAdjustment.delay;
    return _Panel(
      title: 'Compose a what-if path',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Choose one explicit change. ChronoSpark will compare its capacity, risk, goal-timing, Timeline, and Progression consequences without changing your real plan.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            decoration: const InputDecoration(
              labelText: 'Commitment to change',
            ),
            items: widget.baseline.tasks
                .map(
                  (TrajectoryTaskNode task) => DropdownMenuItem<String>(
                    value: task.id,
                    child: Text(task.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) => setState(() => _subjectId = value),
          ),
          const SizedBox(height: 10),
          SegmentedButton<TrajectoryCustomAdjustment>(
            segments: const <ButtonSegment<TrajectoryCustomAdjustment>>[
              ButtonSegment<TrajectoryCustomAdjustment>(
                value: TrajectoryCustomAdjustment.complete,
                label: Text('Complete'),
                icon: Icon(Icons.check_rounded),
              ),
              ButtonSegment<TrajectoryCustomAdjustment>(
                value: TrajectoryCustomAdjustment.delay,
                label: Text('Delay'),
                icon: Icon(Icons.schedule_rounded),
              ),
              ButtonSegment<TrajectoryCustomAdjustment>(
                value: TrajectoryCustomAdjustment.reduceScope,
                label: Text('Remove'),
                icon: Icon(Icons.remove_circle_outline_rounded),
              ),
            ],
            selected: <TrajectoryCustomAdjustment>{_adjustment},
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll<Size>(
                Size(0, AppSizes.touchTarget),
              ),
              shape: WidgetStatePropertyAll<OutlinedBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              textStyle: const WidgetStatePropertyAll<TextStyle>(
                TextStyle(letterSpacing: 0),
              ),
            ),
            onSelectionChanged: (Set<TrajectoryCustomAdjustment> selected) {
              setState(() => _adjustment = selected.first);
            },
          ),
          if (showsDelay) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Declared delay: ${_delayDays.round()} day${_delayDays.round() == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Slider(
              value: _delayDays,
              min: 1,
              max: 14,
              divisions: 13,
              label: '${_delayDays.round()} days',
              onChanged: (double value) => setState(() => _delayDays = value),
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
                    : () => widget.onComposed(
                        TrajectoryCustomScenarioDraft(
                          subjectId: _subjectId!,
                          adjustment: _adjustment,
                          delayDays: _delayDays.round(),
                        ),
                      ),
                icon: const Icon(Icons.alt_route_rounded),
                label: Text('Compare ${widget.horizonDays}-day path'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear my scenario'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.summary});

  final AsyncValue<TrajectoryCalibrationSummary> summary;

  @override
  Widget build(BuildContext context) {
    final TrajectoryCalibrationSummary? value = summary.asData?.value;
    final String state = value == null
        ? (summary.isLoading ? 'loading' : 'unavailable')
        : value.resolvedForecasts == 0
        ? 'provisional'
        : 'monitored';
    final String detail = value == null
        ? 'Monitoring evidence is not currently available.'
        : value.resolvedForecasts == 0
        ? 'No tracked path has reached its horizon yet. Forecasts remain provisional.'
        : '${value.resolvedForecasts} resolved and monitored • momentum error ${value.momentumMeanAbsoluteError.toStringAsFixed(1)} points • pressure error ${value.pressureMeanAbsoluteError.toStringAsFixed(1)} points • interval coverage ${(value.intervalCoverage * 100).round()}%. Coefficients and uncertainty are unchanged.';
    return _Panel(
      title: 'Forecast monitoring',
      child: Semantics(
        container: true,
        label: 'Forecast monitoring $state. $detail',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              state.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 11,
                fontWeight: FontWeight.w900,
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
    );
  }
}

TrajectoryScenarioOutcome? _selected(
  TrajectoryComparison? comparison,
  String? selectedId,
) {
  if (comparison == null || comparison.outcomes.isEmpty) return null;
  if (selectedId != null) {
    for (final TrajectoryScenarioOutcome outcome in comparison.outcomes) {
      if (outcome.id == selectedId) return outcome;
    }
  }
  return comparison.recommended ?? comparison.outcomes.first;
}
