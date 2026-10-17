@Tags(['local-public-policy'])
library;

import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/public_release_profile.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/rhythm_planning_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'compiled policy admits real on-device first-choice request',
    () async {
      expect(Env.isLocalMode, isTrue);
      expect(Env.cloudServicesEnabled, isFalse);
      expect(Env.isMockMode, isFalse);
      expect(Env.isMockLoginEnabled, isFalse);
      expect(Env.hasTesterFullAccess, isFalse);
      expect(
        jsonDecode(Env.remoteConfigDefaultsJson),
        equals(PublicReleaseProfile.assistantPolicy),
      );
      final container = _container(
        AccountStorageScope.authenticated('synthetic-local-policy-account'),
      );
      addTearDown(container.dispose);
      final config = await container.read(
        assistantReleaseConfigProvider.future,
      );
      expect(config.configurationValid, isTrue);
      expect(config.stage, AssistantReleaseStage.general);
      expect(
        await container.read(smartPlannerAvailabilityProvider.future),
        isTrue,
      );
      expect(
        container.read(remoteConfigServiceProvider).snapshot(),
        equals(PublicReleaseProfile.assistantPolicy),
      );
      expect(
        container.read(personalizationProfileProvider).externalAiAllowed,
        isFalse,
      );
      final result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.2,
            emotion: null,
            notes:
                'I have five minutes and low capacity. Help me fold one shirt.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );
      expect(result.processingMode, AIProcessingMode.onDevice);
      expect(result.plannerResponse.nextStep.trim(), isNotEmpty);
      expect(
        result.plannerResponse.toAccessibleText().toLowerCase(),
        contains('shirt'),
      );
      result.response.validateAgainst(result.request);
      expect(
        (await container.read(
          assistantReleaseDecisionProvider(
            AssistantReleaseCapability.plannerExplanation,
          ).future,
        )).enabled,
        isFalse,
      );
    },
    tags: 'local-public-policy',
  );

  test(
    'compiled policy keeps unsafe account scope blocked',
    () async {
      final container = _container(const AccountStorageScope.unsafe());
      addTearDown(container.dispose);
      expect(
        await container.read(smartPlannerAvailabilityProvider.future),
        isFalse,
      );
      await expectLater(
        container
            .read(smartPlannerQueryControllerProvider)
            .requestPlanningGuidance(
              energy: 0.2,
              emotion: null,
              notes: 'Help me fold one shirt in five minutes.',
              history: const <Map<String, String>>[],
              previousSavedNotes: null,
            ),
        throwsA(isA<AssistantReleaseBlockedException>()),
      );
    },
    tags: 'local-public-policy',
  );
}

ProviderContainer _container(AccountStorageScope scope) => ProviderContainer(
  overrides: [
    accountStorageScopeProvider.overrideWithValue(scope),
    domainTaskRepositoryProvider.overrideWithValue(_EmptyTasks()),
    domainGoalRepositoryProvider.overrideWithValue(_EmptyGoals()),
    rhythmPlanningProvider.overrideWith((ref) async => const []),
    selectedPlanningNoteProvider.overrideWith((ref) async => null),
    smartPlannerOperatingReceiptProvider.overrideWithValue(null),
    memoryRecallProvider(
      MemorySurface.smartPlanner,
    ).overrideWithValue(const <MemoryEntity>[]),
    personalizationProfileProvider.overrideWith(_NoExternalAi.new),
    personContextForSurfaceProvider(
      PersonContextAccessRequest(
        surface: PersonContextSurface.smartPlanner,
        purposes: operationalPersonContextPurposes,
      ),
    ).overrideWithValue(null),
  ],
);

class _NoExternalAi extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() =>
      const PersonalizationProfile(externalAiAllowed: false);
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
