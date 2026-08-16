import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_projection_work_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_projection_work.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Hive implements HiveStore {
  const _Hive();
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();
  @override
  Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

const _Hive _hive = _Hive();

TaskOccurrenceProjectionWorkRepository _repository(AccountStorageScope scope) =>
    TaskOccurrenceProjectionWorkRepository(
      HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.taskOccurrenceProjectionWork, scope),
        hive: _hive,
      ),
    );

TaskOccurrenceProjectionWork _work(
  String suffix,
) => TaskOccurrenceProjectionWork(
  occurrenceId: 'task::$suffix',
  operationId: 'op-$suffix',
  taskTitle: 'Task $suffix',
  taskDifficulty: 3,
  transitionAt: DateTime.utc(2026, 8, 16),
  stages:
      const <TaskOccurrenceProjectionStage, TaskOccurrenceProjectionStageState>{
        TaskOccurrenceProjectionStage.timeline:
            TaskOccurrenceProjectionStageState.pending,
        TaskOccurrenceProjectionStage.completionLedger:
            TaskOccurrenceProjectionStageState.done,
      },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => Hive.init(
      Directory.systemTemp
          .createTempSync('task-occurrence-projection-work-')
          .path,
    ),
  );

  test(
    'projection work is account-scoped and survives repository recreation',
    () async {
      final AccountStorageScope a = AccountStorageScope.authenticated('work-a');
      final AccountStorageScope b = AccountStorageScope.authenticated('work-b');
      final TaskOccurrenceProjectionWork value = _work('same');
      final TaskOccurrenceProjectionWorkRepository first = _repository(a);
      await first.save(value);
      await first.cancelAndDrain();

      final TaskOccurrenceProjectionWorkRepository restarted = _repository(a);
      final List<TaskOccurrenceProjectionWork> recovered = await restarted
          .listPending();
      expect(recovered.single.id, value.id);
      expect(
        recovered.single.isPending(TaskOccurrenceProjectionStage.timeline),
        isTrue,
      );
      expect(await _repository(b).listPending(), isEmpty);
    },
  );

  test(
    'same projection operation overwrites state without a duplicate work item',
    () async {
      final AccountStorageScope a = AccountStorageScope.authenticated('work-c');
      final TaskOccurrenceProjectionWork initial = _work('update');
      final TaskOccurrenceProjectionWorkRepository repository = _repository(a);
      await repository.save(initial);
      await repository.save(
        initial.withStage(
          TaskOccurrenceProjectionStage.timeline,
          TaskOccurrenceProjectionStageState.done,
        ),
      );

      expect(await repository.listPending(), isEmpty);
      final TaskOccurrenceProjectionWork? stored = await repository.getById(
        initial.id,
      );
      expect(stored, isNotNull);
      expect(
        stored!.isPending(TaskOccurrenceProjectionStage.timeline),
        isFalse,
      );
    },
  );
}
