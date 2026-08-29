import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
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
    await tester.pump();
    await tester.tap(testerAccess);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('APP_READY'), findsOneWidget);
  });

  testWidgets('two-page onboarding persists welcome and profile completion', (
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

    expect(find.text('CHRONOSPARK'), findsOneWidget);
    expect(find.text('SKIP'), findsNothing);
    await tester.tap(find.text('Continue to login'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Integration User');
    await tester.pump();
    final Finder completeButton = find.widgetWithText(
      FilledButton,
      'Continue to Creator',
    );
    expect(
      tester.widget<FilledButton>(completeButton).onPressed,
      isNotNull,
      reason: 'The second onboarding page must become actionable after input.',
    );
    await tester.tap(completeButton);
    await _waitForPreference(
      tester,
      key: onboardingCompleteStorageKey,
      expected: true,
    );
    await tester.pump();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isTrue);
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
    expect(container.read(profileProvider).name, 'Integration User');
  });

  test(
    'planner pipeline accepts context and returns a usable response',
    () async {
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

  test('task journey creates and persists a task', () async {
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

    final tasks = await container.read(tasksProvider.future);
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Ship tester journey');

    expect(await container.read(tasksProvider.future), hasLength(1));

    final Map<String, dynamic> metrics = await _waitForMetric(
      container,
      key: 'tasks_created',
      expected: 1,
    );
    expect(metrics['tasks_created'], 1);
    expect(metrics['tasks_completed'], 0);
  });

  testWidgets('screen journey reviews, creates, and routes to Timeline', (
    WidgetTester tester,
  ) async {
    await SharedPrefsService.clear();
    final _InMemoryTaskRepository repository = _InMemoryTaskRepository();
    final ProviderContainer container = _integrationContainer(repository);
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

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump(const Duration(milliseconds: 250));
    final Finder creatorButton = find.text('Creator');
    await tester.tap(creatorButton);
    await tester.pump(const Duration(milliseconds: 600));
    expect(router.routeInformationProvider.value.uri.path, RoutePaths.creator);
    expect(find.byType(CreatorScreen), findsOneWidget);

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'UI journey task');
    await tester.tap(find.text('TASK'));
    await tester.tap(find.bySemanticsLabel('Set priority level 4'));
    final Finder scheduleControl = find.bySemanticsLabel('Schedule date');
    await tester.ensureVisible(scheduleControl);
    await tester.tap(scheduleControl);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Schedule date and time...'), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));

    final Finder reviewButton = find.text('REVIEW CHANGES');
    await tester.ensureVisible(reviewButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(reviewButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CONFIRM CREATOR CHANGES'), findsOneWidget);
    final Finder confirmButton = find.byKey(
      const Key('creator-confirm-selected'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pump();
    await _waitForRepositoryTask(tester, repository, title: 'UI journey task');

    final Finder openTimelineButton = find.text('Open Timeline');
    await tester.ensureVisible(openTimelineButton);
    await tester.tap(openTimelineButton);
    await tester.pump();
    await _waitForRouterPath(tester, router, RoutePaths.timeline);
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(appFlowProvider), AppView.timeline);
    final tasks = await container.read(tasksProvider.future);
    expect(tasks.where((task) => task.title == 'UI journey task'), isNotEmpty);
    final Map<String, dynamic> metrics = await _waitForMetric(
      container,
      key: 'tasks_created',
      expected: 1,
    );
    expect(metrics['tasks_created'], 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });
}

ProviderContainer _integrationContainer(_InMemoryTaskRepository repository) {
  return ProviderContainer(
    overrides: [
      domainTaskRepositoryProvider.overrideWithValue(repository),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      isOnlineProvider.overrideWithValue(true),
      profileProvider.overrideWith(_IntegrationProfileController.new),
      audioFeedbackControllerProvider.overrideWithValue(
        const _SilentAudioFeedbackController(),
      ),
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
}

Future<Map<String, dynamic>> _waitForMetric(
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
    await Future<void>.delayed(const Duration(milliseconds: 20));
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

Future<void> _waitForRepositoryTask(
  WidgetTester tester,
  _InMemoryTaskRepository repository, {
  required String title,
}) async {
  final bool persisted =
      await tester.runAsync<bool>(() async {
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 15),
        );
        do {
          final List<TaskEntity> tasks = await repository.getAllTasks();
          if (tasks.any((TaskEntity task) => task.title == title)) {
            return true;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        } while (DateTime.now().isBefore(deadline));
        return false;
      }) ??
      false;
  expect(
    persisted,
    isTrue,
    reason: 'Timed out waiting for Creator to persist "$title".',
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

class _SilentAudioFeedbackController extends AudioFeedbackController {
  const _SilentAudioFeedbackController();

  @override
  void playDecision() {}

  @override
  void playTaskComplete() {}
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
  Future<void> deleteCurrentAccount({required String password}) async {}

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
