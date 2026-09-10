import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'dart:async';

import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
// Regression coverage for AUD-LIB-04 and AUD-LIB-05.
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/fake_task_repository.dart';
import 'lib_audit_mutation_regression_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final phase in ['stage', 'confirm', 'undo']) {
    for (final returnToA in [false, true]) {
      test(
        'AUD-LIB-04 Creator $phase cannot survive an account switch returnToA=$returnToA',
        () async {
          SharedPreferences.setMockInitialValues({});
          var scope = AccountStorageScope.authenticated('audit-owner-a');
          final a = GatedHabits()..items = [];
          final b = fixtures.Habits()..items = [];
          final store = SecureStore(backend: InMemorySecureStoreBackend());
          final request = PersonContextAccessRequest(
            surface: PersonContextSurface.creator,
            purposes: operationalPersonContextPurposes,
          );
          final container = ProviderContainer(
            overrides: [
              accountStorageScopeProvider.overrideWith((ref) => scope),
              domainTaskRepositoryProvider.overrideWithValue(
                FakeTaskRepository(),
              ),
              domainGoalRepositoryProvider.overrideWithValue(EmptyGoals()),
              domainHabitRepositoryProvider.overrideWith(
                (ref) =>
                    ref.watch(accountStorageScopeProvider).rawUserId ==
                        'audit-owner-a'
                    ? a
                    : b,
              ),
              domainNoteRepositoryProvider.overrideWithValue(fixtures.Notes()),
              secureStoreProvider.overrideWithValue(store),
              personContextForSurfaceProvider(request).overrideWithValue(null),
              creatorHandshakeClockProvider.overrideWithValue(
                () => DateTime.utc(2026, 9, 9, 12),
              ),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(creatorHandshakeProvider.notifier);
          const form = CreatorFormData(
            title: 'Account A private rhythm',
            type: 'Daily Rhythm',
            priority: 3,
          );
          final Future<Object?> pending;
          if (phase == 'stage') {
            a.blockOnRead = 1;
            pending = notifier.stage(data: form);
          } else {
            await notifier.stage(data: form);
            if (phase == 'undo') {
              await notifier.confirm();
              expect(a.items, hasLength(1));
            }
            // Final snapshot read immediately before the canonical write/delete.
            a.blockOnRead = a.reads + 3;
            pending = phase == 'undo' ? notifier.undo() : notifier.confirm();
          }
          await a.entered.future.timeout(const Duration(seconds: 5));
          scope = AccountStorageScope.authenticated('audit-owner-b');
          container
              .read(authSessionBoundaryProvider.notifier)
              .begin(userId: 'audit-owner-b', isTransitioning: false);
          container.invalidate(accountStorageScopeProvider);
          container.invalidate(creatorHandshakeProvider);
          container.read(creatorHandshakeProvider);
          if (returnToA) {
            scope = AccountStorageScope.authenticated('audit-owner-a');
            container
                .read(authSessionBoundaryProvider.notifier)
                .begin(userId: 'audit-owner-a', isTransitioning: false);
            container.invalidate(accountStorageScopeProvider);
            container.invalidate(creatorHandshakeProvider);
            container.read(creatorHandshakeProvider);
          }
          a.release.complete();
          await pending;
          expect(
            a.items,
            phase == 'undo' ? hasLength(1) : isEmpty,
            reason: 'An obsolete operation must stop before mutating',
          );
          expect(container.read(creatorHandshakeProvider).receipt, isNull);
          expect(
            b.items,
            isEmpty,
            reason:
                'An A confirmation cannot resolve B save use cases after an awaited A read',
          );
        },
      );
    }
  }

  test(
    'Creator and a rhythm screen edit share one fresh mutation sequence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = GatedHabits();
      final request = PersonContextAccessRequest(
        surface: PersonContextSurface.creator,
        purposes: operationalPersonContextPurposes,
      );
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('audit-owner-a'),
          ),
          domainTaskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          domainGoalRepositoryProvider.overrideWithValue(EmptyGoals()),
          domainHabitRepositoryProvider.overrideWithValue(repo),
          domainNoteRepositoryProvider.overrideWithValue(fixtures.Notes()),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
          personContextForSurfaceProvider(request).overrideWithValue(null),
          reminderOrchestratorServiceProvider.overrideWithValue(
            ReminderOrchestratorService(
              preferences: fixtures.DisabledPreferences(),
              notifications: NotificationsService(fixtures.Notifications()),
              scheduler: NotificationScheduler(),
              accountScope: 'audit-owner-a',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(habitsProvider.future);
      final creator = container.read(creatorHandshakeProvider.notifier);
      await creator.stage(
        data: const CreatorFormData(
          title: 'Stretch',
          type: 'Daily Rhythm',
          priority: 3,
        ),
      );
      repo.blockOnRead = repo.reads + 3;
      final creation = creator.confirm();
      await repo.entered.future.timeout(const Duration(seconds: 5));
      final rename = container
          .read(habitsProvider.notifier)
          .renameHabit('journal', 'Evening journal');
      repo.release.complete();
      await Future.wait([creation, rename]);
      expect(repo.items.map((h) => h.title).toSet(), {
        'Walk',
        'Evening journal',
        'Stretch',
      });
      expect(
        container.read(habitsProvider).requireValue.map((h) => h.title).toSet(),
        {'Walk', 'Evening journal', 'Stretch'},
      );
    },
  );

  for (final undo in [false, true]) {
    test(
      'queued Creator action cannot target a replaced review undo=$undo',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = fixtures.Habits()..items = [];
        final request = PersonContextAccessRequest(
          surface: PersonContextSurface.creator,
          purposes: operationalPersonContextPurposes,
        );
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(
              AccountStorageScope.authenticated('audit-owner-a'),
            ),
            domainTaskRepositoryProvider.overrideWithValue(
              FakeTaskRepository(),
            ),
            domainGoalRepositoryProvider.overrideWithValue(EmptyGoals()),
            domainHabitRepositoryProvider.overrideWithValue(repo),
            domainNoteRepositoryProvider.overrideWithValue(fixtures.Notes()),
            secureStoreProvider.overrideWithValue(
              SecureStore(backend: InMemorySecureStoreBackend()),
            ),
            personContextForSurfaceProvider(request).overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);
        final creator = container.read(creatorHandshakeProvider.notifier);
        await creator.stage(
          data: const CreatorFormData(
            title: 'Reviewed rhythm',
            type: 'Daily Rhythm',
            priority: 3,
          ),
        );
        if (undo) await creator.confirm();
        final entered = Completer<void>();
        final release = Completer<void>();
        final blocker = runAccountStorageMutation(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final pending = undo ? creator.undo() : creator.confirm();
        try {
          await creator.stage(
            data: const CreatorFormData(
              title: 'New unconfirmed rhythm',
              type: 'Daily Rhythm',
              priority: 3,
            ),
          );
        } finally {
          release.complete();
        }
        await Future.wait([blocker, pending]);
        expect(
          repo.items.map((h) => h.title),
          undo ? ['Reviewed rhythm'] : isEmpty,
        );
        expect(container.read(creatorHandshakeProvider).receipt, isNull);
      },
    );
  }

  test('AUD-LIB-05 unreadable profile bytes must survive a name edit', () async {
    final scope = AccountStorageScope.authenticated('audit-owner-a');
    final backend = InMemorySecureStoreBackend();
    final store = SecureStore(backend: backend);
    final scoped = store.forAccount(scope);
    const original =
        '{"xp":"unreadable","level":20,"name":"Original","streak":12}';
    await scoped.writeString('profile_state_v2', original);
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(scope),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        secureStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(profileProvider.notifier).updateName('Changed name'),
      throwsA(isA<ProfileUnavailableException>()),
    );
    expect(
      container.read(profileProvider).readStatus,
      ProfileReadStatus.unavailable,
    );
    final profile = container.read(profileProvider.notifier);
    for (final action in <Future<void> Function()>[
      () => profile.addXP(25),
      () => profile.awardXP(25, source: 'task'),
      () => profile.toggleSound(false),
      profile.incrementStreak,
      profile.resetStreak,
    ]) {
      await expectLater(action(), throwsA(isA<ProfileUnavailableException>()));
    }
    final retained = await backend.readAll();
    expect(
      retained.values,
      contains(original),
      reason:
          'A decode failure must block replacement or preserve recovery bytes before saving defaults',
    );
  });
  test(
    'a temporary profile read failure preserves data and retry restores progress',
    () async {
      final scope = AccountStorageScope.authenticated('audit-owner-a');
      final backend = FailingReadBackend();
      final store = SecureStore(backend: backend);
      final scoped = store.forAccount(scope);
      const original = '{"xp":2400,"level":20,"name":"Original","streak":12}';
      await scoped.writeString('profile_state_v2', original);
      backend.fail = true;
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(scope),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          secureStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(profileProvider.notifier).updateName('Blocked'),
        throwsA(isA<ProfileUnavailableException>()),
      );
      expect((await backend.readAll()).values, contains(original));
      backend.fail = false;
      container.read(profileProvider.notifier).retryLoad();
      await container.read(profileProvider.notifier).updateName('Recovered');
      final profile = container.read(profileProvider);
      expect(profile.readStatus, ProfileReadStatus.ready);
      expect(profile.name, 'Recovered');
      expect(profile.xp, 2400);
      expect(profile.level, 20);
      expect(profile.streak, 12);
    },
  );
}

class GatedHabits extends fixtures.Habits {
  int reads = 0;
  int? blockOnRead;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<HabitEntity>> getHabits() async {
    reads++;
    if (reads == blockOnRead) {
      entered.complete();
      await release.future;
    }
    return super.getHabits();
  }
}

class EmptyGoals implements IGoalRepository {
  @override
  List<GoalEntity> getGoals() => [];
  @override
  Future<void> saveGoal(GoalEntity goal) async {}
  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
  @override
  Future<void> deleteGoal(String id) async {}
}

class FailingReadBackend extends InMemorySecureStoreBackend {
  bool fail = false;
  @override
  Future<String?> read({required String key}) async {
    if (fail) throw StateError('Temporary secure storage failure');
    return super.read(key: key);
  }
}
