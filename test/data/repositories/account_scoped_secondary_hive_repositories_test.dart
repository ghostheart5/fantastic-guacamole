import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final NotifierProvider<_ScopeNotifier, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeNotifier, AccountStorageScope>(_ScopeNotifier.new);

void main() {
  late Directory tempDirectory;
  late _DirectHiveStore hive;

  setUp(() async {
    await Hive.close();
    tempDirectory = await Directory.systemTemp.createTemp(
      'secondary_hive_account_scope_test_',
    );
    Hive.init(tempDirectory.path);
    hive = _DirectHiveStore();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'five Hive domains and offline queue rotate with account scope',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          hiveStoreProvider.overrideWithValue(hive),
          accountStorageScopeProvider.overrideWith(
            (Ref ref) => ref.watch(_scopeProvider),
          ),
          accountLegacyOwnershipProvider.overrideWith((Ref ref) {
            final AccountStorageScope scope = ref.watch(_scopeProvider);
            return scope.isWritable
                ? LegacyScopeOwnership.provenNotOwned
                : LegacyScopeOwnership.ambiguous;
          }),
        ],
      );
      addTearDown(container.dispose);

      final DateTime date = DateTime.utc(2026, 9, 3);
      final List<Object> accountAUseCases = _useCases(container);
      await _saveAccountRecords(container, 'account-a', date);

      container
          .read(_scopeProvider.notifier)
          .setScope(AccountStorageScope.authenticated('account-b'));
      await Future<void>.delayed(Duration.zero);

      final List<Object> accountBUseCases = _useCases(container);
      for (int index = 0; index < accountAUseCases.length; index += 1) {
        expect(accountBUseCases[index], isNot(same(accountAUseCases[index])));
      }
      await _expectAccountEmpty(container, date);
      await _saveAccountRecords(container, 'account-b', date);

      container
          .read(_scopeProvider.notifier)
          .setScope(AccountStorageScope.authenticated('account-a'));
      await Future<void>.delayed(Duration.zero);

      expect(
        (await container.read(planRepositoryProvider).getPlan(date))?.id,
        'account-a-plan',
      );
      expect(
        container.read(projectRepositoryProvider).getProjects().single.id,
        'account-a-project',
      );
      expect(
        container.read(routineRepositoryProvider).getRoutines().single.id,
        'account-a-routine',
      );
      expect(
        container.read(subtaskRepositoryProvider).getSubtasks().single.id,
        'account-a-subtask',
      );
      expect(
        (await container.read(progressionRepositoryProvider).getProgression())
            ?.xp,
        11,
      );
      expect(
        (await container.read(offlineSyncQueueProvider)!.loadQueue())
            .single
            .dedupeKey,
        'account-a-sync',
      );
    },
  );

  test(
    'legacy boxes copy only for the proven owner and remain preserved',
    () async {
      const List<String> bases = <String>[
        HiveBoxes.dailyPlans,
        HiveBoxes.projects,
        HiveBoxes.routines,
        HiveBoxes.subtasks,
        HiveBoxes.progression,
        HiveBoxes.offlineQueue,
        HiveBoxes.profile,
      ];
      final AccountStorageScope accountA = AccountStorageScope.authenticated(
        'account-a',
      );
      final AccountStorageScope accountB = AccountStorageScope.authenticated(
        'account-b',
      );

      for (final String base in bases) {
        final HiveStorage<String> legacy = HiveStorage<String>(
          base,
          hive: hive,
        );
        await legacy.put('owned-record', 'preserve-$base');

        final AccountScopedHiveStorage accountAStorage =
            AccountScopedHiveStorage(
              baseBox: base,
              scope: accountA,
              hive: hive,
              legacyOwnership: LegacyScopeOwnership.provenOwned,
            );
        final AccountScopedHiveStorage accountBStorage =
            AccountScopedHiveStorage(
              baseBox: base,
              scope: accountB,
              hive: hive,
              legacyOwnership: LegacyScopeOwnership.provenNotOwned,
            );

        await accountAStorage.prepare();
        await accountBStorage.prepare();

        expect(accountAStorage.get('owned-record'), 'preserve-$base');
        expect(accountBStorage.get('owned-record'), isNull);
        expect(legacy.get('owned-record'), 'preserve-$base');
      }
    },
  );

  test('signed-out Hive providers cannot read or write account data', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        hiveStoreProvider.overrideWithValue(hive),
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_scopeProvider),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.unownedSignedOut,
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(_scopeProvider.notifier)
        .setScope(const AccountStorageScope.signedOut());
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      container.read(planRepositoryProvider).getPlan(DateTime.utc(2026, 9, 3)),
      throwsStateError,
    );
    await expectLater(
      container
          .read(projectRepositoryProvider)
          .saveProject(
            ProjectEntity(
              id: 'blocked',
              name: 'Blocked',
              createdAt: DateTime.utc(2026, 9, 3),
            ),
          ),
      throwsStateError,
    );
    await expectLater(
      container.read(progressionRepositoryProvider).getProgression(),
      throwsStateError,
    );

    final queue = container.read(offlineSyncQueueProvider)!;
    await queue.enqueue(actionType: 'sync_to_cloud', dedupeKey: 'blocked-sync');
    expect(await queue.loadQueue(), isEmpty);
  });
}

List<Object> _useCases(ProviderContainer container) => <Object>[
  container.read(getPlanUseCaseProvider),
  container.read(getProjectsUseCaseProvider),
  container.read(getRoutinesUseCaseProvider),
  container.read(getSubtasksUseCaseProvider),
  container.read(getProgressionUseCaseProvider),
  container.read(getSignalsUseCaseProvider),
  container.read(getLogsUseCaseProvider),
  container.read(getCalendarEntriesUseCaseProvider),
  container.read(getTimelineEventsUseCaseProvider),
  container.read(getProfileUseCaseProvider),
  container.read(getWorkspaceUseCaseProvider),
  container.read(getMilestonesUseCaseProvider),
];

Future<void> _saveAccountRecords(
  ProviderContainer container,
  String account,
  DateTime date,
) async {
  await container
      .read(planRepositoryProvider)
      .savePlan(
        PlanEntity(
          id: '$account-plan',
          date: date,
          blocks: <TimeBlock>[
            TimeBlock(
              id: '$account-block',
              taskId: '$account-task',
              title: account,
              start: date,
              end: date.add(const Duration(minutes: 30)),
            ),
          ],
        ),
      );
  await container
      .read(projectRepositoryProvider)
      .saveProject(
        ProjectEntity(id: '$account-project', name: account, createdAt: date),
      );
  await container
      .read(routineRepositoryProvider)
      .saveRoutine(
        HabitEntity(id: '$account-routine', title: account, createdAt: date),
      );
  await container
      .read(subtaskRepositoryProvider)
      .saveSubtask(
        SubtaskEntity(
          id: '$account-subtask',
          parentTaskId: '$account-task',
          title: account,
          createdAt: date,
        ),
      );
  await container
      .read(progressionRepositoryProvider)
      .saveProgression(const ProgressionEntity(xp: 11, level: 1, streak: 1));
  await container
      .read(offlineSyncQueueProvider)!
      .enqueue(actionType: 'sync_to_cloud', dedupeKey: '$account-sync');
}

Future<void> _expectAccountEmpty(
  ProviderContainer container,
  DateTime date,
) async {
  expect(await container.read(planRepositoryProvider).getPlan(date), isNull);
  expect(container.read(projectRepositoryProvider).getProjects(), isEmpty);
  expect(container.read(routineRepositoryProvider).getRoutines(), isEmpty);
  expect(container.read(subtaskRepositoryProvider).getSubtasks(), isEmpty);
  expect(
    await container.read(progressionRepositoryProvider).getProgression(),
    isNull,
  );
  expect(await container.read(offlineSyncQueueProvider)!.loadQueue(), isEmpty);
}

final class _ScopeNotifier extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('account-a');

  void setScope(AccountStorageScope scope) => state = scope;
}

final class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) return Hive.box<T>(key);
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
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}
