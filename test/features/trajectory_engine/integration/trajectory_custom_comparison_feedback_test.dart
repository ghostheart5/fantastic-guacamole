import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

final _account = NotifierProvider<_Account, AccountStorageScope>(_Account.new);

class _Account extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() =>
      AccountStorageScope.authenticated('comparison-test');
  void change() => state = AccountStorageScope.authenticated('another-account');
}

class _ControlState {
  const _ControlState(this.mode, [this.model]);
  final String mode;
  final TrajectoryEngineModel? model;
}

final _control = NotifierProvider<_Control, _ControlState>(_Control.new);

class _Control extends Notifier<_ControlState> {
  @override
  _ControlState build() => const _ControlState('automatic');
  void hold(TrajectoryEngineModel model) =>
      state = _ControlState('hold', model);
  void show(TrajectoryEngineModel model) =>
      state = _ControlState('show', model);
  void mode(String mode) => state = _ControlState(mode);
}

// Guidance persistence has its own integration tests. This screen fixture
// isolates that startup side effect while exercising real comparison rendering.
class _QuietGuidance extends AdaptiveGuidanceNotifier {
  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: {},
    counts: {},
    skippedLessons: {},
    completedLessons: {},
  );
  @override
  Future<void> record(
    GuidanceMilestone milestone, {
    bool Function()? shouldContinue,
  }) async {}
}

class _Actions extends TrajectoryForecastLedgerActions {
  _Actions(super.ref);
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
  Future<int> reconcile(TrajectoryBaseline baseline) async {
    reconciles++;
    return 0;
  }
}

TrajectoryBaseline _baseline(String accountScope) {
  final b = trajectoryTestBaseline();
  return TrajectoryBaseline(
    accountScope: accountScope,
    revision: 'current-baseline',
    observedAt: b.observedAt,
    evidenceWindow: b.evidenceWindow,
    momentum: b.momentum,
    pressure: b.pressure,
    energy: b.energy,
    completedInWindow: b.completedInWindow,
    deferredInWindow: b.deferredInWindow,
    observationCount: b.observationCount,
    availableMinutes: b.availableMinutes,
    occupiedMinutes: b.occupiedMinutes,
    unscheduledMinutes: b.unscheduledMinutes,
    tasks: const [
      TrajectoryTaskNode(
        id: 'undated',
        title: 'Undated task',
        priority: 3,
        estimatedMinutes: 20,
      ),
    ],
    goals: const [],
    blocks: const [],
    timelineSignals: const [],
    progression: b.progression,
    confidence: b.confidence,
    sourceRevisions: b.sourceRevisions,
  );
}

TrajectoryEngineModel _model(
  TrajectoryCustomScenarioDraft? draft, {
  String? accountScope,
  int days = 7,
  TrajectoryEngineStatus status = TrajectoryEngineStatus.ready,
}) {
  final fixture = trajectoryTestEngineModel();
  final baseline = _baseline(
    accountScope ??
        AccountStorageScope.authenticated('comparison-test').v2Namespace!,
  );
  final interventions = <TrajectoryIntervention>[
    TrajectoryIntervention(
      id: 'maintain',
      type: TrajectoryInterventionType.maintainCourse,
      title: 'Keep current plan',
      description: 'Keep the current plan.',
      horizon: Duration(days: days),
    ),
    if (draft != null)
      TrajectoryIntervention(
        id: trajectoryCustomScenarioId(draft, horizonDays: days),
        type: switch (draft.adjustment) {
          TrajectoryCustomAdjustment.complete =>
            TrajectoryInterventionType.completeTask,
          TrajectoryCustomAdjustment.delay =>
            TrajectoryInterventionType.delayTask,
          TrajectoryCustomAdjustment.reduceScope =>
            TrajectoryInterventionType.reduceScope,
        },
        title:
            'My scenario: ${draft.adjustment == TrajectoryCustomAdjustment.complete ? 'complete' : 'delay'} Undated task',
        description: 'A local comparison; no task changes.',
        subjectId: draft.subjectId,
        delay: Duration(days: draft.delayDays),
        horizon: Duration(days: days),
      ),
  ];
  return TrajectoryEngineModel(
    status: status,
    summary: fixture.summary,
    momentum: fixture.momentum,
    statusDetail: 'Current comparison test',
    hasAvailableNetworkInterface: true,
    comparison:
        status == TrajectoryEngineStatus.loading ||
            status == TrajectoryEngineStatus.error
        ? null
        : const FutureConsequenceEngine().compare(
            baseline: baseline,
            interventions: interventions,
            generatedAt: baseline.observedAt,
          ),
  );
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<ProviderContainer> _open(WidgetTester tester, {bool es = false}) async {
  tester.view.physicalSize = const Size(450, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWith((ref) => ref.watch(_account)),
      trajectoryForecastLedgerActionsProvider.overrideWith(_Actions.new),
      adaptiveGuidanceProvider.overrideWith(_QuietGuidance.new),
      trajectoryCalibrationSummaryProvider.overrideWithValue(
        const AsyncData(
          TrajectoryCalibrationSummary(
            resolvedForecasts: 0,
            momentumMeanAbsoluteError: 0,
            pressureMeanAbsoluteError: 0,
            intervalCoverage: 0,
            state: PredictiveCalibrationState.provisional,
          ),
        ),
      ),
      trajectoryEngineModelProvider.overrideWith((ref) {
        final control = ref.watch(_control);
        final draft = ref.watch(trajectoryCustomScenarioProvider);
        final days = ref.watch(trajectoryHorizonDaysProvider);
        final scope = ref.watch(_account);
        if (control.model != null) return control.model!;
        return _model(
          control.mode == 'rejected' ? null : draft,
          days: days,
          accountScope: scope.v2Namespace,
          status: control.mode == 'loading'
              ? TrajectoryEngineStatus.loading
              : control.mode == 'error'
              ? TrajectoryEngineStatus.error
              : TrajectoryEngineStatus.ready,
        );
      }),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(es ? 'es' : 'en'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: const [
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: es),
          child: child!,
        ),
        home: const TrajectoryEngineScreen(),
      ),
    ),
  );
  await _frames(tester);
  return container;
}

Future<void> _composer(WidgetTester tester, {bool es = false}) async {
  final scroll = find.byType(Scrollable).first;
  final label = es ? 'Probar un escenario hipotético' : 'Try a custom what-if';
  await tester.scrollUntilVisible(
    find.text(label).hitTestable(),
    250,
    scrollable: scroll,
  );
  await tester.tap(find.text(label).hitTestable());
  await _frames(tester);
  await tester.scrollUntilVisible(
    find
        .text(es ? 'Comparar trayectoria de 7 días' : 'Compare 7-day path')
        .hitTestable(),
    180,
    scrollable: scroll,
  );
  await _frames(tester);
}

Future<void> _compare(WidgetTester tester, {bool es = false}) async {
  await tester.tap(
    find
        .text(es ? 'Comparar trayectoria de 7 días' : 'Compare 7-day path')
        .hitTestable(),
  );
  await _frames(tester);
}

void _noSavedChanges(ProviderContainer container) {
  final actions =
      container.read(trajectoryForecastLedgerActionsProvider) as _Actions;
  expect(actions.tracks, 0);
  expect(actions.reconciles, 0);
  final task = container
      .read(trajectoryEngineModelProvider)
      .comparison!
      .baseline
      .tasks
      .single;
  expect(task.id, 'undated');
  expect(task.dueAt, isNull);
  expect(task.scheduledAt, isNull);
}

void main() {
  for (final es in [false, true]) {
    testWidgets(
      '${es ? 'Spanish reduced-motion' : 'English'} scrolled composer confirms and reveals matching preview',
      (tester) async {
        final container = await _open(tester, es: es);
        try {
          await _composer(tester, es: es);
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(
                  find.byType(DropdownButtonFormField<String>),
                )
                .initialValue,
            'undated',
          );
          await _compare(tester, es: es);
          expect(
            container.read(trajectoryCustomScenarioProvider)!.subjectId,
            'undated',
          );
          final view = es ? 'Ver comparación' : 'View comparison';
          expect(find.text(view).hitTestable(), findsOneWidget);
          final receipt = find.text(
            es
                ? 'Tu comparación está lista. Solo es una vista previa; no se guardaron cambios.'
                : 'Your comparison is ready. Preview only; no changes saved.',
          );
          expect(receipt.hitTestable(), findsOneWidget);
          expect(
            tester
                .widget<Semantics>(
                  find
                      .ancestor(of: receipt, matching: find.byType(Semantics))
                      .first,
                )
                .properties
                .liveRegion,
            isTrue,
          );
          // A provider may reuse an already reconciled identical result.
          container
              .read(_control.notifier)
              .hold(container.read(trajectoryEngineModelProvider));
          await tester.ensureVisible(
            find.text(
              es ? 'Comparar trayectoria de 7 días' : 'Compare 7-day path',
            ),
          );
          await _compare(tester, es: es);
          expect(find.text(view).hitTestable(), findsOneWidget);
          await tester.tap(find.text(view).hitTestable());
          // View schedules animateTo after layout. Start its first animation
          // frame before advancing beyond the production 250 ms duration.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .isScrollingNotifier
                .value,
            isFalse,
          );
          expect(
            find
                .text(
                  es
                      ? 'Mi escenario: completar Undated task'
                      : 'My scenario: complete Undated task',
                )
                .last
                .hitTestable(),
            findsOneWidget,
          );
          _noSavedChanges(container);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await tester.pump(Duration.zero);
        }
      },
    );
  }

  testWidgets(
    'retained old data and loading cannot claim ready or rejection before reconciled result',
    (tester) async {
      final container = await _open(tester);
      try {
        container
            .read(_control.notifier)
            .hold(container.read(trajectoryEngineModelProvider));
        await _composer(tester);
        await _compare(tester);
        expect(find.text('Updating your comparison…'), findsOneWidget);
        expect(find.text('View comparison'), findsNothing);
        expect(find.textContaining('could not be compared'), findsNothing);
        container.read(_control.notifier).mode('loading');
        await _frames(tester);
        expect(find.text('Updating your comparison…'), findsOneWidget);
        container.read(_control.notifier).mode('automatic');
        await _frames(tester);
        expect(find.text('View comparison'), findsOneWidget);
        _noSavedChanges(container);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(Duration.zero);
      }
    },
  );

  testWidgets(
    'synchronously rejected draft gets honest feedback; clear removes receipt',
    (tester) async {
      final container = await _open(tester);
      try {
        container.read(_control.notifier).mode('rejected');
        await _composer(tester);
        await _compare(tester);
        expect(
          find.textContaining('This change could not be compared'),
          findsOneWidget,
        );
        expect(find.text('View comparison'), findsNothing);
        expect(find.text('Updating your comparison…'), findsNothing);
        await tester.ensureVisible(find.text('Clear my scenario'));
        await tester.tap(find.text('Clear my scenario'));
        await _frames(tester);
        expect(container.read(trajectoryCustomScenarioProvider), isNull);
        expect(
          find.textContaining('This change could not be compared'),
          findsNothing,
        );
        _noSavedChanges(container);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(Duration.zero);
      }
    },
  );

  testWidgets('an older custom result cannot satisfy the latest request', (
    tester,
  ) async {
    final container = await _open(tester);
    try {
      container
          .read(_control.notifier)
          .hold(container.read(trajectoryEngineModelProvider));
      await _composer(tester);
      await _compare(tester);
      final first = container.read(trajectoryCustomScenarioProvider)!;
      await tester.ensureVisible(find.text('Delay'));
      await tester.tap(find.text('Delay'));
      await _frames(tester);
      await tester.ensureVisible(find.text('Compare 7-day path'));
      await _compare(tester);
      final latest = container.read(trajectoryCustomScenarioProvider)!;
      expect(latest.adjustment, TrajectoryCustomAdjustment.delay);
      container.read(_control.notifier).show(_model(first));
      await _frames(tester);
      expect(find.text('View comparison'), findsNothing);
      expect(find.text('Updating your comparison…'), findsOneWidget);
      container.read(_control.notifier).show(_model(latest));
      await _frames(tester);
      expect(find.text('View comparison'), findsOneWidget);
      _noSavedChanges(container);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(Duration.zero);
    }
  });

  for (final change in ['horizon', 'account', 'generation']) {
    testWidgets('$change removes an old comparison receipt and action', (
      tester,
    ) async {
      final container = await _open(tester);
      try {
        await _composer(tester);
        await _compare(tester);
        expect(find.text('View comparison'), findsOneWidget);
        final oldView = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'View comparison'),
            )
            .onPressed!;
        switch (change) {
          case 'horizon':
            container.read(trajectoryHorizonDaysProvider.notifier).select(30);
          case 'account':
            container.read(_account.notifier).change();
          case 'generation':
            final boundary = container.read(
              authSessionBoundaryProvider.notifier,
            );
            final generation = boundary.begin(
              userId: 'comparison-test',
              isTransitioning: true,
            );
            boundary.complete(generation);
        }
        oldView(); // A callback retained before the next frame must fail closed.
        await _frames(tester);
        expect(find.text('View comparison'), findsNothing);
        expect(find.textContaining('Your comparison is ready.'), findsNothing);
        expect(find.text('Updating your comparison…'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(Duration.zero);
      }
    });
  }

  testWidgets(
    'model failure reports unavailable rather than leaving a pending request',
    (tester) async {
      final container = await _open(tester);
      try {
        container
            .read(_control.notifier)
            .hold(container.read(trajectoryEngineModelProvider));
        await _composer(tester);
        await _compare(tester);
        container.read(_control.notifier).mode('error');
        await _frames(tester);
        expect(
          find.textContaining('This change could not be compared'),
          findsOneWidget,
        );
        expect(find.text('View comparison'), findsNothing);
        expect(find.text('Updating your comparison…'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(Duration.zero);
      }
    },
  );
}
