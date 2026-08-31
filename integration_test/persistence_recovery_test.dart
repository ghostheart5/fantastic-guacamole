import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('task survives restart and malformed storage degrades safely', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'persistence-integration-user',
    );
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'chronospark_persistence_integration_',
    );
    await Hive.close();
    Hive.init(tempDir.path);
    final _DirectHiveStore backend = _DirectHiveStore();
    addTearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final ProviderContainer firstRun = _containerFor(backend, scope);
    await firstRun
        .read(taskActionsProvider)
        .createQuickTask('Persisted integration task');
    expect(
      (await firstRun.read(tasksProvider.future)).map((t) => t.title),
      contains('Persisted integration task'),
    );
    firstRun.dispose();

    final ProviderContainer secondRun = _containerFor(backend, scope);
    addTearDown(secondRun.dispose);
    final recovered = await secondRun.read(tasksProvider.future);
    expect(
      recovered.map((t) => t.title),
      contains('Persisted integration task'),
    );

    final Box<String> taskBox = await backend.openBox<String>(
      HiveBoxes.accountScoped(HiveBoxes.tasks, scope),
    );
    await taskBox.put('malformed-task', '{ malformed-json');

    final ProviderContainer corruptedRun = _containerFor(backend, scope);
    addTearDown(corruptedRun.dispose);

    final recoveredAfterCorruption = await corruptedRun
        .read(tasksProvider.future)
        .timeout(const Duration(seconds: 2));
    expect(
      recoveredAfterCorruption.map((task) => task.title),
      contains('Persisted integration task'),
    );
    expect(
      taskBox.get(TaskRepository.quarantineKey),
      contains('malformed-task'),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: corruptedRun,
        child: const MaterialApp(home: SmartPlannerScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(SmartPlannerScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _containerFor(HiveStore backend, AccountStorageScope scope) {
  return ProviderContainer(
    overrides: [
      hiveStoreProvider.overrideWithValue(backend),
      accountStorageScopeProvider.overrideWithValue(scope),
      siStateProvider.overrideWith(_FixedSiStateController.new),
      learningProvider.overrideWith(_FixedLearningController.new),
    ],
  );
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<dynamic> box = Hive.isBoxOpen(key)
        ? Hive.box<dynamic>(key)
        : await Hive.openBox<dynamic>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<dynamic>(key).close();
    }
  }
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.7, fatigue: 0.2, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}
