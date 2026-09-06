import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Exercises the typed Planner handoff, confirmed task identity, real completion
/// action and outcome repository. The Planner option is a fixture; this does not
/// claim to test response generation, secure storage, or a process restart.
Future<void> verifyPlannerLearningIdentity({
  required Future<void> Function() reopenStorage,
}) async {
  final scope = AccountStorageScope.authenticated(
    'planner-learning-identity-a',
  );
  final secureStore = SecureStore(backend: InMemorySecureStoreBackend());
  ProviderContainer containerFor(AccountStorageScope account) =>
      ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(account),
          hiveStoreProvider.overrideWithValue(const IdentityHiveStore()),
          secureStoreProvider.overrideWithValue(secureStore),
          sensitivePrefsStoreProvider.overrideWithValue(
            const SharedPrefsStoreAdapter(),
          ),
          siStateProvider.overrideWith(_IdentitySiController.new),
          learningProvider.overrideWith(_IdentityLearningController.new),
          profileProvider.overrideWith(_IdentityProfileController.new),
        ],
      );

  final first = containerFor(scope);
  var firstDisposed = false;
  try {
    // An unrelated completed task deliberately makes a generic ledger assertion
    // pass before the Planner task exists. It must never satisfy the ID checks.
    await first.read(taskActionsProvider).createQuickTask('Unrelated seed');
    final seedId = (await first.read(tasksProvider.future)).single.id;
    await first.read(taskActionsProvider).completeTask(seedId, notify: false);
    final outcomeRepository = first.read(decisionOutcomeRepositoryProvider)!;
    final before = await outcomeRepository.load();
    expect(before.where((entry) => entry.subjectId == seedId), hasLength(1));

    final draft = CreatorDraftPreview.fromPlannerOption(
      const PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Planner identity persistence regression',
        description: 'Complete the reviewed ten minute task.',
        estimatedMinutes: 10,
        tradeoff: 'One bounded task before optional work.',
      ),
    );
    first.read(creatorDraftPreviewProvider.notifier).stage(draft);
    final handshake = first.read(creatorHandshakeProvider.notifier);
    final preview = await handshake.stage(
      data: CreatorFormData(
        title: draft.title,
        description: draft.description,
        type: 'Task',
        priority: 3,
        estimatedDuration: Duration(minutes: draft.estimatedMinutes),
      ),
      source: CreatorHandshakeSource.smartPlanner,
    );
    expect(preview.phase, CreatorHandshakePhase.preview);
    expect(preview.preview!.source, CreatorHandshakeSource.smartPlanner);
    expect(
      await first.read(tasksProvider.future),
      isEmpty,
      reason: 'A Planner preview must not silently create a task.',
    );
    expect(await outcomeRepository.load(), hasLength(before.length));

    final confirmed = await handshake.confirm();
    expect(confirmed.receipt, isNotNull, reason: confirmed.message);
    final taskId = confirmed.receipt!.taskIds.single;
    expect(taskId, isNot(seedId));
    final repository = first.read(domainTaskRepositoryProvider);
    final created = await repository.getTaskById(taskId);
    expect(created, isNotNull);
    expect(created!.title, draft.title);
    expect(created.isCompleted, isFalse);
    expect(
      (await outcomeRepository.load()).where(
        (entry) => entry.subjectId == taskId,
      ),
      isEmpty,
    );

    await first.read(taskActionsProvider).completeTask(taskId, notify: false);
    final completed = await repository.getTaskById(taskId);
    expect(completed!.isCompleted, isTrue);
    expect(completed.completedAt, isNotNull);
    final after = await outcomeRepository.load();
    expect(after, hasLength(before.length + 1));
    final exact = after.where((entry) => entry.subjectId == taskId).single;
    expect(exact.kind, DecisionOutcomeKind.completed);
    expect(exact.surface, 'task_lifecycle');
    expect(exact.completionResult, 'Completed the task.');
    expect(exact.recommendationHelped, isTrue);
    expect(exact.id, isNot(before.single.id));
    await outcomeRepository.drain();
    first.dispose();
    firstDisposed = true;

    // The caller closes and reopens Hive, and reloads preferences from its
    // backing store. No provider or repository from the first run is reused.
    await reopenStorage();
    final reopened = containerFor(scope);
    try {
      final restoredTask = await reopened
          .read(domainTaskRepositoryProvider)
          .getTaskById(taskId);
      expect(restoredTask!.isCompleted, isTrue);
      expect(restoredTask.title, draft.title);
      final restored = await reopened
          .read(decisionOutcomeRepositoryProvider)!
          .load();
      expect(restored, hasLength(before.length + 1));
      expect(
        restored.where((entry) => entry.subjectId == taskId).single.toJson(),
        exact.toJson(),
      );
      expect(
        restored.where((entry) => entry.subjectId == seedId),
        hasLength(1),
      );
    } finally {
      reopened.dispose();
    }

    final otherAccount = containerFor(
      AccountStorageScope.authenticated('planner-learning-identity-b'),
    );
    try {
      expect(
        await otherAccount.read(decisionOutcomeRepositoryProvider)!.load(),
        isEmpty,
      );
      expect(
        await otherAccount
            .read(domainTaskRepositoryProvider)
            .getTaskById(taskId),
        isNull,
      );
    } finally {
      otherAccount.dispose();
    }
  } finally {
    if (!firstDisposed) first.dispose();
  }
}

class IdentityHiveStore implements HiveStore {
  const IdentityHiveStore();
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      Hive.isBoxOpen(key) ? Hive.box<T>(key) : await Hive.openBox<T>(key);
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async =>
      (await openBox<dynamic>(key)).clear();
  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}

class _IdentitySiController extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.8, fatigue: 0.1, completedToday: 0);
}

class _IdentityLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _IdentityProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();
  @override
  Future<void> addXP(int amount) async =>
      state = state.copyWith(xp: state.xp + amount);
}
