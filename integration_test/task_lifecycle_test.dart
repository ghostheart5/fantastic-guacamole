import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/session_score_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('task lifecycle creates, surfaces, completes, and updates progression state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
        siStateProvider.overrideWith(_FixedSiStateController.new),
        learningProvider.overrideWith(_FixedLearningController.new),
        profileProvider.overrideWith(_TestProfileController.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(creatorActionsProvider)
        .createTask(
          const CreatorFormData(
            title: 'Release blocker lifecycle',
            description: 'Create task, see it, complete it.',
            type: 'Task',
            priority: 5,
          ),
        );

    final tasks = await container.read(tasksProvider.future);
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Release blocker lifecycle');

    final String taskId = tasks.single.id;
    await container.read(taskActionsProvider).completeTask(taskId);

    final ITaskRepository repository = container.read(domainTaskRepositoryProvider);
    final TaskEntity? stored = await repository.getTaskById(taskId);
    expect(stored, isNotNull);
    expect(stored!.isCompleted, isTrue);
    expect(stored.completedAt, isNotNull);

    final remaining = await container.read(tasksProvider.future);
    expect(remaining, isEmpty);

    final score = container.read(sessionScoreProvider);
    expect(score, isNotNull);
    expect(score!.xp, greaterThan(0));
    expect(container.read(profileProvider).xp, greaterThan(0));
  });
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() => const SIState(energy: 0.8, fatigue: 0.1, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  void addXP(int amount) {
    state = state.copyWith(xp: state.xp + amount);
  }
}
