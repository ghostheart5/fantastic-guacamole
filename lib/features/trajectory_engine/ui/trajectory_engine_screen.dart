import 'package:fantastic_guacamole/ui/widgets/dropdown_route_keyboard_guard.dart';
import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';

import 'dart:async';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/navigation/open_schedule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/tasks/widgets/task_edit_dialog.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'trajectory_engine_screen.copy.dart';
part 'trajectory_engine_screen.overview.dart';
part 'trajectory_engine_screen.widgets.dart';

/// Future outcomes: estimates of what could happen next, built on the plain
/// kit. Every figure is for the selected time range.
class TrajectoryEngineScreen extends ConsumerStatefulWidget {
  const TrajectoryEngineScreen({super.key});

  @override
  ConsumerState<TrajectoryEngineScreen> createState() =>
      _TrajectoryEngineScreenState();
}

class _TrajectoryEngineScreenState
    extends ConsumerState<TrajectoryEngineScreen> {
  /// The chosen option, kept by the kind of option (not by outcome id), so it
  /// survives a refresh, a calibration change or a range change.
  _OptionSelection? _selection;
  _CustomComparisonRequest? _customRequest;
  (_CustomComparisonRequest?, _CustomComparisonState?)? _lastCustomFeedback;
  final GlobalKey _comparisonPreviewKey = GlobalKey();
  final GlobalKey _customFeedbackKey = GlobalKey();
  TrajectoryEngineModel? _lastDisplayModel;
  AsyncValue<TrajectoryCalibrationSummary>? _lastCalibration;
  bool _isRefreshing = false;
  (String?, int, int)? _comparisonContext;

  bool _reviewRecorded = false;

  /// The Patterns lesson finishes when the person actually uses this screen
  /// (scrolls, changes the range or picks an option to compare), not when it
  /// first appears and not on a first touch, which would remove its hint
  /// card and move the page under the finger.
  void _recordReview() {
    if (_reviewRecorded) return;
    _reviewRecorded = true;
    ref
        .read(adaptiveGuidanceProvider.notifier)
        .recordIfMissing(GuidanceMilestone.firstTrajectoryReview)
        .ignore();
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
    // Habit lines live beside the forecast: shown only, never fed into the
    // comparison, the selected option, outcome ids or receipts.
    final TrajectoryHabitLines habitLines = ref.watch(
      trajectoryHabitLinesProvider,
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
      _customRequest = null;
      // Another account or sign-in never inherits a choice; a new range keeps
      // the same kind of option when it still exists.
      if (_comparisonContext != null &&
          (_comparisonContext!.$1 != comparisonContext.$1 ||
              _comparisonContext!.$2 != comparisonContext.$2)) {
        _selection = null;
      }
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
    final TrajectoryScenarioOutcome? selected = _selectedOutcome(
      comparison,
      _selection,
    );
    final customFeedback = _customFeedbackState(model);
    final feedbackIdentity = (_customRequest, customFeedback);
    if (_lastCustomFeedback != feedbackIdentity) {
      _lastCustomFeedback = feedbackIdentity;
      final request = _customRequest;
      if (request != null && customFeedback != null) {
        _revealCustomFeedback(request);
      }
    }
    final bool blocksContent =
        model.status == TrajectoryEngineStatus.empty ||
        comparison == null &&
            (model.status == TrajectoryEngineStatus.loading ||
                model.status == TrajectoryEngineStatus.learning ||
                model.status == TrajectoryEngineStatus.error ||
                model.status == TrajectoryEngineStatus.empty);

    final Widget page = PlainScreen(
      children: <Widget>[
        PlainHeader(
          title: InsightsCopy.of(context).tabName,
          actions: <PlainHeaderAction>[
            PlainHeaderAction(
              icon: Icons.refresh_rounded,
              label: journeyText(
                context,
                'Update estimate',
                'Actualizar estimación',
              ),
              onPressed: refreshing ? null : () => _refresh(comparison),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const InsightsDestinationSwitch(current: AppView.trajectoryEngine),
        const SizedBox(height: 16),
        const _EstimatesLine(),
        const SizedBox(height: 12),
        _TrajectoryStateNotice(
          // The updating overlay reports refresh progress. Keep this
          // prior-result notice at its original height too, so a transient
          // loading message cannot shrink the list extent.
          status: displayModel.status,
          detail: displayModel.statusDetail,
          onRetry: () => ref.read(trajectoryEngineActionsProvider).refresh(),
          onCreate: () => goToAppView(context, ref, AppView.creator),
        ),
        if (model.status == TrajectoryEngineStatus.empty &&
            comparison?.baseline.hasObservedEnergy == true)
          PlainCard(
            child: PlainMetricRow(
              label: journeyText(
                context,
                'Energy you recorded',
                'Energía que registraste',
              ),
              value: '${comparison!.baseline.energy}%',
              provenance: ProvenanceKind.recorded,
            ),
          ),
        if (blocksContent && model.status == TrajectoryEngineStatus.loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              // The page palette's accent, like the rest of the kit.
              child: Builder(
                builder: (BuildContext context) => CircularProgressIndicator(
                  color: PlainPalette.of(context).accent,
                ),
              ),
            ),
          ),
        if (blocksContent && customFeedback != null)
          PlainCard(
            child: _CustomComparisonFeedback(
              key: _customFeedbackKey,
              state: customFeedback,
            ),
          ),
        AbsorbPointer(
          absorbing: refreshing,
          child: ExcludeFocus(
            excluding: refreshing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!blocksContent)
                  if (comparison case final TrajectoryComparison value)
                    ..._forecastBody(
                      context,
                      value: value,
                      displayModel: displayModel,
                      model: model,
                      horizonDays: horizonDays,
                      habitLines: habitLines,
                      selected: selected,
                      canRecommendScenario: canRecommendScenario,
                      customFeedback: customFeedback,
                      comparisonContext: comparisonContext,
                      displayCalibration: displayCalibration,
                    ),
              ],
            ),
          ),
        ),
      ],
    );

    return Listener(
      // A mouse wheel or trackpad scroll.
      onPointerSignal: (_) => _recordReview(),
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) {
          _recordReview();
          return false;
        },
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: page),
            if (refreshing)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _RefreshingBar(),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _forecastBody(
    BuildContext context, {
    required TrajectoryComparison value,
    required TrajectoryEngineModel displayModel,
    required TrajectoryEngineModel model,
    required int horizonDays,
    required TrajectoryHabitLines habitLines,
    required TrajectoryScenarioOutcome? selected,
    required bool canRecommendScenario,
    required _CustomComparisonState? customFeedback,
    required (String?, int, int) comparisonContext,
    required AsyncValue<TrajectoryCalibrationSummary> displayCalibration,
  }) {
    const List<int> ranges = <int>[7, 30, 90];
    return <Widget>[
      PlainSection(
        title: journeyText(context, 'Time range', 'Periodo'),
        children: <Widget>[
          RangeChoice(
            key: const Key('future-outcomes-range'),
            labels: <String>[
              for (final int days in ranges)
                journeyText(context, '$days days', '$days días'),
            ],
            selectedIndex: ranges.indexOf(horizonDays).clamp(0, 2),
            onSelected: (int index) {
              if (_isRefreshing) return;
              _recordReview();
              ref
                  .read(trajectoryHorizonDaysProvider.notifier)
                  .select(ranges[index]);
            },
          ),
        ],
      ),
      _KeepGoingSection(
        baseline: value.baseline,
        horizonDays: horizonDays,
        habitLines: habitLines,
      ),
      _OptionsSection(
        comparison: value,
        selected: selected,
        canRecommend: canRecommendScenario,
        onSelected: (TrajectoryScenarioOutcome outcome) {
          if (_isRefreshing) return;
          _recordReview();
          setState(() => _selection = _OptionSelection.of(outcome));
        },
      ),
      if (selected case final TrajectoryScenarioOutcome outcome)
        KeyedSubtree(
          key: _comparisonPreviewKey,
          child: _SelectedOptionSection(
            baseline: value.baseline,
            outcome: outcome,
            keepGoing: _keepGoingOutcome(value),
            pickedByPerson: _pickedByPerson(outcome),
            isRecommended:
                canRecommendScenario &&
                outcome.id == value.recommendedScenarioId,
            onOpen: () => _openScenarioDestination(value.baseline, outcome),
            onTrack: () => _trackScenario(value.baseline, outcome),
            onCorrect: () => _correctAssumptions(value.baseline, outcome),
          ),
        ),
      const SizedBox(height: 16),
      PlainCard(
        child: PlainDisclosure(
          key: const Key('future-outcomes-what-if'),
          title: journeyText(
            context,
            'Try a custom what-if',
            'Probar un escenario hipotético',
          ),
          children: <Widget>[
            _CustomScenarioComposer(
              baseline: value.baseline,
              horizonDays: horizonDays,
              feedback: customFeedback == null
                  ? null
                  : _CustomComparisonFeedback(
                      key: _customFeedbackKey,
                      state: customFeedback,
                      onView: customFeedback == _CustomComparisonState.ready
                          ? _viewCustomComparison
                          : null,
                    ),
              onDraftChanged: _invalidateCustomFeedback,
              onComposed: (TrajectoryCustomScenarioDraft draft) {
                if (_isRefreshing) return;
                _recordReview();
                final request = _CustomComparisonRequest(
                  draft: draft,
                  scenarioId: trajectoryCustomScenarioId(
                    draft,
                    horizonDays: horizonDays,
                  ),
                  previous: model.comparison,
                  context: comparisonContext,
                );
                ref
                    .read(trajectoryCustomScenarioProvider.notifier)
                    .compose(draft);
                setState(() {
                  _customRequest = request;
                  _selection = _OptionSelection.custom(request.scenarioId);
                });
              },
              onClear: () {
                if (_isRefreshing) return;
                ref.read(trajectoryCustomScenarioProvider.notifier).clear();
                setState(() {
                  _selection = null;
                  _customRequest = null;
                });
              },
            ),
          ],
        ),
      ),
      PlainSection(
        title: journeyText(context, 'More detail', 'Más detalle'),
        children: <Widget>[
          PlainCard(
            child: PlainDisclosure(
              key: const Key('future-outcomes-based-on'),
              title: journeyText(
                context,
                'What this is based on',
                'En qué se basa',
              ),
              children: <Widget>[
                _BasedOnDetails(baseline: value.baseline, model: displayModel),
                if (displayModel.decisionIntelligence
                    case final DecisionIntelligence intelligence) ...<Widget>[
                  const SizedBox(height: 12),
                  _PlanningSummary(
                    intelligence: intelligence,
                    onAction: () =>
                        _openDecisionAction(intelligence.decision.actionIntent),
                  ),
                ],
              ],
            ),
          ),
          PlainCard(
            child: PlainDisclosure(
              key: const Key('future-outcomes-monitoring'),
              title: journeyText(
                context,
                'Forecast monitoring',
                'Seguimiento de previsiones',
              ),
              children: <Widget>[
                _MonitoringDetails(summary: displayCalibration),
              ],
            ),
          ),
          PlainCard(
            child: PlainDisclosure(
              key: const Key('insights-how-it-helps'),
              title: journeyText(
                context,
                'How this helps you',
                'Cómo te ayuda esto',
              ),
              children: const <Widget>[_HowThisHelps()],
            ),
          ),
        ],
      ),
    ];
  }

  /// Whether [outcome] is shown because the person chose it (rather than
  /// as the recommended or first option): the same option, or the same kind
  /// of option about the same task (a range change). A fallback to the same
  /// kind of option about another task is "Option shown", not "picked".
  bool _pickedByPerson(TrajectoryScenarioOutcome outcome) {
    final _OptionSelection? selection = _selection;
    if (selection == null) return false;
    return outcome.intervention.id == selection.interventionId ||
        (!selection.isCustom &&
            !_isCustomOutcome(outcome) &&
            outcome.intervention.type == selection.type &&
            outcome.intervention.subjectId == selection.subjectId);
  }

  void _invalidateCustomFeedback() {
    // Invalidate retained callbacks immediately, including subject replacement
    // during the composer's didUpdateWidget. Rebuild after the current frame.
    _customRequest = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _customRequest == null) setState(() {});
    });
  }

  _CustomComparisonState? _customFeedbackState(TrajectoryEngineModel model) {
    final request = _customRequest;
    if (request == null || !_customRequestIsCurrent(request)) {
      return null;
    }
    if (_isRefreshing || model.status == TrajectoryEngineStatus.loading) {
      return _CustomComparisonState.pending;
    }
    if (model.status == TrajectoryEngineStatus.error ||
        model.comparison == null) {
      return _CustomComparisonState.unavailable;
    }
    final comparison = model.comparison!;
    final matching =
        comparison.baseline.accountScope == request.context.$1 &&
        comparison.outcomes.any(
          (outcome) =>
              outcome.intervention.id == request.scenarioId &&
              outcome.intervention.horizon.inDays == request.context.$3,
        );
    if (matching) {
      // Repeating the identical request may reuse an already reconciled result.
      return _CustomComparisonState.ready;
    }
    // Retained AsyncData is not a rejection of this request. A synchronous
    // rejected draft produces a fresh comparison without its outcome.
    if (identical(model.comparison, request.previous)) {
      return _CustomComparisonState.pending;
    }
    if (comparison.outcomes.any(_isCustomOutcome)) {
      // An older custom result is not a rejection of the latest request.
      return _CustomComparisonState.pending;
    }
    return _CustomComparisonState.unavailable;
  }

  bool _customRequestIsCurrent(_CustomComparisonRequest request) =>
      request.context ==
          (
            ref.read(accountStorageScopeProvider).v2Namespace,
            ref.read(authSessionBoundaryProvider).generation,
            ref.read(trajectoryHorizonDaysProvider),
          ) &&
      identical(ref.read(trajectoryCustomScenarioProvider), request.draft);

  void _revealCustomFeedback(_CustomComparisonRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_customRequest, request) ||
          !_customRequestIsCurrent(request)) {
        return;
      }
      final target = _customFeedbackKey.currentContext;
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target, alignment: 1));
      }
    });
  }

  void _viewCustomComparison() {
    final request = _customRequest;
    if (request == null ||
        _customFeedbackState(ref.read(trajectoryEngineModelProvider)) !=
            _CustomComparisonState.ready) {
      return;
    }
    setState(() => _selection = _OptionSelection.custom(request.scenarioId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(request, _customRequest) ||
          _customFeedbackState(ref.read(trajectoryEngineModelProvider)) !=
              _CustomComparisonState.ready) {
        return;
      }
      final target = _comparisonPreviewKey.currentContext;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: .05,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          ),
        );
      }
    });
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
                ? '$reconciled ${reconciled == 1 ? 'previsión anterior comprobada' : 'previsiones anteriores comprobadas'} con tus registros.'
                : '$reconciled earlier forecast${reconciled == 1 ? '' : 's'} checked against your records.',
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
                  'Option tracked. Its estimate is checked against what you record later.',
                  'Opción supervisada. Su estimación se compara con lo que registres después.',
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
                  'Forecast excluded on this device. Its assumptions and estimate stay visible, but it does not count toward monitoring.',
                  'Previsión excluida en este dispositivo. Sus supuestos y su estimación siguen visibles, pero no cuenta para el seguimiento.',
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

  /// Review on the selected option opens what its button names: the task the
  /// option is about, Choose a step or the Schedule. Nothing is saved without
  /// the person's own Save or Done, and never in another account.
  void _openScenarioDestination(
    TrajectoryBaseline baseline,
    TrajectoryScenarioOutcome outcome,
  ) {
    if (_isRefreshing) return;
    switch (outcome.intervention.type) {
      case TrajectoryInterventionType.applySmartPlanner:
        goToAppView(context, ref, AppView.smartPlanner);
      case TrajectoryInterventionType.maintainCourse:
        unawaited(openSchedule(context));
      case TrajectoryInterventionType.completeTask:
        unawaited(_confirmComplete(baseline, outcome.intervention));
      case TrajectoryInterventionType.delayTask:
      case TrajectoryInterventionType.reduceScope:
      case TrajectoryInterventionType.recoverCommitment:
        unawaited(_editSubject(baseline, outcome));
    }
  }

  /// The same account check Today uses before it writes a task.
  bool _sameAccount(int generation, String? namespace) =>
      mounted &&
      ref.read(authSessionBoundaryProvider).generation == generation &&
      ref.read(accountStorageScopeProvider).isWritable &&
      ref.read(authSessionBoundaryProvider).isStorageReady &&
      !ref.read(authSessionBoundaryProvider).isTransitioning &&
      ref.read(authSessionBoundaryProvider).blockingIssue == null &&
      ref.read(accountStorageScopeProvider).v2Namespace == namespace;

  /// The option's task as it is now, or null. When it was finished or
  /// deleted since the estimate, says so and opens My plan.
  Future<TaskEntity?> _subjectTask(
    TrajectoryBaseline baseline,
    String? id,
    int generation,
    String? namespace,
  ) async {
    // An estimate from another account never leads to a write here.
    if (!_sameAccount(generation, namespace) ||
        baseline.accountScope != namespace) {
      return null;
    }
    List<Task>? tasks;
    try {
      tasks = await ref.read(allTasksProvider.future);
    } catch (_) {
      tasks = null;
    }
    if (!mounted || !_sameAccount(generation, namespace)) return null;
    if (tasks == null) {
      _showMessage(
        journeyText(
          context,
          'Your tasks could not be read. Try again.',
          'No se pudieron leer tus tareas. Inténtalo de nuevo.',
        ),
      );
      return null;
    }
    for (final Task task in tasks) {
      if (id != null && task.id == id) return task;
    }
    _showMessage(
      journeyText(
        context,
        'That task is no longer in your plan. It may have been finished or deleted.',
        'Esa tarea ya no está en tu plan. Puede que se haya terminado o eliminado.',
      ),
    );
    goToAppView(context, ref, AppView.timeline);
    return null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Shows a dialog with [open] and closes it if the account or sign-in
  /// changes while it is open. The caller still checks the account before
  /// writing anything with the result.
  Future<T?> _dialogInThisAccount<T>(
    int generation,
    String? namespace,
    Future<T?> Function() open,
  ) async {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final Future<T?> result = open();
    // The dialog route was just pushed: it is the top route now.
    Route<dynamic>? dialog;
    navigator.popUntil((Route<dynamic> route) {
      dialog = route;
      return true;
    });
    void closeIfSwitched() {
      if (_sameAccount(generation, namespace)) return;
      final Route<dynamic>? route = dialog;
      if (route == null || !route.isActive) return;
      // Close anything opened over the dialog (a date picker), then it.
      navigator.popUntil((Route<dynamic> r) => r == route || r.isFirst);
      if (route.isCurrent) navigator.pop();
    }

    final List<ProviderSubscription<Object?>> subscriptions =
        <ProviderSubscription<Object?>>[
          ref.listenManual(
            accountStorageScopeProvider,
            (_, _) => scheduleMicrotask(closeIfSwitched),
          ),
          ref.listenManual(
            authSessionBoundaryProvider,
            (_, _) => scheduleMicrotask(closeIfSwitched),
          ),
        ];
    try {
      return await result;
    } finally {
      for (final ProviderSubscription<Object?> subscription in subscriptions) {
        subscription.close();
      }
    }
  }

  /// Delay, reduce and recover: the task edit dialog for the option's task,
  /// with a note naming the option. Delay starts from the delayed time.
  Future<void> _editSubject(
    TrajectoryBaseline baseline,
    TrajectoryScenarioOutcome outcome,
  ) async {
    final int generation = ref.read(authSessionBoundaryProvider).generation;
    final String? namespace = ref.read(accountStorageScopeProvider).v2Namespace;
    final TrajectoryIntervention intervention = outcome.intervention;
    final TaskEntity? task = await _subjectTask(
      baseline,
      intervention.subjectId,
      generation,
      namespace,
    );
    if (task == null || !mounted) return;
    // The engine's rule for this option (FutureConsequenceEngine's timeline
    // consequence): the task's scheduled time, or the estimate's time when
    // it has none, plus the option's own delay.
    final DateTime? delayed =
        intervention.type == TrajectoryInterventionType.delayTask
        ? (task.scheduledFor ?? outcome.generatedAt.toLocal()).add(
            intervention.delay,
          )
        : null;
    final TaskEditDraft? draft = await _dialogInThisAccount(
      generation,
      namespace,
      () => showTaskEditDialog(
        context: context,
        editable: task,
        goals: ref.read(goalsProvider),
        note: _reviewNote(context, intervention),
        initialScheduledFor: delayed,
      ),
    );
    if (draft == null || !_sameAccount(generation, namespace)) return;
    try {
      await ref
          .read(taskActionsProvider)
          .updateTaskDetails(
            id: task.id,
            title: draft.title,
            description: draft.description,
            clearDescription: draft.description == null,
            priority: draft.priority,
            estimatedDuration: draft.estimatedDuration,
            clearEstimatedDuration: draft.estimatedDuration == null,
            scheduledFor: draft.scheduledFor,
            clearScheduledFor: draft.scheduledFor == null,
            dueDate: draft.dueDate,
            clearDueDate: draft.dueDate == null,
            goalId: draft.goalId,
            clearGoalId: draft.goalId == null,
          );
    } catch (_) {
      if (mounted && _sameAccount(generation, namespace)) {
        _showMessage(
          journeyText(
            context,
            'Could not save your changes. Please try again.',
            'No se pudieron guardar los cambios. Inténtalo de nuevo.',
          ),
        );
      }
    }
  }

  /// Complete: a small confirm dialog naming the task, then Done completes it.
  Future<void> _confirmComplete(
    TrajectoryBaseline baseline,
    TrajectoryIntervention intervention,
  ) async {
    final int generation = ref.read(authSessionBoundaryProvider).generation;
    final String? namespace = ref.read(accountStorageScopeProvider).v2Namespace;
    final TaskEntity? task = await _subjectTask(
      baseline,
      intervention.subjectId,
      generation,
      namespace,
    );
    if (task == null || !mounted) return;
    final bool? done = await _dialogInThisAccount(
      generation,
      namespace,
      () => showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) =>
            _CompleteTaskDialog(title: task.title),
      ),
    );
    if (done != true || !_sameAccount(generation, namespace)) return;
    try {
      await ref.read(taskActionsProvider).completeTask(task.id, notify: false);
      if (mounted && _sameAccount(generation, namespace)) {
        _showMessage(
          journeyText(
            context,
            'Completed. Your progress is recorded.',
            'Completada. Tu progreso quedó registrado.',
          ),
        );
      }
    } catch (_) {
      if (mounted && _sameAccount(generation, namespace)) {
        _showMessage(
          journeyText(
            context,
            'Could not complete this task. Please try again.',
            'No se pudo completar la tarea. Inténtalo de nuevo.',
          ),
        );
      }
    }
  }
}

/// "Mark "X" done?" with Cancel and Done. Done returns true.
class _CompleteTaskDialog extends StatelessWidget {
  const _CompleteTaskDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Large text on a small screen scrolls instead of overflowing.
      scrollable: true,
      title: Text(
        journeyText(
          context,
          'Mark "$title" done?',
          '¿Marcar "$title" como hecha?',
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(journeyText(context, 'Cancel', 'Cancelar')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(journeyText(context, 'Done', 'Hecha')),
        ),
      ],
    );
  }
}

/// The one-line note in the task edit dialog naming the option it came from.
String _reviewNote(BuildContext context, TrajectoryIntervention intervention) {
  final String from = InsightsCopy.of(context).futureOutcomes;
  if (intervention.type == TrajectoryInterventionType.delayTask) {
    final int days = intervention.delay.inDays < 1
        ? 1
        : intervention.delay.inDays;
    return journeyText(
      context,
      'From $from: put off by ${days == 1 ? 'one day' : '$days days'}',
      'Desde $from: aplazar ${days == 1 ? 'un día' : '$days días'}',
    );
  }
  final String option = _trajectoryGeneratedText(context, intervention.title);
  return journeyText(context, 'From $from: $option', 'Desde $from: $option');
}

/// The bar shown over the bottom of the page while a refresh is running.
class _RefreshingBar extends StatelessWidget {
  const _RefreshingBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSecondary,
      child: SafeArea(
        top: false,
        child: PlainPaletteScope(
          palette: PlainPalette.page,
          child: Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                journeyText(
                  context,
                  'Updating estimate. The previous result is shown; the controls come back when it is ready.',
                  'Actualizando la estimación. Se muestra el resultado anterior; los controles vuelven cuando esté lista.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
