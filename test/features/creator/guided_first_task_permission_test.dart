import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../permissions/notification_permission_test_support.dart';

/// The first task saved in the first-run guide always has a time, so this
/// is when a new person most needs the in-context notification question.
/// It is asked once the task is saved, and My plan still opens afterwards.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // Far enough ahead that the reminder is still to come.
  final DateTime at = DateTime.utc(2099, 3, 2, 9);

  Future<(PermissionFixture, _Tasks)> stageGuidedTask(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _Tasks tasks = _Tasks();
    final PermissionFixture fixture = PermissionFixture(
      overrides: [
        sensitivePrefsStoreProvider.overrideWithValue(MemoryPrefs()),
        domainTaskRepositoryProvider.overrideWithValue(tasks),
        domainGoalRepositoryProvider.overrideWithValue(const _Goals()),
        domainHabitRepositoryProvider.overrideWithValue(const _Habits()),
        domainNoteRepositoryProvider.overrideWithValue(const _Notes()),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        creatorHandshakeClockProvider.overrideWithValue(
          () => at.subtract(const Duration(days: 1)),
        ),
        accountOnboardingCompleteProvider.overrideWith(_SetupDone.new),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(
            const User(id: 'a', email: 'a@example.test', emailVerified: true),
          ),
        ),
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        dailyDecisionIntelligenceProvider.overrideWith((Ref ref) => _decision),
      ],
    );
    // Task reminders are on unless the person turns them off.
    fixture.actions.reminderPrefs = const ReminderOrchestratorPrefs(
      goalRemindersEnabled: true,
      habitRemindersEnabled: true,
      dailyPlanningEnabled: true,
      dailyPlanningHour: 7,
      dailyPlanningMinute: 30,
      taskRemindersEnabled: true,
    );
    final ProviderContainer container = fixture.container;
    final AdaptiveGuidanceState guide = await container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(guide.guidesCreatorTask, isTrue);
    await container
        .read(creatorHandshakeProvider.notifier)
        .stage(
          data: CreatorFormData(
            title: 'First scheduled task',
            type: 'Task',
            priority: 4,
            scheduledFor: at,
          ),
        );
    container.read(creatorTutorialDraftProvider.notifier)
      ..setHasTitle(true)
      ..markPriorityChosen()
      ..setHasSchedule(true);
    return (fixture, tasks);
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> answer(
    WidgetTester tester,
    PermissionFixture fixture, {
    required bool allow,
  }) async {
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
    await tester.tap(
      allow
          ? find.widgetWithText(FilledButton, 'Allow Notifications')
          : find.text('Not Now'),
    );
    await settle(tester);
    expect(fixture.actions.requests, allow ? 1 : 0);
  }

  for (final bool allow in <bool>[true, false]) {
    final String answered = allow ? 'allowed' : 'declined';

    testWidgets("Add something's own confirm button asks after saving, then "
        'opens My plan ($answered)', (WidgetTester tester) async {
      final (PermissionFixture fixture, _Tasks tasks) = await stageGuidedTask(
        tester,
      );
      await tester.pumpWidget(fixture.app(const CreatorScreen()));
      await settle(tester);
      final Finder confirm = find.byKey(const Key('creator-confirm-selected'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await settle(tester);

      // Saved first, then asked.
      expect(tasks.saveCalls, 1);
      await answer(tester, fixture, allow: allow);
      expect(fixture.container.read(appFlowProvider), AppView.timeline);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('"Confirm and open My plan" on the guide card asks after '
        'saving, then opens My plan ($answered)', (WidgetTester tester) async {
      final (PermissionFixture fixture, _Tasks tasks) = await stageGuidedTask(
        tester,
      );
      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.creator,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.creator,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('Add something page'))),
          ),
          GoRoute(
            path: RoutePaths.timeline,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('My plan page'))),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp.router(
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              ChronoSparkLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
            builder: (BuildContext context, Widget? child) => Stack(
              children: <Widget>[
                Positioned.fill(child: child ?? const SizedBox.shrink()),
                ListenableBuilder(
                  listenable: router.routerDelegate,
                  builder: (BuildContext context, Widget? _) =>
                      AdaptiveGuideOverlay(
                        key: ValueKey<String>(
                          router.routerDelegate.state.uri.path,
                        ),
                        router: router,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
      await fixture.container.read(authUserProvider.future);
      await settle(tester);
      await tester.tap(find.text('Confirm and open My plan'));
      await settle(tester);

      expect(tasks.saveCalls, 1);
      await answer(tester, fixture, allow: allow);
      expect(router.routerDelegate.state.uri.path, RoutePaths.timeline);
      expect(find.text('My plan page'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _SetupDone extends AccountOnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'a',
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
