import 'package:fantastic_guacamole/core/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final repositoryHiveStoreProvider = Provider<HiveStore>((ref) {
  return const HiveStoreAdapter();
});

TaskRepository taskRepository(Ref ref) {
  return TaskRepository(
    storage: HiveStorage<String>(
      'tasks_box',
      hive: ref.read(repositoryHiveStoreProvider),
    ),
  );
}

final taskRepositoryProvider = Provider<TaskRepository>(taskRepository);
