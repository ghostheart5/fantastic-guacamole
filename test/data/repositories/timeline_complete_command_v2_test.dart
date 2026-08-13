import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override Future<void> clear() async => values.clear();
  @override Future<void> delete(String key) async => values.remove(key);
  @override Future<void> init() async {}
  @override String? load(String key) => values[key];
  @override Future<void> save(String key, String value) async { values[key] = value; }
}

class _Tasks implements ITaskRepository {
  _Tasks(this.task);
  TaskEntity task;
  @override Future<void> deleteTask(String id) async {}
  @override Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[task];
  @override Future<TaskEntity?> getTaskById(String id) async => id == task.id ? task : null;
  @override Future<void> saveTask(TaskEntity value) async { task = value; }
}

class _Profile extends ProfileController {
  @override
  ProfileState build() => ProfileState(profileReady: true);

  @override
  void addXP(int amount) {}
}

class _Learning extends LearningController {
  @override LearningState build() => const LearningState();
  @override Future<void> update({required bool success, required int difficulty}) async {}
}

class _Logs extends LogsActions {
  _Logs(super.ref);
  @override Future<void> addMirroredEntry({required String source, required String message, String? id, DateTime? timestamp}) async {}
  @override Future<void> addCompletedTask({required String task, bool mirrored = false, bool updateInsights = false, bool syncSoulMap = false}) async {}
}

TaskEntity _entity() => TaskEntity(id: 'complete-a', title: 'Complete under A', createdAt: DateTime.utc(2026, 8, 13), priority: 3, difficulty: 2, energyRequired: 2);
Task _task(TaskEntity value) => Task(id: value.id, title: value.title, priority: value.priority, difficulty: value.difficulty, energyRequired: value.energyRequired);

ProviderContainer _container(_Store store, AccountStorageScope scope, _Tasks tasks) => ProviderContainer(overrides: [
  sensitivePrefsStoreProvider.overrideWithValue(store),
  accountStorageScopeProvider.overrideWith((Ref ref) => scope),
  domainTaskRepositoryProvider.overrideWithValue(tasks),
  completeTaskUseCaseProvider.overrideWithValue(CompleteTask(tasks)),
  tasksProvider.overrideWith((Ref ref) async => <Task>[_task(tasks.task)]),
  profileProvider.overrideWith(_Profile.new),
  learningProvider.overrideWith(_Learning.new),
  logsActionsProvider.overrideWith((Ref ref) => _Logs(ref)),
]);

Future<void> _settle() async { for (var i = 0; i < 8; i++) { await Future<void>.delayed(Duration.zero); } }

void main() {
  test('PRE-TEST-02E1 complete command persists through real Timeline path to scoped V2 storage', () async {
    final _Store store = _Store();
    const String legacy = '[{"legacy":"timeline-sentinel"}]';
    store.values['timeline_events_v1'] = legacy;
    final AccountStorageScope a = AccountStorageScope.authenticated('account-a');
    final AccountStorageScope b = AccountStorageScope.authenticated('account-b');
    final _Tasks tasks = _Tasks(_entity());
    final ProviderContainer containerA = _container(store, a, tasks);
    addTearDown(containerA.dispose);

    await containerA.read(taskActionsProvider).completeTask('complete-a', notify: false);
    await _settle();
    final String keyA = 'timeline_events_v2.${a.v2Namespace}';
    final String keyB = 'timeline_events_v2.${b.v2Namespace}';
    expect(store.values[keyA], contains('Task Completed'));
    expect(store.values[keyB], isNull);
    expect(store.values['timeline_events_v1'], legacy);

    final ProviderContainer containerB = _container(store, b, _Tasks(_entity()));
    addTearDown(containerB.dispose);
    expect(containerB.read(timelineProvider), isEmpty);
    expect(store.values[keyB], isNull);

    final ProviderContainer containerAAgain = _container(store, a, _Tasks(_entity()));
    addTearDown(containerAAgain.dispose);
    expect(containerAAgain.read(timelineProvider).map((event) => event.title), contains('Task Completed'));
    expect(store.values['timeline_events_v1'], legacy);
  });

  test('PRE-TEST-02E2 delay and skip commands follow the real scoped Timeline path', () async {
    final _Store store = _Store();
    const String legacy = '[{"legacy":"timeline-sentinel"}]';
    store.values['timeline_events_v1'] = legacy;
    final AccountStorageScope a = AccountStorageScope.authenticated('account-a');
    final AccountStorageScope b = AccountStorageScope.authenticated('account-b');
    final String keyA = 'timeline_events_v2.${a.v2Namespace}';
    final String keyB = 'timeline_events_v2.${b.v2Namespace}';

    final ProviderContainer delayA = _container(store, a, _Tasks(_entity()));
    addTearDown(delayA.dispose);
    await delayA.read(taskActionsProvider).delayTask('complete-a', notify: false);
    await _settle();
    expect(store.values[keyA], contains('Task Delayed'));
    expect(store.values[keyB], isNull);
    expect(store.values['timeline_events_v1'], legacy);
    final ProviderContainer delayB = _container(store, b, _Tasks(_entity()));
    addTearDown(delayB.dispose);
    expect(delayB.read(timelineProvider), isEmpty);
    final ProviderContainer delayAAgain = _container(store, a, _Tasks(_entity()));
    addTearDown(delayAAgain.dispose);
    expect(delayAAgain.read(timelineProvider).map((event) => event.title), contains('Task Delayed'));

    final ProviderContainer skipB = _container(store, b, _Tasks(_entity()));
    addTearDown(skipB.dispose);
    await skipB.read(taskActionsProvider).skipTask('complete-a', notify: false);
    await _settle();
    expect(store.values[keyB], contains('Task Skipped'));
    expect(store.values[keyA], contains('Task Delayed'));
    expect(store.values['timeline_events_v1'], legacy);
    final ProviderContainer skipA = _container(store, a, _Tasks(_entity()));
    addTearDown(skipA.dispose);
    expect(skipA.read(timelineProvider).map((event) => event.title), contains('Task Delayed'));
    final ProviderContainer skipBAgain = _container(store, b, _Tasks(_entity()));
    addTearDown(skipBAgain.dispose);
    expect(skipBAgain.read(timelineProvider).map((event) => event.title), contains('Task Skipped'));
  });
}
