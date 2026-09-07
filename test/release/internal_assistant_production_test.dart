import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Synthetic identities only. This proves production provider semantics, not
// enrollment of a real Play tester or an installed production binary.
final AccountStorageScope _member = AccountStorageScope.authenticated(
  'synthetic-internal-account',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('compile-time production profile does not introduce a QA exception', () {
    expect(
      Env.isProduction,
      kReleaseMode &&
          const String.fromEnvironment(
                'CHRONOSPARK_APP_FLAVOR',
                defaultValue: 'prod',
              ) ==
              'prod',
    );
    expect(Env.isMockMode, isFalse);
    expect(Env.isMockLoginEnabled, isFalse);
    expect(Env.hasTesterFullAccess, isFalse);
    expect(
      Env.enableRuntimeFeatureFlags,
      const bool.fromEnvironment(
        'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
        defaultValue: true,
      ),
    );
  });

  test(
    'bundled internal policy returns both real local response contracts',
    () async {
      final ProviderContainer container = _container(scope: _member);
      addTearDown(container.dispose);
      final IntelligenceState intelligence = container.read(
        intelligenceStateProvider,
      );
      expect(intelligence.environment.isProduction, isTrue);
      expect(intelligence.flags.testerFullAccess, isFalse);
      expect(intelligence.flags.mockMode, isFalse);
      expect(intelligence.flags.mockLoginEnabled, isFalse);
      expect(LaunchContainment.externalAiEnabled, isFalse);
      expect(LaunchContainment.subscriptionsEnabled, isFalse);
      expect(LaunchContainment.cloudSyncEnabled, isFalse);
      expect(
        await container.read(smartPlannerAvailabilityProvider.future),
        isTrue,
      );
      expect(await container.read(siV2AvailabilityProvider.future), isTrue);

      final SmartPlannerResult planner = await _plan(container);
      expect(planner.processingMode, AIProcessingMode.onDevice);
      expect(planner.plannerResponse.whatIHeard, contains('release checklist'));
      expect(planner.plannerResponse.nextStep, isNotEmpty);
      planner.response.validateAgainst(planner.request);

      final SIV2Response console = await _query(container);
      console.validate();
      expect(console.evidenceLinks, isNotEmpty);
      expect(console.toPlainText(), isNotEmpty);
      expect(
        (await container.read(
          assistantReleaseDecisionProvider(
            AssistantReleaseCapability.governedMemory,
          ).future,
        )).enabled,
        isTrue,
      );
      expect(
        (await container.read(
          assistantReleaseDecisionProvider(
            AssistantReleaseCapability.plannerExplanation,
          ).future,
        )).enabled,
        isFalse,
      );
    },
  );

  for (final MapEntry<String, AccountStorageScope> item
      in <String, AccountStorageScope>{
        'signed out': const AccountStorageScope.signedOut(),
        'unsafe transition': const AccountStorageScope.unsafe(),
        'other account': AccountStorageScope.authenticated(
          'synthetic-other-account',
        ),
      }.entries) {
    test('${item.key} cannot execute either internal local response', () async {
      final ProviderContainer container = _container(scope: item.value);
      addTearDown(container.dispose);
      expect(
        await container.read(smartPlannerAvailabilityProvider.future),
        isFalse,
      );
      expect(await container.read(siV2AvailabilityProvider.future), isFalse);
      await expectLater(
        _plan(container),
        throwsA(isA<AssistantReleaseBlockedException>()),
      );
      await expectLater(
        _query(container),
        throwsA(isA<AssistantReleaseBlockedException>()),
      );
    });
  }

  test(
    'signed-out and unsafe identities stay fenced even when explicitly allowlisted',
    () async {
      for (final AccountStorageScope scope in <AccountStorageScope>[
        const AccountStorageScope.signedOut(),
        const AccountStorageScope.unsafe(),
      ]) {
        final ProviderContainer container = _container(
          scope: scope,
          changes: <String, Object?>{
            'assistant_release_internal_account_digests':
                assistantReleaseAccountDigest(scope.v2Namespace ?? 'v2.unsafe'),
          },
        );
        addTearDown(container.dispose);
        final AssistantReleaseDecision decision = await container.read(
          assistantReleaseDecisionProvider(
            AssistantReleaseCapability.siConsoleV2,
          ).future,
        );
        expect(decision.enabled, isFalse);
        expect(decision.reasonCode, 'authenticated_account_required');
      }
    },
  );

  test(
    'required safety rollback blocks both real local request paths',
    () async {
      final ProviderContainer container = _container(
        scope: _member,
        changes: const <String, Object?>{'kill_assistant_safety_critic': true},
      );
      addTearDown(container.dispose);
      expect(
        await container.read(smartPlannerAvailabilityProvider.future),
        isFalse,
      );
      expect(await container.read(siV2AvailabilityProvider.future), isFalse);
      await expectLater(
        _plan(container),
        throwsA(isA<AssistantReleaseBlockedException>()),
      );
      await expectLater(
        _query(container),
        throwsA(isA<AssistantReleaseBlockedException>()),
      );
    },
  );

  test(
    'empty tracked policy cannot enable an account without verified cohort input',
    () async {
      final ProviderContainer container = _container(
        scope: _member,
        changes: const <String, Object?>{
          'assistant_release_internal_account_digests': '',
        },
      );
      addTearDown(container.dispose);
      expect(
        await container.read(smartPlannerAvailabilityProvider.future),
        isFalse,
      );
      expect(await container.read(siV2AvailabilityProvider.future), isFalse);
    },
  );
}

Future<SmartPlannerResult> _plan(ProviderContainer container) => container
    .read(smartPlannerQueryControllerProvider)
    .requestPlanningGuidance(
      energy: 0.6,
      emotion: EmotionalState.calm,
      notes: 'Help me finish the release checklist.',
      history: const <Map<String, String>>[],
      previousSavedNotes: null,
    );

Future<SIV2Response> _query(ProviderContainer container) => container
    .read(siV2QueryServiceProvider)
    .analyze(
      SIV2Query(
        rawText: 'What should I do next?',
        intent: SIV2Intent.answer,
        sources: <SIV2Source>{SIV2Source.tasks},
        timeRange: SIV2TimeRange.thirtyDays,
      ),
    );

ProviderContainer _container({
  required AccountStorageScope scope,
  Map<String, Object?> changes = const <String, Object?>{},
}) {
  final Map<String, Object?> policy =
      (jsonDecode(
                File(
                  'tool/internal_testing_assistant_release.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)
          .cast<String, Object?>()
        ..['assistant_release_internal_account_digests'] =
            assistantReleaseAccountDigest(_member.v2Namespace!)
        ..addAll(changes);
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(scope),
      remoteConfigServiceProvider.overrideWithValue(
        RemoteConfigService(initialValues: policy),
      ),
      intelligenceStateProvider.overrideWith(
        (Ref ref) => const IntelligenceState(
          environment: EnvironmentState(
            appName: 'ChronoSpark',
            appFlavor: 'prod',
            isProduction: true,
            isSupabaseConfigured: true,
          ),
          flags: FeatureFlagsState(
            verboseLogs: false,
            analyticsEnabled: false,
            mockMode: false,
            mockLoginEnabled: false,
            paywallDisabled: false,
            testerFullAccess: false,
          ),
          auth: AuthStateSnapshot(
            hasMockSignIn: false,
            hasAuthenticatedUser: true,
          ),
          mockLogin: MockLoginConfigState(email: '', password: ''),
        ),
      ),
      domainTaskRepositoryProvider.overrideWithValue(_EmptyTasks()),
      domainGoalRepositoryProvider.overrideWithValue(_EmptyGoals()),
      smartPlannerOperatingReceiptProvider.overrideWithValue(null),
      memoryRecallProvider(
        MemorySurface.smartPlanner,
      ).overrideWithValue(const <MemoryEntity>[]),
      siV2ReadGatewayProvider.overrideWithValue(
        SIV2ReadGateway(
          accountScopeId: scope.v2Namespace ?? 'v2.unsafe',
          readTasks: () async => const <TaskEntity>[],
          readGoals: () async => const <GoalEntity>[],
          readMilestones: () async => [],
          readTimeline: () async => [],
        ),
      ),
      operatingDecisionForSurfaceProvider(
        OperatingDecisionSurface.siConsole,
      ).overrideWith(
        (Ref ref) async =>
            throw StateError('No shared decision in this evidence fixture'),
      ),
    ],
  );
}

class _EmptyTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyGoals implements IGoalRepository {
  @override
  List<GoalEntity> getGoals() => const <GoalEntity>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
