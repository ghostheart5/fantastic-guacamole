import 'dart:async';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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
    final bool canRecommendScenario = model.canRecommendScenario;
    final TrajectoryScenarioOutcome? selected = _selected(
      comparison,
      _selectedScenarioId,
    );
    final bool blocksContent =
        comparison == null &&
        (model.status == TrajectoryEngineStatus.loading ||
            model.status == TrajectoryEngineStatus.learning ||
            model.status == TrajectoryEngineStatus.error ||
            model.status == TrajectoryEngineStatus.empty);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgTrajectory,
      overlayOpacity: .58,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: <Widget>[
              TemporalScreenHeader(
                title: 'TRAJECTORY',
                subtitle: 'See the consequence before you commit.',
                eyebrow: 'Future branches',
                onBack: () => goToAppView(context, ref, AppView.nexus),
                trailing: IconButton(
                  tooltip: 'Recalculate trajectory',
                  constraints: const BoxConstraints.tightFor(
                    width: AppSizes.touchTarget,
                    height: AppSizes.touchTarget,
                  ),
                  onPressed: () => _refresh(comparison),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 20),
              _TrajectoryStateNotice(
                status: model.status,
                detail: model.statusDetail,
                onRetry: () =>
                    ref.read(trajectoryEngineActionsProvider).refresh(),
                onCreate: () => goToAppView(context, ref, AppView.creator),
              ),
              if (blocksContent) const SizedBox(height: 12),
              if (blocksContent &&
                  model.status == TrajectoryEngineStatus.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!blocksContent) ...<Widget>[
                if (comparison
                    case final TrajectoryComparison value) ...<Widget>[
                  const SizedBox(height: 12),
                  _HorizonSelector(
                    selectedDays: horizonDays,
                    onSelected: (int days) {
                      setState(() => _selectedScenarioId = null);
                      ref
                          .read(trajectoryHorizonDaysProvider.notifier)
                          .select(days);
                    },
                  ),
                  const SizedBox(height: 12),
                  _TrajectoryOverviewCard(
                    baseline: value.baseline,
                    horizonDays: horizonDays,
                  ),
                  const SizedBox(height: 12),
                  _FutureBranches(
                    outcomes: value.outcomes,
                    selectedId: selected?.id,
                    recommendedId: value.recommendedScenarioId,
                    canRecommend: canRecommendScenario,
                    onSelected: (String id) =>
                        setState(() => _selectedScenarioId = id),
                  ),
                  if (selected
                      case final TrajectoryScenarioOutcome outcome) ...<Widget>[
                    const SizedBox(height: 12),
                    _ScenarioComparisonCard(
                      baseline: value.baseline,
                      outcome: outcome,
                      isRecommended:
                          canRecommendScenario &&
                          outcome.id == value.recommendedScenarioId,
                      onOpen: () =>
                          _openScenarioDestination(outcome.intervention),
                      onTrack: () => _trackScenario(value.baseline, outcome),
                      onCorrect: () =>
                          _correctAssumptions(value.baseline, outcome),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                          () =>
                              _selectedScenarioId = trajectoryCustomScenarioId(
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
                  const SizedBox(height: 12),
                  _DisclosurePanel(
                    title: 'Evidence and model details',
                    subtitle: 'Baseline, monitoring, and forecast sources',
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
      ),
    );
  }

  void _openDecisionAction(OperatingActionIntent intent) {
    switch (NexusActionResolver.resolve(intent)) {
      case NexusActionDestination.creatorTask:
        ref
            .read(creatorNavigationIntentProvider.notifier)
            .open(CreatorFormKind.task);
        goToAppView(context, ref, AppView.creator);
      case NexusActionDestination.creatorNote:
        ref
            .read(creatorNavigationIntentProvider.notifier)
            .open(CreatorFormKind.note);
        goToAppView(context, ref, AppView.creator);
      case NexusActionDestination.goals:
        goToAppView(context, ref, AppView.goals);
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
              ? 'Path tracked. Its forecast will be monitored against future observed evidence.'
              : 'Sign in to keep an account-scoped forecast receipt.',
        ),
      ),
    );
  }

  Future<void> _correctAssumptions(
    TrajectoryBaseline baseline,
    TrajectoryScenarioOutcome outcome,
  ) async {
    final bool stored = await ref
        .read(trajectoryForecastLedgerRepositoryProvider)
        .recordAssumptionCorrection(
          baseline: baseline,
          outcome: outcome,
          correctedAt: DateTime.now().toUtc(),
        );
    if (stored) ref.invalidate(trajectoryForecastLedgerProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stored
              ? 'Correction saved locally. This result will not count as monitoring evidence.'
              : 'Sign in to save an account-scoped assumption correction.',
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
