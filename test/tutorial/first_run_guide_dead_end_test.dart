import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression coverage for first-run guide dead ends found in the 4.2.2 audit:
// every path into Creator or Timeline must leave a reachable, enabled target.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'confirming with the highlighted Creator button keeps the Timeline step',
    (WidgetTester tester) async {
      _tallView(tester);
      final _Tasks repo = _Tasks();
      final ProviderContainer container = _container(repo);
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      await container
          .read(creatorHandshakeProvider.notifier)
          .stage(
            data: CreatorFormData(
              title: 'First scheduled task',
              type: 'Task',
              priority: 4,
              scheduledFor: DateTime.now().add(const Duration(hours: 2)),
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CreatorScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(FirstRunTutorialTargets.creatorConfirm.currentContext, isNotNull);

      final Finder confirm = find.byKey(const Key('creator-confirm-selected'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(repo.saveCalls, 1);
      expect(
        state.expectedFirstRunCreatorTaskIds,
        equals(repo.tasks.keys.toSet()),
      );
      expect(
        state
            .nextIntervention(
              currentRoute: RoutePaths.timeline,
              decision: _decision,
            )
            ?.id,
        GuidanceLessonId.reviewTimeline,
      );
    },
  );

  testWidgets('restarting the guide mounts every Creator spotlight target', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(
      _Tasks.withScheduledTask(),
      overlay: true,
    );
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container.read(adaptiveGuidanceProvider.notifier).restartLessons();

    await _pumpCreatorWithGuide(tester, container);

    expect(find.text('Name the real task'), findsOneWidget);
    expect(FirstRunTutorialTargets.creatorTitle.currentContext, isNotNull);
    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Book the dentist');
    await tester.pump();
    expect(_primary(tester, 'Title entered').onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  test(
    'a returning account with restored tasks gets a guided Creator',
    () async {
      final ProviderContainer container = _container(
        _Tasks.withScheduledTask(),
      );
      addTearDown(container.dispose);
      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(state.has(GuidanceMilestone.firstSchedule), isTrue);
      expect(state.activeCoreLesson, GuidanceLessonId.createFirstItem);
      expect(state.guidesCreatorTask, isTrue);
    },
  );

  test('a paused first-run guide no longer forces guided Creator', () async {
    final ProviderContainer container = _container(_Tasks());
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container
        .read(adaptiveGuidanceProvider.notifier)
        .later(GuidanceLessonId.createFirstItem);
    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.activeCoreLesson, isNull);
    expect(state.guidesCreatorTask, isFalse);
  });

  testWidgets('Creator guide offers Back after the first step', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await _pumpCreatorWithGuide(tester, container);

    expect(find.byKey(const Key('tutorial_back_action')), findsNothing);
    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Book the dentist');
    await tester.pump();
    await tester.tap(find.text('Title entered'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Set its priority'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial_back_action')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Name the real task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausing the guide says where to resume it', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await _pumpCreatorWithGuide(tester, container);

    await tester.tap(find.text('Pause guide'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('guide-paused-snackbar')), findsOneWidget);
    expect(find.textContaining('Restart Adaptive Guide'), findsOneWidget);
    expect(find.text('Name the real task'), findsNothing);
  });

  testWidgets('core guidance does not cover the Smart Planner first choice', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    final GoRouter router = GoRouter(
      initialLocation: RoutePaths.smartPlanner,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.smartPlanner,
          builder: (_, _) => const Scaffold(body: Text('planner')),
        ),
        GoRoute(
          path: RoutePaths.nexus,
          builder: (_, _) => const Scaffold(body: Text('nexus')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouterWithGuide(tester, container, router);

    expect(find.text('Capture the first real commitment'), findsNothing);
    router.go(RoutePaths.nexus);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Capture the first real commitment'), findsOneWidget);
  });
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

FilledButton _primary(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
    ),
  );
}

Future<void> _pumpCreatorWithGuide(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final GoRouter router = GoRouter(
    initialLocation: RoutePaths.creator,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.creator,
        builder: (_, _) => const CreatorScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await _pumpRouterWithGuide(tester, container, router);
}

Future<void> _pumpRouterWithGuide(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => Stack(
          children: <Widget>[
            ?child,
            ListenableBuilder(
              listenable: router.routerDelegate,
              builder: (BuildContext context, Widget? _) {
                final String location =
                    router.routerDelegate.currentConfiguration.isEmpty
                    ? ''
                    : router.routerDelegate.state.uri.path;
                return AdaptiveGuideOverlay(
                  key: ValueKey<String>(location),
                  router: router,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  await container.read(authUserProvider.future);
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer _container(_Tasks repo, {bool overlay = false}) {
  return ProviderContainer(
    overrides: [
      sensitivePrefsStoreProvider.overrideWithValue(_Prefs()),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('account-a'),
      ),
      domainTaskRepositoryProvider.overrideWithValue(repo),
      domainGoalRepositoryProvider.overrideWithValue(const _Goals()),
      domainHabitRepositoryProvider.overrideWithValue(const _Habits()),
      domainNoteRepositoryProvider.overrideWithValue(const _Notes()),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      if (overlay) ...[
        onboardingCompleteProvider.overrideWith(_OnboardingDone.new),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(
            const User(
              id: 'account-a',
              email: 'account-a@example.test',
              emailVerified: true,
            ),
          ),
        ),
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        dailyDecisionIntelligenceProvider.overrideWith((Ref ref) => _decision),
      ],
    ],
  );
}

class _OnboardingDone extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'account-a',
    isTransitioning: false,
    isStorageReady: true,
  );
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Wait for evidence.',
  momentum: '0% stable',
  trajectory: 'No trajectory yet.',
  energy: 'Energy not checked',
  warning: 'No material constraint is supported by current evidence.',
  recovery: 'No recovery signal yet.',
  recommendedAction: 'Wait for evidence.',
  rationale: 'No evidence yet.',
  changeSummary: 'No prior state.',
  evidence: <String>[],
  confidence: 0,
  observedOutcomes: 0,
);

class _Tasks implements ITaskRepository {
  _Tasks();

  factory _Tasks.withScheduledTask() =>
      _Tasks()
        ..tasks['restored'] = TaskEntity(
          id: 'restored',
          title: 'Restored task',
          createdAt: DateTime.now(),
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
        );

  final Map<String, TaskEntity> tasks = <String, TaskEntity>{};
  int saveCalls = 0;

  @override
  Future<void> deleteTask(String id) async => tasks.remove(id);

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    saveCalls += 1;
    tasks[task.id] = task;
  }
}

class _Goals implements IGoalRepository {
  const _Goals();

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  List<GoalEntity> getGoals() => <GoalEntity>[];

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
}

class _Habits implements IHabitRepository {
  const _Habits();

  @override
  Future<List<HabitEntity>> getHabits() async => const <HabitEntity>[];

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}

class _Notes implements INoteRepository {
  const _Notes();

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<List<NoteEntity>> getNotes() async => const <NoteEntity>[];

  @override
  Future<void> saveNote(NoteEntity note) async {}
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
