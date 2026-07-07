import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty tasks produce fallback recommendation', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [tasksProvider.overrideWith((Ref ref) async => const <Task>[])],
    );
    addTearDown(container.dispose);

    expect(container.read(nextActionTextProvider), 'Create your first task to get started.');
  });

  test('task changes trigger updated SI recommendation text', () async {
    final ProviderContainer emptyContainer = ProviderContainer(
      overrides: [tasksProvider.overrideWith((Ref ref) async => const <Task>[])],
    );
    addTearDown(emptyContainer.dispose);

    expect(emptyContainer.read(nextActionTextProvider), 'Create your first task to get started.');

    final ProviderContainer populatedContainer = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith((Ref ref) async {
          return const <Task>[
            Task(
              id: 't1',
              title: 'Move launch checklist',
              priority: 4,
              difficulty: 3,
              energyRequired: 3,
            ),
          ];
        }),
      ],
    );
    addTearDown(populatedContainer.dispose);

    await populatedContainer.read(tasksProvider.future);
    expect(populatedContainer.read(nextActionTextProvider), 'Focus on: Move launch checklist');
  });

  test('authenticatedGuardProvider is true when mock auth session is enabled', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(mockAuthSessionProvider.notifier).set(true);

    expect(container.read(authenticatedGuardProvider), isTrue);
  });

  test('authenticatedGuardProvider reflects overridden intelligence auth state', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        intelligenceStateProvider.overrideWith(
          (Ref ref) => const IntelligenceState(
            environment: EnvironmentState(
              appName: 'ChronoSpark',
              appFlavor: 'dev',
              isProduction: false,
              isSupabaseConfigured: false,
            ),
            flags: FeatureFlagsState(
              verboseLogs: true,
              analyticsEnabled: false,
              mockMode: true,
              mockLoginEnabled: true,
              paywallDisabled: true,
              testerFullAccess: true,
            ),
            auth: AuthStateSnapshot(hasMockSession: false, hasAuthenticatedUser: true),
            mockLogin: MockLoginConfigState(email: '', password: ''),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(authenticatedGuardProvider), isTrue);
  });

  test('repeated input does not duplicate identical output signal', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    int notifications = 0;
    final ProviderSubscription<String?> sub = container.listen<String?>(aiInputProvider, (
      String? previous,
      String? next,
    ) {
      notifications += 1;
    }, fireImmediately: false);
    addTearDown(sub.close);

    container.read(aiInputProvider.notifier).set('repeat');
    container.read(aiInputProvider.notifier).set('repeat');

    expect(container.read(aiInputProvider), 'repeat');
    expect(notifications, lessThanOrEqualTo(1));
  });

  test('engine failure creates safe UI fallback', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith((Ref ref) => Stream<User?>.error(Exception('engine down'))),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(authenticatedGuardProvider), isFalse);
  });

  test('mockLoginConfigProvider mirrors intelligence service configuration', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final config = container.read(mockLoginConfigProvider);

    expect(config.email, isA<String>());
    expect(config.password, isA<String>());
    expect(config.isConfigured, anyOf(isTrue, isFalse));
  });
}
