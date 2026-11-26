import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

final _scope = AccountStorageScope.authenticated('refresh-test');
final _model = NotifierProvider<_Model, TrajectoryEngineModel>(_Model.new);

class _CountingActions extends TrajectoryForecastLedgerActions {
  _CountingActions(super.ref);
  int tracks = 0;
  int reconciles = 0;
  @override
  Future<bool> track({
    required TrajectoryBaseline baseline,
    required TrajectoryScenarioOutcome outcome,
  }) async {
    tracks++;
    return false;
  }

  @override
  Future<TrajectoryReconcileCounts> reconcile(
    TrajectoryBaseline baseline,
  ) async {
    reconciles++;
    return TrajectoryReconcileCounts.none;
  }
}

class _Model extends Notifier<TrajectoryEngineModel> {
  @override
  TrajectoryEngineModel build() => _ready();

  void revise() => state = _ready(revision: 'next-baseline');

  void show(TrajectoryEngineStatus status) {
    final ready = _ready();
    state = status == TrajectoryEngineStatus.ready
        ? ready
        : TrajectoryEngineModel(
            status: status,
            summary: const TrajectorySummaryView(
              pendingTasks: 0,
              completedTasks: 0,
              completedToday: 0,
              level: 0,
              streak: 0,
              energy: 0,
              momentum: 0,
              adaptability: 0,
              lastCompletionXp: 0,
              lastCompletionQuality: 0,
              pressureIndex: 0,
              behaviorDivergence: 0,
              alert: '',
              predictionTitle: null,
              predictionOutcome: null,
              predictionProbability: null,
              predictionExplanation: null,
            ),
            momentum: ready.momentum,
            statusDetail: 'Evidence refresh test',
            hasAvailableNetworkInterface: true,
          );
  }
}

TrajectoryEngineModel _ready({String revision = 'original-baseline'}) {
  final fixture = trajectoryTestEngineModel();
  final baseline = trajectoryTestBaseline();
  // Keep the account identity real: retained estimates must match the
  // current account namespace, not only a matching widget instance.
  final scoped = TrajectoryBaseline(
    accountScope: _scope.v2Namespace!,
    revision: revision,
    observedAt: baseline.observedAt,
    evidenceWindow: baseline.evidenceWindow,
    momentum: baseline.momentum,
    pressure: baseline.pressure,
    energy: baseline.energy,
    completedInWindow: baseline.completedInWindow,
    deferredInWindow: baseline.deferredInWindow,
    observationCount: baseline.observationCount,
    availableMinutes: baseline.availableMinutes,
    occupiedMinutes: baseline.occupiedMinutes,
    unscheduledMinutes: baseline.unscheduledMinutes,
    tasks: baseline.tasks,
    goals: baseline.goals,
    blocks: baseline.blocks,
    timelineSignals: baseline.timelineSignals,
    progression: baseline.progression,
    confidence: baseline.confidence,
    sourceRevisions: baseline.sourceRevisions,
    energyOrigin: baseline.energyOrigin,
    availabilityOrigin: baseline.availabilityOrigin,
  );
  return TrajectoryEngineModel(
    status: TrajectoryEngineStatus.ready,
    summary: fixture.summary,
    momentum: fixture.momentum,
    statusDetail: fixture.statusDetail,
    comparison: trajectoryTestComparison(baseline: scoped),
    hasAvailableNetworkInterface: true,
  );
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  ThemeData? theme,
  bool scheduleSources = false,
  Locale? locale,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(_scope),
        if (scheduleSources) ...[
          goalsProvider.overrideWith(_ScheduleGoals.new),
          timelineProvider.overrideWith(_ScheduleTimeline.new),
          timelinePersistenceCorruptedProvider.overrideWithValue(false),
          allTasksProvider.overrideWith((ref) async => const <Task>[]),
        ],
        trajectoryForecastLedgerActionsProvider.overrideWith(
          _CountingActions.new,
        ),
        trajectoryCalibrationSummaryProvider.overrideWithValue(
          const AsyncValue<TrajectoryCalibrationSummary>.data(
            TrajectoryCalibrationSummary(
              resolvedForecasts: 0,
              momentumMeanAbsoluteError: 0,
              pressureMeanAbsoluteError: 0,
              intervalCoverage: 0,
              state: PredictiveCalibrationState.provisional,
            ),
          ),
        ),
        trajectoryEngineModelProvider.overrideWith((ref) => ref.watch(_model)),
      ],
      child: MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: const [
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const TrajectoryEngineScreen(),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(TrajectoryEngineScreen)),
  );
}

Future<void> _chooseDelay(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    find.text('Try a custom what-if').hitTestable(),
    300,
    scrollable: scrollable,
  );
  await tester.tap(find.text('Try a custom what-if').hitTestable());
  await tester.pump(const Duration(seconds: 1));
  await tester.scrollUntilVisible(
    find.text('Delay').hitTestable(),
    300,
    scrollable: scrollable,
  );
  await tester.tap(find.text('Delay').hitTestable());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(
    find.text('Compare over 7 days').hitTestable(),
    150,
    scrollable: scrollable,
  );
}

void main() {
  for (final es in <bool>[false, true]) {
    testWidgets('time range copy says it changes the estimate and reliability '
        '(${es ? 'es' : 'en'})', (tester) async {
      await _open(tester, locale: Locale(es ? 'es' : 'en'));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .toList();
      expect(texts.any((t) => t.contains('across the next')), isFalse);
      expect(texts.any((t) => t.contains('durante los próximos')), isFalse);
      expect(
        texts.any(
          (t) => es
              ? t == 'En los próximos 7 días.'
              : t == 'Over the next 7 days.',
        ),
        isTrue,
      );

      final helps = find.text(es ? 'Cómo te ayuda esto' : 'How this helps you');
      await tester.scrollUntilVisible(
        helps.hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(helps.hitTestable());
      await tester.pump(const Duration(seconds: 1));
      final expected = es
          ? '• Elige una opción para ver cómo podrían cambiar tu carga de '
                'trabajo y tu ritmo. El periodo (7, 30 o 90 días) cambia la '
                'estimación: decide qué tareas cuentan y cuánto tiempo libre '
                'hay. Cuanto más lejos, menos fiable, por eso los rangos son '
                'más amplios. “Ajuste recomendado” marca la opción que mejor '
                'se ve ahora, cuando hay suficiente historial.'
          : '• Pick an option to see how your workload and pace could change. '
                'The time range (7, 30 or 90 days) changes the estimate: it '
                'sets which tasks count and how much free time there is. '
                'Further ahead is less reliable, so the ranges are wider. '
                '“Recommended adjustment” marks the option that looks best '
                'right now, once there is enough history.';
      expect(find.text(expected), findsOneWidget);

      final title = _ready().comparison!.outcomes.first.intervention.title;
      await tester.ensureVisible(find.text(title).first);
      await tester.pump();
      await tester.tap(find.text(title).first);
      await tester.pump(const Duration(seconds: 1));
      final marker = es
          ? 'Frente a seguir como vas'
          : 'Compared with keeping going';
      await tester.scrollUntilVisible(
        find.textContaining(marker).first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining(
          es
              ? 'decide qué tareas cuentan y cuánto tiempo libre hay'
              : 'it sets which tasks count and how much free time there is',
        ),
        findsWidgets,
      );
      // The old claim that the range leaves the numbers unchanged is gone.
      expect(find.textContaining('not the projected numbers'), findsNothing);
      expect(find.textContaining('no los números proyectados'), findsNothing);
      expect(find.textContaining('range only changes'), findsNothing);
      expect(find.textContaining('solo cambia lo amplia'), findsNothing);
      expect(find.textContaining('menos seguro'), findsNothing);
      expect(find.textContaining('less certain'), findsNothing);
      expect(find.textContaining('Over 7 days'), findsNothing);
      expect(find.textContaining('Durante 7 días'), findsNothing);
    });
  }

  testWidgets(
    'forecast review opens actual Schedule and Back retains Insights preview',
    (tester) async {
      final container = await _open(tester, scheduleSources: true);
      container.read(appFlowProvider.notifier).show(AppView.trajectoryEngine);
      final target = _ready().comparison!.outcomes.firstWhere(
        (outcome) =>
            outcome.intervention.type ==
            TrajectoryInterventionType.maintainCourse,
      );
      expect(target.intervention.title, 'Maintain current course');
      // The keep-going option goes by the page's own name for it.
      const String shown = 'Keep going as you are';
      await tester.scrollUntilVisible(
        find.text(shown).first.hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(shown).first.hitTestable());
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Review on Schedule').hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review on Schedule').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(container.read(appFlowProvider), AppView.trajectoryEngine);
      final Finder scheduleBack = find.descendant(
        of: find.byType(TimelineScreen),
        matching: find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
      );
      expect(tester.widget<IconButton>(scheduleBack).tooltip, 'Back');
      await tester.tap(scheduleBack);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(TimelineScreen), findsNothing);
      expect(find.byType(TrajectoryEngineScreen), findsOneWidget);
      expect(find.text('Review on Schedule').hitTestable(), findsOneWidget);
      expect(container.read(appFlowProvider), AppView.trajectoryEngine);
      final actions =
          container.read(trajectoryForecastLedgerActionsProvider)
              as _CountingActions;
      expect(actions.tracks, 0);
      expect(actions.reconciles, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'planner adjustment still selects Choose a step instead of Schedule',
    (tester) async {
      final container = await _open(tester, scheduleSources: true);
      final target = _ready().comparison!.outcomes.firstWhere(
        (outcome) =>
            outcome.intervention.type ==
            TrajectoryInterventionType.applySmartPlanner,
      );
      await tester.scrollUntilVisible(
        find.text(target.intervention.title).first.hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.text(target.intervention.title).first.hitTestable(),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Open Choose a step').hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open Choose a step').hitTestable());
      await tester.pump();
      expect(container.read(appFlowProvider), AppView.smartPlanner);
      expect(find.byType(TimelineScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [appTheme, appLightTheme]) {
    testWidgets(
      '${theme.brightness.name} what-if segments remain readable and local',
      (tester) async {
        final container = await _open(tester, theme: theme);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        await _chooseDelay(tester);
        final segmented = find.byType(
          SegmentedButton<TrajectoryCustomAdjustment>,
        );
        await tester.ensureVisible(segmented);
        await tester.pump(const Duration(milliseconds: 350));
        for (final label in ['Complete', 'Delay', 'Remove']) {
          final text = find.descendant(
            of: segmented,
            matching: find.text(label),
          );
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final material = tester.widget<Material>(
            find.ancestor(of: text, matching: find.byType(Material)).first,
          );
          expect(material.color, isNotNull);
          final foreground = Color.alphaBlend(
            paragraph.text.style!.color!,
            material.color!,
          ).computeLuminance();
          final background = material.color!.computeLuminance();
          final contrast = foreground > background
              ? (foreground + .05) / (background + .05)
              : (background + .05) / (foreground + .05);
          expect(contrast, greaterThanOrEqualTo(4.5), reason: label);
        }
        expect(
          Theme.of(tester.element(segmented)).brightness,
          theme.brightness,
        );
        final actions =
            container.read(trajectoryForecastLedgerActionsProvider)
                as _CountingActions;
        expect(actions.tracks, 0);
        expect(actions.reconciles, 0);
        expect(container.read(trajectoryCustomScenarioProvider), isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('selected modeled path survives a new baseline revision', (
    tester,
  ) async {
    final container = await _open(tester);
    final target = _ready().comparison!.outcomes.last;
    expect(target.id, isNot(_ready().comparison!.recommendedScenarioId));
    await tester.scrollUntilVisible(
      find.text(target.intervention.title).first.hitTestable(),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(target.intervention.title).first.hitTestable());
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text(target.intervention.description),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    container.read(_model.notifier).revise();
    await tester.pump();
    expect(find.text(target.intervention.description), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'refresh keeps expanded Delay composer and scroll, blocks stale actions',
    (tester) async {
      final container = await _open(tester);
      await _chooseDelay(tester);
      expect(find.text('Put off by: 1 day'), findsOneWidget);

      final compare = find.widgetWithText(FilledButton, 'Compare over 7 days');
      final oldCompare = tester.widget<FilledButton>(compare).onPressed!;
      Focus.of(tester.element(find.text('Compare over 7 days'))).requestFocus();
      await tester.pump();
      expect(
        Focus.of(tester.element(find.text('Compare over 7 days'))).hasFocus,
        isTrue,
      );
      // Focus is a separate interaction and may reveal its target. Measure
      // the settled viewport immediately before the evidence refresh itself.
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = position.pixels;
      final extent = position.maxScrollExtent;
      final compareY = tester.getTopLeft(find.text('Compare over 7 days')).dy;
      expect(offset, greaterThan(0));
      container.read(_model.notifier).show(TrajectoryEngineStatus.loading);
      await tester.pump();
      expect(position.maxScrollExtent, closeTo(extent, 1));
      expect(
        tester.getTopLeft(find.text('Compare over 7 days')).dy,
        closeTo(compareY, 1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      oldCompare(); // A callback obtained before refresh must also fail closed.
      expect(container.read(trajectoryCustomScenarioProvider), isNull);
      expect(
        find.textContaining('Updating estimate. The previous result'),
        findsOneWidget,
      );
      expect(find.text('Put off by: 1 day'), findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(offset, 1),
      );
      expect(
        tester
            .widget<AbsorbPointer>(
              find
                  .descendant(
                    of: find.byType(TrajectoryEngineScreen),
                    matching: find.byType(AbsorbPointer),
                  )
                  .first,
            )
            .absorbing,
        isTrue,
      );
      await tester.tap(find.text('Compare over 7 days'), warnIfMissed: false);
      expect(container.read(trajectoryCustomScenarioProvider), isNull);

      container.read(_model.notifier).revise();
      await tester.pump();
      expect(
        find.textContaining('Updating estimate. The previous result'),
        findsNothing,
      );
      expect(find.text('Put off by: 1 day'), findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(offset, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'focused Track cannot write while refreshing and the switch remains usable',
    (tester) async {
      final container = await _open(tester);
      final scroll = find.byType(Scrollable).first;
      const label = 'Track this option for monitoring';
      await tester.scrollUntilVisible(
        find.text(label).hitTestable(),
        300,
        scrollable: scroll,
      );
      final oldTrack = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
          .onPressed!;
      Focus.of(tester.element(find.text(label))).requestFocus();
      await tester.pump();
      expect(Focus.of(tester.element(find.text(label))).hasFocus, isTrue);
      container.read(_model.notifier).show(TrajectoryEngineStatus.loading);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      oldTrack();
      await tester.pump();
      final actions =
          container.read(trajectoryForecastLedgerActionsProvider)
              as _CountingActions;
      expect(actions.tracks, 0);
      expect(actions.reconciles, 0);
      expect(find.text(label), findsOneWidget);
      container.read(appFlowProvider.notifier).show(AppView.trajectoryEngine);
      await tester.drag(find.byType(ListView), const Offset(0, 20000));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Update estimate',
              ),
            )
            .onPressed,
        isNull,
      );
      // The Insights root has no Back arrow; the two-part switch still works.
      expect(find.byTooltip('Back'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(InsightsDestinationSwitch.switchKey),
          matching: find.text('Patterns'),
        ),
      );
      expect(container.read(appFlowProvider), AppView.progression);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded task follow-through retains rendered evidence during loading',
    (tester) async {
      final container = await _open(tester);
      await tester.scrollUntilVisible(
        find.text('What this is based on').hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('What this is based on').hitTestable());
      await tester.pump(const Duration(seconds: 1));
      final evidence = find.textContaining(
        'Completion is plausible if the protected block holds.',
      );
      await tester.scrollUntilVisible(
        evidence,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      container.read(_model.notifier).show(TrajectoryEngineStatus.loading);
      await tester.pump();
      // The incoming loading model has no task prediction; retaining comparison
      // alone would replace this expanded content and shrink the scroll extent.
      expect(evidence, findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(offset, 1),
      );
      container.read(_model.notifier).revise();
      await tester.pump();
      expect(evidence, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reason in [
    'error',
    'empty',
    'learning',
    'account-generation',
    'horizon',
  ]) {
    testWidgets('retained forecast clears on $reason', (tester) async {
      final container = await _open(tester);
      await _chooseDelay(tester);
      container.read(_model.notifier).show(TrajectoryEngineStatus.loading);
      await tester.pump();
      expect(find.text('Put off by: 1 day'), findsOneWidget);
      switch (reason) {
        case 'account-generation':
          container
              .read(authSessionBoundaryProvider.notifier)
              .begin(userId: 'other', isTransitioning: true);
        case 'horizon':
          container.read(trajectoryHorizonDaysProvider.notifier).select(30);
        default:
          container
              .read(_model.notifier)
              .show(TrajectoryEngineStatus.values.byName(reason));
      }
      await tester.pump();
      expect(find.text('Put off by: 1 day'), findsNothing);
      expect(
        find.textContaining('Updating estimate. The previous result'),
        findsNothing,
      );
      expect(find.text('If you keep going as you are'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ScheduleGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _ScheduleTimeline extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];
}
