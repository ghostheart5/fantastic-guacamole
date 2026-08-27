import 'dart:async';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/decision_intelligence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrajectoryEngineScreen extends ConsumerStatefulWidget {
  const TrajectoryEngineScreen({super.key});

  @override
  ConsumerState<TrajectoryEngineScreen> createState() =>
      _TrajectoryEngineScreenState();
}

class _TrajectoryEngineScreenState
    extends ConsumerState<TrajectoryEngineScreen> {
  String? _selectedScenarioId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(adaptiveGuidanceProvider.notifier)
            .record(GuidanceMilestone.firstTrajectoryReview),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final TrajectoryEngineModel model = ref.watch(
      trajectoryEngineModelProvider,
    );
    final int horizonDays = ref.watch(trajectoryHorizonDaysProvider);
    final AsyncValue<TrajectoryCalibrationSummary> calibration = ref.watch(
      trajectoryCalibrationSummaryProvider,
    );
    final TrajectoryComparison? comparison = model.comparison;
    final TrajectoryScenarioOutcome? selected = _selected(
      comparison,
      _selectedScenarioId,
    );
    final bool blocksContent =
        comparison == null &&
        (model.status == TrajectoryEngineStatus.loading ||
            model.status == TrajectoryEngineStatus.error ||
            model.status == TrajectoryEngineStatus.empty);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgTrajectory,
      overlayOpacity: .58,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back to Nexus',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => goToAppView(context, ref, AppView.nexus),
          ),
          title: const Text('Trajectory Engine'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recalculate trajectory',
              onPressed: () => _refresh(comparison),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: <Widget>[
            _TrajectoryStateNotice(
              status: model.status,
              detail: model.statusDetail,
              onRetry: () =>
                  ref.read(trajectoryEngineActionsProvider).refresh(),
              onCreate: () => goToAppView(context, ref, AppView.creator),
            ),
            if (blocksContent) const SizedBox(height: 8),
            if (blocksContent && model.status == TrajectoryEngineStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!blocksContent) ...<Widget>[
              if (comparison case final TrajectoryComparison value) ...<Widget>[
                const SizedBox(height: 8),
                _TrajectoryOverviewCard(
                  baseline: value.baseline,
                  horizonDays: horizonDays,
                ),
                const SizedBox(height: 8),
                _HorizonSelector(
                  selectedDays: horizonDays,
                  onSelected: (int days) {
                    setState(() => _selectedScenarioId = null);
                    ref
                        .read(trajectoryHorizonDaysProvider.notifier)
                        .select(days);
                  },
                ),
                if (selected
                    case final TrajectoryScenarioOutcome outcome) ...<Widget>[
                  const SizedBox(height: 8),
                  _ScenarioComparisonCard(
                    baseline: value.baseline,
                    outcome: outcome,
                    isRecommended: outcome.id == value.recommendedScenarioId,
                    onOpen: () =>
                        _openScenarioDestination(outcome.intervention),
                    onTrack: () => _trackScenario(value.baseline, outcome),
                  ),
                ],
                const SizedBox(height: 8),
                _DisclosurePanel(
                  title: 'Try a custom what-if',
                  subtitle: 'Optional simulation tools',
                  child: _CustomScenarioComposer(
                    baseline: value.baseline,
                    horizonDays: horizonDays,
                    onComposed: (TrajectoryCustomScenarioDraft draft) {
                      ref
                          .read(trajectoryCustomScenarioProvider.notifier)
                          .compose(draft);
                      setState(
                        () => _selectedScenarioId = trajectoryCustomScenarioId(
                          draft,
                          horizonDays: horizonDays,
                        ),
                      );
                    },
                    onClear: () {
                      ref
                          .read(trajectoryCustomScenarioProvider.notifier)
                          .clear();
                      setState(() => _selectedScenarioId = null);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _DisclosurePanel(
                  title: 'Evidence and model details',
                  subtitle: 'Baseline, calibration, and forecast sources',
                  child: Column(
                    children: <Widget>[
                      if (model.decisionIntelligence
                          case final DecisionIntelligence
                              intelligence) ...<Widget>[
                        DecisionIntelligenceCard(
                          intelligence: intelligence,
                          title: 'Decision context',
                          compact: true,
                          onAction: () => _openDecisionAction(
                            intelligence.decision.actionIntent,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _BaselineCard(baseline: value.baseline),
                      const SizedBox(height: 8),
                      _CalibrationCard(summary: calibration),
                      const SizedBox(height: 8),
                      _TaskPredictionCard(model: model),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _openDecisionAction(OperatingActionIntent intent) {
    switch (NexusActionResolver.resolve(intent)) {
      case NexusActionDestination.creator:
        goToAppView(context, ref, AppView.creator);
      case NexusActionDestination.timeline:
        goToAppView(context, ref, AppView.timeline);
      case NexusActionDestination.smartPlanner:
        goToAppView(context, ref, AppView.smartPlanner);
      case NexusActionDestination.siConsole:
        goToAppView(context, ref, AppView.console);
      case NexusActionDestination.trajectoryEngine:
        goToAppView(context, ref, AppView.trajectoryEngine);
      case NexusActionDestination.progression:
        goToAppView(context, ref, AppView.progression);
      case NexusActionDestination.acknowledge:
      case NexusActionDestination.none:
        break;
      case NexusActionDestination.unsupported:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This action is not available.')),
        );
    }
  }

  Future<void> _refresh(TrajectoryComparison? comparison) async {
    int reconciled = 0;
    if (comparison != null) {
      reconciled = await ref
          .read(trajectoryForecastLedgerActionsProvider)
          .reconcile(comparison.baseline);
    }
    ref.read(trajectoryEngineActionsProvider).refresh();
    if (mounted && reconciled > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$reconciled due forecast${reconciled == 1 ? '' : 's'} reconciled with current evidence.',
          ),
        ),
      );
    }
  }

  Future<void> _trackScenario(
    TrajectoryBaseline baseline,
    TrajectoryScenarioOutcome outcome,
  ) async {
    final bool stored = await ref
        .read(trajectoryForecastLedgerActionsProvider)
        .track(baseline: baseline, outcome: outcome);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stored
              ? 'Path tracked. Its forecast will be compared with future observed evidence.'
              : 'Sign in to keep an account-scoped forecast receipt.',
        ),
      ),
    );
  }

  void _openScenarioDestination(TrajectoryIntervention intervention) {
    switch (intervention.type) {
      case TrajectoryInterventionType.applySmartPlanner:
      case TrajectoryInterventionType.maintainCourse:
        goToAppView(context, ref, AppView.smartPlanner);
      case TrajectoryInterventionType.completeTask:
      case TrajectoryInterventionType.delayTask:
      case TrajectoryInterventionType.reduceScope:
      case TrajectoryInterventionType.recoverCommitment:
        goToAppView(context, ref, AppView.timeline);
    }
  }
}

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
    return _Panel(
      title: 'Current direction',
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
                  borderRadius: BorderRadius.circular(13),
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
                  label: 'PRESSURE',
                  value: '${baseline.pressure}%',
                  accent: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  label: 'MOMENTUM',
                  value: '${baseline.momentum}%',
                  accent: const Color(0xFF6EE7F9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  label: 'ENERGY',
                  value: '${baseline.energy}%',
                  accent: const Color(0xFFA78BFA),
                ),
              ),
            ],
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF93A4C9),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
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
    return Material(
      color: const Color(0xE611192A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF24345B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        iconColor: const Color(0xFF6EE7F9),
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
              ),
              TextButton(
                onPressed: widget.onClear,
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
        : value.state.name;
    final String detail = value == null
        ? 'Calibration evidence is not currently available.'
        : value.resolvedForecasts == 0
        ? 'No tracked path has reached its horizon yet. Forecasts remain provisional.'
        : '${value.resolvedForecasts} resolved • momentum error ${value.momentumMeanAbsoluteError.toStringAsFixed(1)} points • pressure error ${value.pressureMeanAbsoluteError.toStringAsFixed(1)} points • interval coverage ${(value.intervalCoverage * 100).round()}%.';
    return _Panel(
      title: 'Forecast calibration',
      child: Semantics(
        container: true,
        label: 'Forecast calibration $state. $detail',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              state.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
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
      TrajectoryEngineStatus.partial ||
      TrajectoryEngineStatus.empty => const Color(0xFFFFC857),
      _ => const Color(0xFF6EE7F9),
    };
    final String label = switch (status) {
      TrajectoryEngineStatus.loading => 'BUILDING BASELINE',
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: .35)),
        ),
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
                      letterSpacing: 1.2,
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
              _ValuePill(label: 'Momentum', value: '${baseline.momentum}%'),
              _ValuePill(label: 'Pressure', value: '${baseline.pressure}%'),
              _ValuePill(label: 'Energy', value: '${baseline.energy}%'),
              _ValuePill(
                label: 'Observed outcomes',
                value: '${baseline.observationCount}',
              ),
              _ValuePill(
                label: 'Capacity gap',
                value: '${baseline.unscheduledMinutes}m',
              ),
              _ValuePill(
                label: 'Progression',
                value:
                    'L${baseline.progression.level} • ${baseline.progression.streak}d',
              ),
            ],
          ),
          const SizedBox(height: 10),
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
    return _Panel(
      title: 'Look ahead',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final int days in const <int>[7, 30, 90])
            ChoiceChip(
              label: Text('$days DAYS'),
              selected: selectedDays == days,
              onSelected: (_) => onSelected(days),
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
  });

  final TrajectoryBaseline baseline;
  final TrajectoryScenarioOutcome outcome;
  final bool isRecommended;
  final VoidCallback onOpen;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: isRecommended ? 'Recommended adjustment' : 'Custom forecast',
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
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
    return _Panel(
      title: 'Full impact report',
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
                uncertainty: 0,
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
                letterSpacing: 1.2,
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
              letterSpacing: 1.2,
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
                letterSpacing: .6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onOpen,
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
            icon: const Icon(Icons.query_stats_rounded),
            label: const Text('Track this path for calibration'),
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
        borderRadius: BorderRadius.circular(10),
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
              letterSpacing: 1,
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

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10182A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF24345B)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFFD8E2FF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
              letterSpacing: 1.2,
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
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D1322),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF24345B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0D1322), Color(0xFF15233F)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6EE7F9),
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
