import 'package:fantastic_guacamole/ui/widgets/dropdown_route_keyboard_guard.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';

import 'dart:async';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
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
  TrajectoryEngineModel? _lastDisplayModel;
  AsyncValue<TrajectoryCalibrationSummary>? _lastCalibration;
  bool _isRefreshing = false;
  (String?, int, int)? _comparisonContext;

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
    // Removing the forecast body during loading clamps the list to the top
    // and disposes expanded panels and unsaved what-if controls. Retain its
    // presentation only during a refresh in the same account and horizon.
    final scope = ref.watch(accountStorageScopeProvider);
    final boundary = ref.watch(authSessionBoundaryProvider);
    final comparisonContext = (
      scope.v2Namespace,
      boundary.generation,
      horizonDays,
    );
    if (_comparisonContext != comparisonContext) {
      _lastDisplayModel = null;
      _lastCalibration = null;
      if (_comparisonContext != null) _selectedScenarioId = null;
      _comparisonContext = comparisonContext;
    }
    final bool refreshing =
        model.status == TrajectoryEngineStatus.loading &&
        model.comparison == null &&
        _lastDisplayModel != null;
    if (model.hasComparison &&
        const <TrajectoryEngineStatus>{
          TrajectoryEngineStatus.ready,
          TrajectoryEngineStatus.partial,
          TrajectoryEngineStatus.offline,
        }.contains(model.status) &&
        scope.v2Namespace != null &&
        model.comparison!.baseline.accountScope == scope.v2Namespace) {
      _lastDisplayModel = model;
      _lastCalibration = calibration;
    } else if (model.status != TrajectoryEngineStatus.loading) {
      _lastDisplayModel = null;
      _lastCalibration = null;
    }
    _isRefreshing = refreshing;
    final TrajectoryEngineModel displayModel = refreshing
        ? _lastDisplayModel!
        : model;
    final displayCalibration = refreshing ? _lastCalibration! : calibration;
    final TrajectoryComparison? comparison = displayModel.comparison;
    final bool canRecommendScenario = !refreshing && model.canRecommendScenario;
    final TrajectoryScenarioOutcome? selected = _selected(
      comparison,
      _selectedScenarioId,
    );
    final bool blocksContent =
        model.status == TrajectoryEngineStatus.empty ||
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
          child: Stack(
            children: <Widget>[
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: <Widget>[
                  TemporalScreenHeader(
                    title: journeyText(
                      context,
                      'Patterns & future outcomes',
                      'Patrones y resultados futuros',
                    ),
                    subtitle: journeyText(
                      context,
                      'See where your current plan could lead. Choose an option to explore a different outcome.',
                      'Ve adónde podría llevarte tu plan. Elige una opción para explorar otro resultado.',
                    ),
                    eyebrow: journeyText(
                      context,
                      'Predictions are possibilities, not promises',
                      'Las predicciones son posibilidades, no promesas',
                    ),
                    onBack: () => goToAppView(context, ref, AppView.nexus),
                    trailing: IconButton(
                      tooltip: journeyText(
                        context,
                        'Update estimate',
                        'Actualizar estimación',
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: AppSizes.touchTarget,
                        height: AppSizes.touchTarget,
                      ),
                      onPressed: refreshing ? null : () => _refresh(comparison),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('insights-patterns'),
                    onPressed: () =>
                        goToAppView(context, ref, AppView.progression),
                    icon: const Icon(Icons.insights_outlined),
                    label: Text(
                      journeyText(
                        context,
                        'My patterns & progress',
                        'Mis patrones y progreso',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TrajectoryStateNotice(
                    status: model.status,
                    detail: model.statusDetail,
                    onRetry: () =>
                        ref.read(trajectoryEngineActionsProvider).refresh(),
                    onCreate: () => goToAppView(context, ref, AppView.creator),
                  ),
                  if (blocksContent) const SizedBox(height: 12),
                  if (model.status == TrajectoryEngineStatus.empty &&
                      comparison?.baseline.hasObservedEnergy == true)
                    _Panel(
                      title: journeyText(
                        context,
                        'Recorded check-in',
                        'Registro actual',
                      ),
                      child: _OverviewMetric(
                        label: journeyText(context, 'ENERGY', 'ENERGÍA'),
                        value: '${comparison!.baseline.energy}%',
                        accent: const Color(0xFFA78BFA),
                      ),
                    ),
                  if (blocksContent &&
                      model.status == TrajectoryEngineStatus.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  AbsorbPointer(
                    absorbing: refreshing,
                    child: ExcludeFocus(
                      excluding: refreshing,
                      child: Column(
                        children: <Widget>[
                          if (!blocksContent) ...<Widget>[
                            if (comparison
                                case final TrajectoryComparison
                                    value) ...<Widget>[
                              const SizedBox(height: 12),
                              _HorizonSelector(
                                selectedDays: horizonDays,
                                onSelected: (int days) {
                                  if (_isRefreshing) return;
                                  setState(() => _selectedScenarioId = null);
                                  ref
                                      .read(
                                        trajectoryHorizonDaysProvider.notifier,
                                      )
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
                                onSelected: (String id) {
                                  if (_isRefreshing) return;
                                  setState(() => _selectedScenarioId = id);
                                },
                              ),
                              if (selected
                                  case final TrajectoryScenarioOutcome
                                      outcome) ...<Widget>[
                                const SizedBox(height: 12),
                                _ScenarioComparisonCard(
                                  baseline: value.baseline,
                                  outcome: outcome,
                                  isRecommended:
                                      canRecommendScenario &&
                                      outcome.id == value.recommendedScenarioId,
                                  onOpen: () => _openScenarioDestination(
                                    outcome.intervention,
                                  ),
                                  onTrack: () =>
                                      _trackScenario(value.baseline, outcome),
                                  onCorrect: () => _correctAssumptions(
                                    value.baseline,
                                    outcome,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _DisclosurePanel(
                                title: journeyText(
                                  context,
                                  'Task predictions',
                                  'Predicciones de tareas',
                                ),
                                subtitle: journeyText(
                                  context,
                                  'Explore timing and completion estimates',
                                  'Explora estimaciones de tiempo y finalización',
                                ),
                                child: _TaskPredictionCard(model: displayModel),
                              ),
                              const SizedBox(height: 12),
                              _DisclosurePanel(
                                title: journeyText(
                                  context,
                                  'Try a custom what-if',
                                  'Probar un escenario hipotético',
                                ),
                                subtitle: journeyText(
                                  context,
                                  'Optional simulation tools',
                                  'Herramientas opcionales de simulación',
                                ),
                                child: _CustomScenarioComposer(
                                  baseline: value.baseline,
                                  horizonDays: horizonDays,
                                  onComposed:
                                      (TrajectoryCustomScenarioDraft draft) {
                                        if (_isRefreshing) return;
                                        ref
                                            .read(
                                              trajectoryCustomScenarioProvider
                                                  .notifier,
                                            )
                                            .compose(draft);
                                        setState(
                                          () => _selectedScenarioId =
                                              trajectoryCustomScenarioId(
                                                draft,
                                                horizonDays: horizonDays,
                                              ),
                                        );
                                      },
                                  onClear: () {
                                    if (_isRefreshing) return;
                                    ref
                                        .read(
                                          trajectoryCustomScenarioProvider
                                              .notifier,
                                        )
                                        .clear();
                                    setState(() => _selectedScenarioId = null);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _DisclosurePanel(
                                title: journeyText(
                                  context,
                                  'Evidence and model details',
                                  'Datos y detalles del modelo',
                                ),
                                subtitle: journeyText(
                                  context,
                                  'Baseline, monitoring, and forecast sources',
                                  'Línea base, seguimiento y fuentes de previsión',
                                ),
                                child: Column(
                                  children: <Widget>[
                                    if (displayModel.decisionIntelligence
                                        case final DecisionIntelligence
                                            intelligence) ...<Widget>[
                                      DecisionIntelligenceCard(
                                        intelligence: intelligence,
                                        title: journeyText(
                                          context,
                                          'Decision context',
                                          'Contexto de la decisión',
                                        ),
                                        compact: true,
                                        onAction: () => _openDecisionAction(
                                          intelligence.decision.actionIntent,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    _BaselineCard(baseline: value.baseline),
                                    const SizedBox(height: 8),
                                    _CalibrationCard(
                                      summary: displayCalibration,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (refreshing)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: const Color(0xFF19263A),
                    child: Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          journeyText(
                            context,
                            'Updating estimate. The previous result is shown; forecast controls will return when it is ready.',
                            'Actualizando la estimación. Se muestra el resultado anterior; los controles volverán cuando esté lista.',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDecisionAction(OperatingActionIntent intent) {
    if (_isRefreshing) return;
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
          SnackBar(
            content: Text(
              journeyText(
                context,
                'This action is not available.',
                'Esta acción no está disponible.',
              ),
            ),
          ),
        );
    }
  }

  Future<void> _refresh(TrajectoryComparison? comparison) async {
    if (_isRefreshing) return;
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
            Localizations.localeOf(context).languageCode == 'es'
                ? '$reconciled ${reconciled == 1 ? 'previsión pendiente conciliada' : 'previsiones pendientes conciliadas'} con los datos actuales.'
                : '$reconciled due forecast${reconciled == 1 ? '' : 's'} reconciled with current evidence.',
          ),
        ),
      );
    }
  }

  Future<void> _trackScenario(
    TrajectoryBaseline baseline,
    TrajectoryScenarioOutcome outcome,
  ) async {
    if (_isRefreshing) return;
    final bool stored = await ref
        .read(trajectoryForecastLedgerActionsProvider)
        .track(baseline: baseline, outcome: outcome);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stored
              ? journeyText(
                  context,
                  'Path tracked. Its forecast will be monitored against future observed evidence.',
                  'Camino supervisado. Su previsión se comparará con datos futuros observados.',
                )
              : journeyText(
                  context,
                  'Sign in to keep an account-scoped forecast receipt.',
                  'Inicia sesión para guardar un recibo de previsión asociado a tu cuenta.',
                ),
        ),
      ),
    );
  }

  Future<void> _correctAssumptions(
    TrajectoryBaseline baseline,
    TrajectoryScenarioOutcome outcome,
  ) async {
    if (_isRefreshing) return;
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
              ? journeyText(
                  context,
                  'Forecast excluded locally. Its assumptions and projection remain visible, but it will not count as monitoring evidence.',
                  'Previsión excluida localmente. Sus supuestos y proyección siguen visibles, pero no contará como evidencia de seguimiento.',
                )
              : journeyText(
                  context,
                  'Sign in to exclude this account-scoped forecast.',
                  'Inicia sesión para excluir esta previsión de la cuenta.',
                ),
        ),
      ),
    );
  }

  void _openScenarioDestination(TrajectoryIntervention intervention) {
    if (_isRefreshing) return;
    switch (intervention.type) {
      case TrajectoryInterventionType.applySmartPlanner:
        goToAppView(context, ref, AppView.smartPlanner);
      case TrajectoryInterventionType.maintainCourse:
      case TrajectoryInterventionType.completeTask:
      case TrajectoryInterventionType.delayTask:
      case TrajectoryInterventionType.reduceScope:
      case TrajectoryInterventionType.recoverCommitment:
        goToAppView(context, ref, AppView.timeline);
    }
  }
}
