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

part 'trajectory_engine_screen.overview.dart';
part 'trajectory_engine_screen.widgets.dart';

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
