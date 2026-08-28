import 'dart:async';

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/data/services/supabase_client_service.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FirebaseBootstrap.resetForTesting();
    SupabaseClientService.resetForTesting();
  });
  tearDown(() {
    FirebaseBootstrap.resetForTesting();
    SupabaseClientService.resetForTesting();
  });

  test('Future.timeout leaves the original startup future running', () async {
    final Completer<void> releaseStartup = Completer<void>();
    bool lateSideEffectRan = false;

    final Future<String> startup = () async {
      await releaseStartup.future;
      lateSideEffectRan = true;
      return 'late completion';
    }();

    final String result = await startup.timeout(
      Duration.zero,
      onTimeout: () => 'degraded fallback',
    );

    expect(result, 'degraded fallback');
    expect(lateSideEffectRan, isFalse);

    releaseStartup.complete();
    await startup;

    expect(lateSideEffectRan, isTrue);
  });

  test(
    'startup timeout cancels the source before returning fallback',
    () async {
      final Completer<void> releaseCurrentStage = Completer<void>();
      final Completer<void> sourceFinished = Completer<void>();
      final StartupCancellationToken cancellationToken =
          StartupCancellationToken();
      StartupCancellationToken? observedToken;
      bool laterStageStarted = false;

      final Future<String> resultFuture = runStartupWithTimeout<String>(
        initialize: (StartupCancellationToken token) async {
          observedToken = token;
          await releaseCurrentStage.future;
          if (!token.isCancelled) {
            laterStageStarted = true;
          }
          sourceFinished.complete();
          return 'late completion';
        },
        timeout: Duration.zero,
        onTimeout: () => 'degraded fallback',
        cancellationToken: cancellationToken,
      );

      expect(await resultFuture, 'degraded fallback');
      expect(observedToken, isNotNull);
      expect(observedToken!.isCancelled, isTrue);
      expect(cancellationToken.isSourceSettled, isFalse);

      releaseCurrentStage.complete();
      await sourceFinished.future;
      await cancellationToken.whenSourceSettled;

      expect(laterStageStarted, isFalse);
      expect(cancellationToken.isSourceSettled, isTrue);
    },
  );

  testWidgets('startup gate stays locked until timed-out source settles', (
    WidgetTester tester,
  ) async {
    final Completer<void> releaseStartup = Completer<void>();
    StartupCancellationToken? observedToken;

    await tester.pumpWidget(
      ProviderScope(
        child: StartupBootstrapGate(
          startupTimeout: const Duration(milliseconds: 1),
          initializeStartup:
              (WidgetRef _, StartupCancellationToken cancellationToken) async {
                observedToken = cancellationToken;
                await releaseStartup.future;
                return const StartupBootstrapResult(
                  hasOnboarded: false,
                  hasSeenWelcome: false,
                  startupError: null,
                  productionReadinessBlocked: false,
                );
              },
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    expect(find.text('Securing local state'), findsOneWidget);
    expect(observedToken, isNotNull);
    expect(observedToken!.isCancelled, isTrue);
    expect(observedToken!.isSourceSettled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    releaseStartup.complete();
    await tester.pump();
    await observedToken!.whenSourceSettled;

    expect(observedToken!.isSourceSettled, isTrue);
  });

  test(
    'startup completion preserves stage order without cancellation',
    () async {
      final List<String> stages = <String>[];
      StartupCancellationToken? observedToken;

      final String result = await runStartupWithTimeout<String>(
        initialize: (StartupCancellationToken token) async {
          observedToken = token;
          stages.add('storage');
          await Future<void>.value();
          stages.add('firebase');
          await Future<void>.value();
          stages.add('preferences');
          return 'ready';
        },
        timeout: const Duration(seconds: 1),
        onTimeout: () => 'degraded fallback',
      );

      expect(result, 'ready');
      expect(observedToken, isNotNull);
      expect(observedToken!.isCancelled, isFalse);
      expect(stages, <String>['storage', 'firebase', 'preferences']);
    },
  );

  test('cancelled storage sequence does not start another operation', () async {
    final StartupCancellationToken token = StartupCancellationToken();
    final Completer<void> releaseHive = Completer<void>();
    final List<String> operations = <String>[];

    final Future<void> sequence = runStartupStorageSequence(
      cancellationToken: token,
      initializeHive: () async {
        operations.add('hive');
        await releaseHive.future;
      },
      initializeSharedPreferences: () async {
        operations.add('shared_preferences');
      },
      initializeSensitivePreferences: () async {
        operations.add('sensitive_preferences');
      },
      runStorageMigration: () async {
        operations.add('migration');
      },
    );

    token.cancel();
    releaseHive.complete();
    await sequence;

    expect(operations, <String>['hive']);
  });

  test('storage sequence preserves production order when active', () async {
    final List<String> operations = <String>[];

    await runStartupStorageSequence(
      cancellationToken: StartupCancellationToken(),
      initializeHive: () async => operations.add('hive'),
      initializeSharedPreferences: () async =>
          operations.add('shared_preferences'),
      initializeSensitivePreferences: () async =>
          operations.add('sensitive_preferences'),
      runStorageMigration: () async => operations.add('migration'),
    );

    expect(operations, <String>[
      'hive',
      'shared_preferences',
      'sensitive_preferences',
      'migration',
    ]);
  });

  test('timed-out startup keeps the account boundary locked', () {
    expect(
      shouldInitializeAccountBoundary(
        productionReadinessBlocked: false,
        startupTimedOut: true,
        startupSourceSettled: false,
      ),
      isFalse,
    );
    expect(
      shouldInitializeAccountBoundary(
        productionReadinessBlocked: false,
        startupTimedOut: false,
        startupSourceSettled: false,
      ),
      isTrue,
    );
    expect(
      shouldInitializeAccountBoundary(
        productionReadinessBlocked: false,
        startupTimedOut: true,
        startupSourceSettled: true,
      ),
      isTrue,
    );
    expect(
      shouldInitializeAccountBoundary(
        productionReadinessBlocked: true,
        startupTimedOut: false,
        startupSourceSettled: true,
      ),
      isFalse,
    );
  });

  test(
    'cancelled Firebase caller does not poison later configuration',
    () async {
      final Completer<void> releaseCore = Completer<void>();
      int coreCalls = 0;
      int crashlyticsCalls = 0;
      bool firstCallerActive = true;
      final FirebaseBootstrap bootstrap = FirebaseBootstrap(
        initializeCore: () async {
          coreCalls += 1;
          await releaseCore.future;
          return null;
        },
        configureCrashlytics: () async {
          crashlyticsCalls += 1;
          return null;
        },
        supportsCrashlytics: true,
      );

      final Future<String?> firstCall = bootstrap.initialize(
        isMockMode: false,
        shouldContinue: () => firstCallerActive,
      );
      firstCallerActive = false;
      releaseCore.complete();

      expect(await firstCall, isNull);
      expect(coreCalls, 1);
      expect(crashlyticsCalls, 0);

      expect(
        await bootstrap.initialize(
          isMockMode: false,
          shouldContinue: () => true,
        ),
        isNull,
      );
      expect(coreCalls, 1);
      expect(crashlyticsCalls, 1);
    },
  );

  test('overlapping Firebase callers share core and configuration', () async {
    final Completer<void> releaseCore = Completer<void>();
    int coreCalls = 0;
    int crashlyticsCalls = 0;
    final FirebaseBootstrap bootstrap = FirebaseBootstrap(
      initializeCore: () async {
        coreCalls += 1;
        await releaseCore.future;
        return null;
      },
      configureCrashlytics: () async {
        crashlyticsCalls += 1;
        return null;
      },
      supportsCrashlytics: true,
    );

    final Future<String?> firstCall = bootstrap.initialize(
      isMockMode: false,
      shouldContinue: () => true,
    );
    final Future<String?> secondCall = bootstrap.initialize(
      isMockMode: false,
      shouldContinue: () => true,
    );
    releaseCore.complete();

    expect(
      await Future.wait<String?>(<Future<String?>>[firstCall, secondCall]),
      <String?>[null, null],
    );
    expect(coreCalls, 1);
    expect(crashlyticsCalls, 1);
  });

  test('Firebase retries a transient cached failure', () async {
    int coreCalls = 0;
    final FirebaseBootstrap bootstrap = FirebaseBootstrap(
      initializeCore: () async {
        coreCalls += 1;
        return coreCalls == 1 ? 'transient failure' : null;
      },
      configureCrashlytics: () async => null,
      supportsCrashlytics: false,
    );

    expect(await bootstrap.initialize(isMockMode: false), 'transient failure');
    expect(await bootstrap.initialize(isMockMode: false), isNull);
    expect(coreCalls, 2);
  });

  test(
    'onboarding replay migration finishes its fail-safe write pair',
    () async {
      final StartupCancellationToken token = StartupCancellationToken();
      final List<String> writes = <String>[];

      await persistOnboardingReplayRequired(
        markOnboardingIncomplete: () async {
          writes.add('incomplete');
          token.cancel();
        },
        storeContentVersion: () async {
          writes.add('content_version');
        },
      );

      expect(token.isCancelled, isTrue);
      expect(writes, <String>['incomplete', 'content_version']);
    },
  );

  test('Supabase initialization waits for the underlying operation', () async {
    final Completer<void> releaseInitialization = Completer<void>();
    bool completed = false;
    final SupabaseClientService service = SupabaseClientService(
      initializeClient: () async {
        await releaseInitialization.future;
        return null;
      },
      isConfigured: true,
    );

    final Future<String?> initialization = service.initialize(
      isMockMode: false,
    );
    unawaited(initialization.then((String? _) => completed = true));
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);

    releaseInitialization.complete();
    expect(await initialization, isNull);
    expect(completed, isTrue);
  });

  test('overlapping Supabase callers share initialization', () async {
    final Completer<void> releaseInitialization = Completer<void>();
    int calls = 0;
    final SupabaseClientService service = SupabaseClientService(
      initializeClient: () async {
        calls += 1;
        await releaseInitialization.future;
        return null;
      },
      isConfigured: true,
    );

    final Future<String?> firstCall = service.initialize(isMockMode: false);
    final Future<String?> secondCall = service.initialize(isMockMode: false);
    releaseInitialization.complete();

    expect(
      await Future.wait<String?>(<Future<String?>>[firstCall, secondCall]),
      <String?>[null, null],
    );
    expect(calls, 1);
  });

  test('Supabase retries a transient cached failure', () async {
    int calls = 0;
    final SupabaseClientService service = SupabaseClientService(
      initializeClient: () async {
        calls += 1;
        return calls == 1 ? 'transient failure' : null;
      },
      isConfigured: true,
    );

    expect(await service.initialize(isMockMode: false), 'transient failure');
    expect(await service.initialize(isMockMode: false), isNull);
    expect(calls, 2);
  });
}
