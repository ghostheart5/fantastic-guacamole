import 'dart:io';

import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:hive/hive.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveRoot;
  setUpAll(() async {
    hiveRoot = await Directory.systemTemp.createTemp(
      'axiomara-auth-integration-',
    );
    Hive.init(hiveRoot.path);
  });
  tearDownAll(() async {
    await Hive.close();
    final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final resolved = await hiveRoot.resolveSymbolicLinks();
    if (!resolved.startsWith('$tempRoot${Platform.pathSeparator}') ||
        !hiveRoot.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last
            .startsWith('axiomara-auth-integration-')) {
      throw StateError('Refusing to remove an unexpected test storage path.');
    }
    await hiveRoot.delete(recursive: true);
  });
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  testWidgets('auth screen exposes forgot password action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AuthGate(
            authService: _IntegrationFakeAuthService(),
            child: const Text('APP_READY'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('QA tester access enters the app without backend access', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('mock-user'),
          ),
        ],
        child: MaterialApp(
          home: AuthGate(
            authService: _IntegrationFakeAuthService(),
            enableMockLogin: true,
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Mock login:'), findsNothing);
    final Finder testerAccess = find.byKey(
      const ValueKey<String>('qa-tester-access-button'),
    );
    expect(testerAccess, findsOneWidget);
    await tester.ensureVisible(testerAccess);
    await tester.pump(const Duration(milliseconds: 800));
    expect(testerAccess.hitTestable(), findsOneWidget);
    await _tapRequired(tester, testerAccess);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('APP_READY'), findsOneWidget);
  });

  testWidgets('onboarding persists and stages the first helpful choice', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(_IntegrationProfileController.new),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('integration-onboarding-user'),
        ),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        intelligenceStateProvider.overrideWithValue(_authenticatedIntelligence),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('onboarding-brand-title')), findsOneWidget);
    expect(find.text('SKIP'), findsNothing);
    expect(find.text('CONTINUE TO LOGIN'), findsNothing);
    expect(find.text('CONTINUE TO PROFILE'), findsNothing);
    await _tapRequired(tester, find.text('CONTINUE TO SETUP'));
    await tester.pump(const Duration(milliseconds: 400));

    final Finder firstValueQuestion = find.byKey(
      const Key('first-value-question'),
    );
    expect(firstValueQuestion, findsOneWidget);
    await tester.ensureVisible(firstValueQuestion);
    await tester.pump();
    await tester.enterText(
      firstValueQuestion,
      'I need one realistic next step.',
    );
    await tester.pump();
    final Finder completeButton = find.byKey(
      const Key('first-value-show-choice'),
    );
    expect(completeButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(completeButton).onPressed,
      isNotNull,
      reason:
          'The first-value page must remain actionable after optional input.',
    );
    await _hideKeyboard(tester);
    await _tapRequired(tester, completeButton);
    await _waitForPreference(
      tester,
      key: onboardingCompleteStorageKey,
      expected: true,
    );
    await tester.pump();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isTrue);
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
    final SmartPlannerFirstValueRequest? request = container.read(
      smartPlannerFirstValueProvider,
    );
    expect(request, isNotNull);
    expect(request!.prompt, 'I need one realistic next step.');
    expect(
      request.accountScopeId,
      container.read(accountStorageScopeProvider).v2Namespace,
    );
  });

  testWidgets(
    'planner pipeline accepts context and returns a usable response',
    (WidgetTester tester) async {
      const AgentOrchestrator orchestrator = AgentOrchestrator();
      final AgentResult result = await orchestrator.execute(
        prompt: 'I keep losing attention after lunch. What should I do next?',
        preferredAgent: AgentKind.chat,
        request: AgentRequest(
          prompt: 'I keep losing attention after lunch. What should I do next?',
          context: <String, dynamic>{
            'surface': 'smart_planner',
            'energy': 0.45,
          },
          history: <Map<String, String>>[
            <String, String>{
              'role': 'assistant',
              'content': 'Choose one small task and begin.',
            },
            <String, String>{
              'role': 'user',
              'content': 'That advice is too generic for my afternoon slump.',
            },
          ],
          si: const SIState(energy: 0.45),
          learning: const LearningState(),
        ),
      );

      expect(result.selectedAgent, AgentKind.chat.name);
      expect(result.payload['message']?.toString().trim(), isNotEmpty);
      expect(
        result.payload['message'],
        isNot('Choose one small task and begin.'),
      );
    },
  );

  testWidgets('task journey creates and persists a task', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
    await SharedPrefsService.clear();

    final _InMemoryTaskRepository repository = _InMemoryTaskRepository();
    final ProviderContainer container = _integrationContainer(repository);
    addTearDown(container.dispose);

    await container
        .read(creatorActionsProvider)
        .createTask(
          const CreatorFormData(
            title: 'Ship tester journey',
            description: 'Verify the connected task and execution pipeline.',
            type: 'Task',
            priority: 5,
          ),
        );

    final List<TaskEntity> persisted = await repository.getAllTasks();
    expect(persisted, hasLength(1));
    expect(persisted.single.isCompleted, isFalse);
    expect(persisted.single.priority, 5);

    final tasks = await container.read(tasksProvider.future);
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Ship tester journey');

    expect(await container.read(tasksProvider.future), hasLength(1));

    final Map<String, dynamic> metrics = await _waitForMetric(
      tester,
      container,
      key: 'tasks_created',
      expected: 1,
    );
    expect(metrics['tasks_created'], 1);
    expect(metrics['tasks_completed'], 0);
  });

  testWidgets(
    'screen journey saves a task, completes it, and reads its history',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPrefsService.init();
      await SharedPrefsService.clear();
      final _InMemoryTaskRepository repository = _InMemoryTaskRepository();
      final ProviderContainer container = _integrationContainer(repository);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });
      final GoRouter router = container.read(appRouterProvider);
      router.go(RoutePaths.nexus);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('today-add')), findsOneWidget);
      await _tapRequired(tester, find.byKey(const Key('today-add')));
      await tester.pump(const Duration(milliseconds: 250));
      await _tapRequired(tester, find.byKey(const Key('today-add-task')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.creator,
      );
      expect(find.byType(CreatorScreen), findsOneWidget);

      final Finder titleField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField && widget.decoration?.hintText == 'Title *',
      );
      await tester.enterText(titleField, 'UI journey task');
      await tester.pump();
      expect(find.byKey(const Key('creator-type-selector')), findsOneWidget);
      await _hideKeyboard(tester);
      await _tapRequired(tester, find.byKey(const Key('creator-task-options')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _tapRequired(tester, find.bySemanticsLabel('Set priority level 4'));
      final Finder scheduleControl = find.text('Schedule date and time...');
      await tester.ensureVisible(scheduleControl);
      await _tapRequired(tester, scheduleControl);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final Finder datePickerOk = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'OK'),
      );
      expect(datePickerOk.hitTestable(), findsOneWidget);
      await _tapRequired(tester, datePickerOk);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final Finder timePickerOk = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.widgetWithText(TextButton, 'OK'),
      );
      expect(timePickerOk.hitTestable(), findsOneWidget);
      await _tapRequired(tester, timePickerOk);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Schedule date and time...'), findsNothing);
      await _hideKeyboard(tester);

      final int xpBeforeCompletion = container.read(profileProvider).xp;
      final Finder saveButton = find.text('Save task');
      await tester.ensureVisible(saveButton);
      await tester.pump(const Duration(milliseconds: 200));
      await _tapRequired(tester, saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _waitForVisible(
        tester,
        find.byKey(const Key('creator-handshake-result')),
      );
      expect(
        find.byKey(const Key('creator-handshake-result')),
        findsOneWidget,
        reason:
            'Save phase: ${container.read(creatorHandshakeProvider).phase}; '
            '${container.read(creatorHandshakeProvider).message}; '
            'form: ${find.byKey(const Key('creator-form-error')).evaluate().map((element) => (element.widget as Text).data).toList()}',
      );
      expect(find.byKey(const Key('creator-confirm-selected')), findsNothing);
      final List<TaskEntity> persisted = (await repository.getAllTasks())
          .where((TaskEntity task) => task.title == 'UI journey task')
          .toList();
      expect(persisted, hasLength(1));
      expect(persisted.single.priority, 4);
      expect(persisted.single.scheduledFor, isNotNull);
      expect(persisted.single.isCompleted, isFalse);
      final tasks = await container.read(tasksProvider.future);
      expect(
        tasks.where((task) => task.title == 'UI journey task'),
        isNotEmpty,
      );
      final Map<String, dynamic> metrics = await _waitForMetric(
        tester,
        container,
        key: 'tasks_created',
        expected: 1,
      );
      expect(metrics['tasks_created'], 1);
      expect(container.read(profileProvider).xp, xpBeforeCompletion);

      await _tapRequired(
        tester,
        find.byKey(const Key('creator-open-saved-result')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.text('UI journey task'), findsOneWidget);
      await _tapRequired(tester, find.text('Complete'));
      await tester.pump(const Duration(milliseconds: 600));
      final Map<String, dynamic> completedMetrics = await _waitForMetric(
        tester,
        container,
        key: 'tasks_completed',
        expected: 1,
      );
      expect(completedMetrics['tasks_completed'], 1);
      final TaskEntity completed = (await repository.getAllTasks()).singleWhere(
        (task) => task.title == 'UI journey task',
      );
      expect(completed.isCompleted, isTrue);
      expect(completed.priority, 4);
      expect(completed.scheduledFor, persisted.single.scheduledFor);
      expect(
        container.read(profileProvider).xp,
        greaterThan(xpBeforeCompletion),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _tapRequired(tester, find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TimelineScreen), findsNothing);
      expect(find.byType(CreatorScreen), findsOneWidget);
      expect(find.byKey(const Key('creator-handshake-result')), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.creator,
      );
      await _tapRequired(tester, find.bySemanticsLabel('Back to Today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _waitForRouterPath(tester, router, RoutePaths.nexus);
      await _waitForVisible(tester, find.byKey(const Key('today-add')));
      expect(
        find.byKey(const Key('today-add')),
        findsOneWidget,
        reason:
            'Home navigation must show Today; remaining schedule screens: '
            '${find.byType(TimelineScreen).evaluate().length}.',
      );
      await _tapRequired(tester, find.byTooltip('My plan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _waitForRouterPath(tester, router, RoutePaths.timeline);
      await _tapRequired(tester, find.text('Completed'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('UI journey task'), findsOneWidget);
      expect(find.byTooltip('Complete task'), findsNothing);
    },
  );
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _waitForVisible(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 100 && target.evaluate().isEmpty; attempt++) {
    // Allow bounded repository/platform work to settle as well as UI frames.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> _tapRequired(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 250));
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason:
        'A required interaction must be reachable before tapping: ${tester.getRect(target)}.',
  );
  await tester.tap(target);
}

ProviderContainer _integrationContainer(_InMemoryTaskRepository repository) {
  final container = ProviderContainer(
    overrides: [
      domainTaskRepositoryProvider.overrideWithValue(repository),
      hiveStoreProvider.overrideWithValue(const _IntegrationHiveStore()),
      domainGoalRepositoryProvider.overrideWithValue(const _UnchangedGoals()),
      domainHabitRepositoryProvider.overrideWithValue(const _UnchangedHabits()),
      domainNoteRepositoryProvider.overrideWithValue(const _UnchangedNotes()),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      networkInterfaceAvailabilityProvider.overrideWithValue(
        NetworkInterfaceAvailability.available,
      ),
      profileProvider.overrideWith(_IntegrationProfileController.new),
      audioFeedbackControllerProvider.overrideWithValue(
        const _SilentAudioFeedbackController(),
      ),
      soundEnabledProvider.overrideWith(_SilentSound.new),
      optimizationConfigProvider.overrideWith(
        (Ref ref) async => OptimizationConfig.neutral(),
      ),
      aiResponseProvider.overrideWith(_IntegrationAIResponseController.new),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('integration-task-user'),
      ),
      guards.authenticatedGuardProvider.overrideWithValue(true),
      guards.onboardingWelcomeCompleteGuardProvider.overrideWithValue(true),
      guards.onboardingCompleteGuardProvider.overrideWithValue(true),
    ],
  );
  // These screen fixtures mount the router below AuthGate. Establish the same
  // ready account boundary that AuthGate normally supplies before actions run.
  final boundary = container.read(authSessionBoundaryProvider.notifier);
  final generation = boundary.begin(
    userId: 'integration-task-user',
    isTransitioning: false,
  );
  boundary.complete(generation, storageReady: true);
  return container;
}

Future<Map<String, dynamic>> _waitForMetric(
  WidgetTester tester,
  ProviderContainer container, {
  required String key,
  required int expected,
}) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  Map<String, dynamic> snapshot = <String, dynamic>{};
  do {
    snapshot = await container.read(localMetricsAccumulatorProvider).snapshot();
    if (snapshot[key] == expected) {
      return snapshot;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  } while (DateTime.now().isBefore(deadline));
  return snapshot;
}

Future<void> _waitForPreference(
  WidgetTester tester, {
  required String key,
  required Object expected,
}) async {
  final bool completed =
      await tester.runAsync<bool>(() async {
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 15),
        );
        do {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          if (prefs.get(key) == expected) {
            return true;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        } while (DateTime.now().isBefore(deadline));
        return false;
      }) ??
      false;
  expect(completed, isTrue, reason: 'Timed out waiting for $key to persist.');
}

Future<void> _waitForRouterPath(
  WidgetTester tester,
  GoRouter router,
  String expectedPath,
) async {
  final bool reached =
      await tester.runAsync<bool>(() async {
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 15),
        );
        do {
          if (router.routeInformationProvider.value.uri.path == expectedPath) {
            return true;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        } while (DateTime.now().isBefore(deadline));
        return false;
      }) ??
      false;
  expect(
    reached,
    isTrue,
    reason: 'Timed out waiting for router path $expectedPath.',
  );
}

const IntelligenceState _authenticatedIntelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'integration',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: true,
    mockLoginEnabled: true,
    paywallDisabled: true,
    testerFullAccess: true,
  ),
  auth: AuthStateSnapshot(hasMockSignIn: true, hasAuthenticatedUser: true),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

class _SilentSound extends SoundEnabledNotifier {
  @override
  bool build() => false;
}

class _SilentAudioFeedbackController extends AudioFeedbackController {
  const _SilentAudioFeedbackController();

  @override
  Future<void> playDecision() => Future<void>.value();

  @override
  Future<void> playTaskComplete() => Future<void>.value();
}

// Creator reads all domains to bind its save transaction. Keep unrelated
// domains synthetic and fail if a task journey tries to mutate any of them.
class _IntegrationHiveStore implements HiveStore {
  const _IntegrationHiveStore();
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      Hive.isBoxOpen(key) ? Hive.box<T>(key) : await Hive.openBox<T>(key);
  @override
  Future<void> clearBox(String key) async =>
      (await openBox<dynamic>(key)).clear();
  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}

class _UnchangedGoals implements IGoalRepository {
  const _UnchangedGoals();
  @override
  List<GoalEntity> getGoals() => const [];
  @override
  Future<void> deleteGoal(String id) =>
      throw StateError('Unexpected goal mutation');
  @override
  Future<void> saveGoal(GoalEntity goal) =>
      throw StateError('Unexpected goal mutation');
  @override
  Future<void> saveGoals(List<GoalEntity> goals) =>
      throw StateError('Unexpected goal mutation');
}

class _UnchangedHabits implements IHabitRepository {
  const _UnchangedHabits();
  @override
  Future<List<HabitEntity>> getHabits() async => const [];
  @override
  Future<void> saveHabits(List<HabitEntity> habits) =>
      throw StateError('Unexpected habit mutation');
}

class _UnchangedNotes implements INoteRepository {
  const _UnchangedNotes();
  @override
  Future<List<NoteEntity>> getNotes() async => const [];
  @override
  Future<void> deleteNote(String id) =>
      throw StateError('Unexpected note mutation');
  @override
  Future<void> saveNote(NoteEntity note) =>
      throw StateError('Unexpected note mutation');
}

class _InMemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async => _tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}

class _IntegrationProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> addXP(int amount) async {
    final int newXP = state.xp + amount;
    state = state.copyWith(
      xp: newXP,
      level: (newXP ~/ 50) + 1,
      leveledUp: (newXP ~/ 50) + 1 > state.level,
      streak: state.streak + 1,
      longestStreak: state.streak + 1,
      lastActiveDate: DateTime.now(),
    );
  }

  @override
  void clearLeveledUp() {
    state = state.copyWith(leveledUp: false);
  }
}

class _IntegrationAIResponseController extends AIResponseController {
  @override
  Future<AIRecommendation?> build() async => null;

  @override
  Future<AIRecommendation?> execute({
    String? inputOverride,
    AIPersonality? personalityOverride,
    AgentKind? preferredAgent,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
    AgentRequest? requestOverride,
  }) async {
    const AIRecommendation recommendation = AIRecommendation(
      task: null,
      message: 'Task complete. Continue with the next ranked action.',
      reasoning: 'Integration response',
      emotion: 'engaged',
      confidence: 0.9,
    );
    state = const AsyncData<AIRecommendation?>(recommendation);
    return recommendation;
  }
}

class _IntegrationFakeAuthService implements AuthServiceContract {
  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<AccountDeletionResult> deleteCurrentAccount({
    required String password,
  }) async => const AccountDeletionResult.completed();

  @override
  Future<PendingAccountDeletionStatus?> readPendingAccountDeletion() async =>
      null;

  @override
  Future<AccountDeletionResult?> refreshPendingAccountDeletion() async => null;

  @override
  Future<void> forgetPendingAccountDeletion() async {}

  @override
  Future<User?> reloadCurrentUser() async => null;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> signInWithGoogle() {
    throw UnimplementedError('Not used by this integration test');
  }

  @override
  Future<UserCredential> signInWithGitHub() {
    throw UnimplementedError('Not used by this integration test');
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('Not used by this integration test');
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('Not used by this integration test');
  }
}
