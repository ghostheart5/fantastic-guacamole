import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Creator shows bound diff, confirms once, and exposes undo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final _ScreenTaskRepository repository = _ScreenTaskRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('creator-screen-test'),
        ),
        domainTaskRepositoryProvider.overrideWithValue(repository),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        creatorHandshakeClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 8, 20, 20),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(creatorHandshakeProvider.notifier)
        .stage(
          data: const CreatorFormData(
            title: 'Ship one verified change',
            description: 'The exact before and after must be visible.',
            type: 'Task',
            priority: 4,
          ),
          source: CreatorHandshakeSource.smartPlanner,
        );
    expect(repository.saveCalls, 0);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreatorScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CONFIRM CREATOR CHANGES'), findsOneWidget);
    expect(
      find.textContaining('Nothing is saved until you confirm'),
      findsOneWidget,
    );
    expect(find.textContaining('Account binding'), findsOneWidget);
    expect(find.textContaining('Domain version'), findsOneWidget);
    expect(find.textContaining('Displayed diff'), findsOneWidget);
    expect(
      find.textContaining('Title: Not present → Ship one verified change'),
      findsOneWidget,
    );
    expect(repository.saveCalls, 0);

    final Finder confirm = find.byKey(const Key('creator-confirm-selected'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.saveCalls, 1);
    expect(find.text('CONFIRMED CREATOR RECEIPT'), findsOneWidget);
    expect(find.textContaining('Saved exactly once'), findsOneWidget);
    expect(find.text('Undo creation'), findsOneWidget);

    final Finder undo = find.byKey(const Key('creator-undo-confirmed'));
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(find.text('CREATION UNDONE'), findsOneWidget);
  });

  testWidgets('operation can be deselected and confirmation becomes disabled', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _ScreenTaskRepository repository = _ScreenTaskRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('creator-screen-test'),
        ),
        domainTaskRepositoryProvider.overrideWithValue(repository),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(creatorHandshakeProvider.notifier)
        .stage(
          data: const CreatorFormData(
            title: 'Optional operation',
            type: 'Task',
            priority: 3,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreatorScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final ElevatedButton confirm = tester.widget<ElevatedButton>(
      find.byKey(const Key('creator-confirm-selected')),
    );
    expect(confirm.onPressed, isNull);
    expect(
      find.textContaining('Select at least one operation'),
      findsOneWidget,
    );
    expect(repository.saveCalls, 0);
  });

  testWidgets(
    'guided scheduled confirmation records milestones and opens Timeline',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _ScreenTaskRepository repository = _ScreenTaskRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('guided-creator-screen-test'),
          ),
          domainTaskRepositoryProvider.overrideWithValue(repository),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
          creatorHandshakeClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 20, 20),
          ),
        ],
      );
      addTearDown(container.dispose);
      final AdaptiveGuidanceState initial = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(initial.has(GuidanceMilestone.firstItem), isFalse);
      await container
          .read(creatorHandshakeProvider.notifier)
          .stage(
            data: CreatorFormData(
              title: 'First scheduled task',
              type: 'Task',
              priority: 4,
              scheduledFor: DateTime.utc(2026, 8, 20, 21),
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CreatorScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(FirstRunTutorialTargets.creatorConfirm.currentContext, isNotNull);
      final Finder confirm = find.byKey(const Key('creator-confirm-selected'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final AdaptiveGuidanceState completed = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(repository.saveCalls, 1);
      expect(completed.has(GuidanceMilestone.firstItem), isTrue);
      expect(completed.has(GuidanceMilestone.firstSchedule), isTrue);
      expect(container.read(appFlowProvider), AppView.timeline);
    },
  );
}

class _ScreenTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> tasks = <String, TaskEntity>{};
  int saveCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> deleteTask(String id) async {
    final TaskEntity? task = tasks[id];
    if (task == null || task.isCanceled) return;
    deleteCalls += 1;
    tasks[id] = task.copyWith(isCanceled: true, updatedAt: DateTime.now());
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async =>
      tasks.values.toList(growable: false);

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    final TaskEntity? task = tasks[id];
    return task == null || task.isCanceled ? null : task;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    saveCalls += 1;
    tasks[task.id] = task;
  }
}
