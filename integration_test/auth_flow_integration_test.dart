import 'package:fantastic_guacamole/app/navigation_shell.dart';
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
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auth screen exposes forgot password action', (WidgetTester tester) async {
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

  testWidgets('mock credentials enter the app without backend access', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AuthGate(
            authService: _IntegrationFakeAuthService(),
            enableMockLogin: true,
            mockLoginEmail: 'mock@chronospark.app',
            mockLoginPassword: 'ChronoSpark123!',
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Mock login:'), findsOneWidget);
    expect(find.textContaining('TESTER ACCESS'), findsNothing);
    final Finder emailField = find.descendant(
      of: find.byKey(const ValueKey('login-email-field')),
      matching: find.byType(TextField),
    );
    final Finder passwordField = find.descendant(
      of: find.byKey(const ValueKey('login-password-field')),
      matching: find.byType(TextField),
    );
    await tester.enterText(emailField, 'mock@chronospark.app');
    await tester.enterText(passwordField, 'ChronoSpark123!');
    await tester.tap(find.text('ENTER SYSTEM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('APP_READY'), findsOneWidget);
  });

  testWidgets('onboarding skip persists completion', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: OnboardingScreen())));
    await tester.pump();

    expect(find.text('CHRONOSPARK'), findsOneWidget);
    await tester.tap(find.text('SKIP'));
    await tester.pump(const Duration(milliseconds: 300));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
  });

  test('coach pipeline accepts context and returns a usable response', () async {
    const AgentOrchestrator orchestrator = AgentOrchestrator();
    final AgentResult result = await orchestrator.execute(
      prompt: 'I keep losing focus after lunch. What should I do next?',
      preferredAgent: AgentKind.chat,
      request: const AgentRequest(
        prompt: 'I keep losing focus after lunch. What should I do next?',
        context: <String, dynamic>{'surface': 'smart_coach', 'energy': 0.45},
        history: <Map<String, String>>[
          <String, String>{'role': 'assistant', 'content': 'Choose one small task and begin.'},
          <String, String>{
            'role': 'user',
            'content': 'That advice is too generic for my afternoon slump.',
          },
        ],
        si: SIState(energy: 0.45),
        learning: LearningState(),
      ),
    );

    expect(result.selectedAgent, AgentKind.chat.name);
    expect(result.payload['message']?.toString().trim(), isNotEmpty);
    expect(result.payload['message'], isNot('Choose one small task and begin.'));
  });

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
            description: 'Verify the connected task and focus pipeline.',
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

    final Map<String, dynamic> metrics = await container
        .read(localMetricsAccumulatorProvider)
        .snapshot();
    expect(metrics['tasks_created'], anyOf(isNull, 0, 1));
    expect(metrics['tasks_completed'], 0);
  });

  testWidgets('screen journey forges a task and routes to plan', (WidgetTester tester) async {
    await SharedPrefsService.clear();
    final ProviderContainer container = _integrationContainer(_InMemoryTaskRepository());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NavigationShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump(const Duration(milliseconds: 250));
    final Finder creatorButton = find.text('Creator');
    await tester.tap(creatorButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CREATOR'), findsOneWidget);

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) => widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'UI journey task');
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));

    final Finder forgeButton = find.text('FORGE TASK');
    await tester.ensureVisible(forgeButton);
    await tester.pump(const Duration(milliseconds: 200));
    final Finder forgeControl = find
        .ancestor(of: forgeButton, matching: find.byType(SmartPressable))
        .first;
    await tester.tap(forgeControl);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(appFlowProvider), AppView.plan);
    final tasks = await container.read(tasksProvider.future);
    expect(tasks.where((task) => task.title == 'UI journey task'), isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });
}

ProviderContainer _integrationContainer(_InMemoryTaskRepository repository) {
  return ProviderContainer(
    overrides: [
      domainTaskRepositoryProvider.overrideWithValue(repository),
      secureStoreProvider.overrideWithValue(SecureStore(backend: InMemorySecureStoreBackend())),
      profileProvider.overrideWith(_IntegrationProfileController.new),
      audioFeedbackControllerProvider.overrideWithValue(const _SilentAudioFeedbackController()),
      optimizationConfigProvider.overrideWith((Ref ref) async => OptimizationConfig.neutral()),
      aiResponseProvider.overrideWith(_IntegrationAIResponseController.new),
    ],
  );
}

class _SilentAudioFeedbackController extends AudioFeedbackController {
  const _SilentAudioFeedbackController();

  @override
  void playDecision() {}

  @override
  void playFocusStart() {}

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
  void addXP(int amount) {
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
      message: 'Session complete. Continue with the next ranked action.',
      reasoning: 'Integration response',
      emotion: 'focused',
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
  Future<AuthSessionSnapshot?> getCurrentSessionSnapshot({
    bool forceRefresh = false,
  }) async => null;

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
  Future<UserCredential> signIn({required String email, required String password}) {
    throw UnimplementedError('Not used by this integration test');
  }

  @override
  Future<UserCredential> signUp({required String email, required String password}) {
    throw UnimplementedError('Not used by this integration test');
  }
}
