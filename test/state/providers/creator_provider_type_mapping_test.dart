import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy task API rejects routine instead of converting it', () async {
    final _CaptureCreateTaskUseCase capture = _CaptureCreateTaskUseCase();
    final _FakeLocalMetricsAccumulator metrics = _FakeLocalMetricsAccumulator();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('creator-type-test'),
        ),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        createTaskUseCaseProvider.overrideWithValue(capture),
        localMetricsAccumulatorProvider.overrideWithValue(metrics),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      () => container
          .read(creatorActionsProvider)
          .createTask(
            const CreatorFormData(
              title: 'Morning reset',
              type: 'Routine',
              priority: 2,
            ),
          ),
      throwsArgumentError,
    );

    expect(capture.lastCreated, isNull);
    expect(metrics.recordedTaskCreated, 0);
  });

  test(
    'legacy task API rejects goal and note instead of converting them',
    () async {
      final _CaptureCreateTaskUseCase capture = _CaptureCreateTaskUseCase();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('creator-type-test'),
          ),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
          createTaskUseCaseProvider.overrideWithValue(capture),
          localMetricsAccumulatorProvider.overrideWithValue(
            _FakeLocalMetricsAccumulator(),
          ),
        ],
      );
      addTearDown(container.dispose);

      for (final String type in <String>['Goal', 'Note']) {
        await expectLater(
          () => container
              .read(creatorActionsProvider)
              .createTask(
                CreatorFormData(
                  title: 'Do not convert $type',
                  type: type,
                  priority: 2,
                ),
              ),
          throwsArgumentError,
        );
      }

      expect(capture.lastCreated, isNull);
    },
  );
}

class _CaptureCreateTaskUseCase extends CreateTask {
  _CaptureCreateTaskUseCase() : super(const _NoopTaskRepository());

  TaskEntity? lastCreated;

  @override
  Future<void> call(TaskEntity task) async {
    lastCreated = task;
  }
}

class _NoopTaskRepository implements ITaskRepository {
  const _NoopTaskRepository();

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return const <TaskEntity>[];
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return null;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _FakeLocalMetricsAccumulator extends LocalMetricsAccumulator {
  int recordedTaskCreated = 0;

  @override
  Future<void> recordTaskCreated() async {
    recordedTaskCreated += 1;
  }
}
