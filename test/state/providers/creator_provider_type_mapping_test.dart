import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routine maps to daily recurrence with lighter energy demand', () async {
    final _CaptureCreateTaskUseCase capture = _CaptureCreateTaskUseCase();
    final _FakeLocalMetricsAccumulator metrics = _FakeLocalMetricsAccumulator();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        createTaskUseCaseProvider.overrideWithValue(capture),
        localMetricsAccumulatorProvider.overrideWithValue(metrics),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(creatorActionsProvider)
        .createTask(const CreatorFormData(title: 'Morning reset', type: 'Routine', priority: 2));

    final TaskEntity created = capture.lastCreated!;
    expect(created.recurrenceRule.name, 'daily');
    expect(created.energyRequired, 2);
    expect(created.difficulty, 3);
    expect(created.priority, 2);
    expect(metrics.recordedTaskCreated, 1);
  });

  test('mission and note apply priority and effort semantics', () async {
    final _CaptureCreateTaskUseCase capture = _CaptureCreateTaskUseCase();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        createTaskUseCaseProvider.overrideWithValue(capture),
        localMetricsAccumulatorProvider.overrideWithValue(_FakeLocalMetricsAccumulator()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(creatorActionsProvider)
        .createTask(const CreatorFormData(title: 'Big launch prep', type: 'Mission', priority: 2));

    final TaskEntity mission = capture.lastCreated!;
    expect(mission.priority, 4);
    expect(mission.difficulty, 5);
    expect(mission.energyRequired, 3);

    await container
        .read(creatorActionsProvider)
        .createTask(
          const CreatorFormData(title: 'Capture quick thought', type: 'Note', priority: 5),
        );

    final TaskEntity note = capture.lastCreated!;
    expect(note.priority, 1);
    expect(note.energyRequired, 1);
    expect(note.recurrenceRule.name, 'none');
  });
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
