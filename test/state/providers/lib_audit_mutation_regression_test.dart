import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
// Regression coverage for AUD-LIB-01, AUD-LIB-02 and AUD-LIB-03.
import 'dart:async';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/adapters/note_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AUD-LIB-01 both independent rhythm edits must survive overlap',
    () async {
      final repo = Habits();
      final notifications = Notifications();
      final container = habitContainer(repo, notifications);
      addTearDown(container.dispose);
      await container.read(habitsProvider.future);
      final notifier = container.read(habitsProvider.notifier);
      await Future.wait([
        notifier.toggleHabit('walk'),
        notifier.toggleHabit('journal'),
      ]);
      expect(
        repo.items.where((h) => !h.active).map((h) => h.id).toSet(),
        {'walk', 'journal'},
        reason: 'Both completed saves must remain durable',
      );
    },
  );

  test(
    'AUD-LIB-02 reminder failure must not make the next edit undo a durable save',
    () async {
      final repo = Habits();
      final notifications = Notifications();
      final container = habitContainer(repo, notifications);
      addTearDown(container.dispose);
      await container.read(habitsProvider.future);
      final notifier = container.read(habitsProvider.notifier);
      notifications.fail = true;
      await expectLater(notifier.toggleHabit('walk'), throwsStateError);
      expect(
        repo.items.firstWhere((h) => h.id == 'walk').active,
        isFalse,
        reason:
            'First edit really reached durable repository before reminder failed',
      );
      notifications.fail = false;
      await notifier.renameHabit('journal', 'Evening journal');
      expect(
        repo.items.firstWhere((h) => h.id == 'walk').active,
        isFalse,
        reason:
            'Unrelated later rename must not roll back the already saved pause',
      );
    },
  );

  for (final returnToA in [false, true]) {
    test(
      'AUD-LIB-03 late note create cannot publish after account transition returnToA=$returnToA',
      () async {
        var scope = AccountStorageScope.authenticated('audit-owner-a');
        final a = Notes();
        final b = Notes();
        final projections = <String, List<String>>{};
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWith((ref) => scope),
            domainNoteRepositoryProvider.overrideWith(
              (ref) =>
                  ref.watch(accountStorageScopeProvider).rawUserId ==
                      'audit-owner-a'
                  ? a
                  : b,
            ),
            noteTimelineAdapterProvider.overrideWith((ref) {
              final owner = ref.watch(accountStorageScopeProvider).rawUserId!;
              return Projection(projections.putIfAbsent(owner, () => []));
            }),
          ],
        );
        addTearDown(container.dispose);
        await container.read(notesProvider.future);
        a.saveGate = Completer<void>();
        Object? staleError;
        final pending = container
            .read(notesProvider.notifier)
            .createNote(title: 'Account A private note')
            .catchError((Object error) {
              staleError = error;
            });
        await a.saveEntered.future;
        scope = AccountStorageScope.authenticated('audit-owner-b');
        container
            .read(authSessionBoundaryProvider.notifier)
            .begin(userId: 'audit-owner-b', isTransitioning: false);
        container.invalidate(accountStorageScopeProvider);
        container.invalidate(notesProvider);
        expect(await container.read(notesProvider.future), isEmpty);
        if (returnToA) {
          scope = AccountStorageScope.authenticated('audit-owner-a');
          container
              .read(authSessionBoundaryProvider.notifier)
              .begin(userId: 'audit-owner-a', isTransitioning: false);
          container.invalidate(accountStorageScopeProvider);
          container.invalidate(notesProvider);
          expect(await container.read(notesProvider.future), isEmpty);
        }
        a.saveGate!.complete();
        await pending;
        expect(b.items, isEmpty, reason: 'Canonical B notes must stay empty');
        expect(
          container.read(notesProvider).requireValue,
          isEmpty,
          reason: 'A completed write must not repopulate B in-memory Notes',
        );
        expect(
          projections.values.expand((value) => value),
          isEmpty,
          reason: 'A note title must not be projected into B Timeline',
        );
        // A disposed old notifier may reject its UI update. That is not a data leak.
        if (staleError != null) {
          expect(staleError, isA<StateError>());
        }
      },
    );
  }

  test(
    'overlapping delete rename and create preserve every completed mutation',
    () async {
      final repo = Habits();
      final container = habitContainer(repo, Notifications());
      addTearDown(container.dispose);
      await container.read(habitsProvider.future);
      final notifier = container.read(habitsProvider.notifier);
      await Future.wait([
        notifier.removeHabit('walk'),
        notifier.renameHabit('journal', 'Evening journal'),
        notifier.addHabit(title: 'Stretch'),
      ]);
      expect(repo.items.map((h) => h.title).toSet(), {
        'Evening journal',
        'Stretch',
      });
      expect(container.read(habitsProvider).requireValue, repo.items);
    },
  );

  test(
    'rhythms remain readable when notification setup fails during load',
    () async {
      final repo = Habits();
      final notifications = Notifications()..fail = true;
      final container = habitContainer(repo, notifications);
      addTearDown(container.dispose);
      expect(await container.read(habitsProvider.future), repo.items);
    },
  );
  test('a new account gets its own real Notes Timeline adapter', () async {
    var scope = AccountStorageScope.authenticated('audit-owner-a');
    final a = Notes();
    final b = Notes();
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => scope),
        domainNoteRepositoryProvider.overrideWith(
          (ref) =>
              ref.watch(accountStorageScopeProvider).rawUserId ==
                  'audit-owner-a'
              ? a
              : b,
        ),
        sensitivePrefsStoreProvider.overrideWithValue(MemoryPreferences()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(notesProvider.future);
    await container.read(notesProvider.notifier).createNote(title: 'Private A');
    final timelineA = container.read(timelineRepositoryProvider);
    expect(timelineA.getEvents().map((e) => e.detail), ['Private A']);
    scope = AccountStorageScope.authenticated('audit-owner-b');
    container
        .read(authSessionBoundaryProvider.notifier)
        .begin(userId: 'audit-owner-b', isTransitioning: false);
    container.invalidate(accountStorageScopeProvider);
    container.invalidate(notesProvider);
    await container.read(notesProvider.future);
    await container.read(notesProvider.notifier).createNote(title: 'Private B');
    final timelineB = container.read(timelineRepositoryProvider);
    expect(timelineA.getEvents().map((e) => e.detail), ['Private A']);
    expect(timelineB.getEvents().map((e) => e.detail), ['Private B']);
  });
}

ProviderContainer habitContainer(Habits repo, Notifications notifications) =>
    ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('audit-owner-a'),
        ),
        domainHabitRepositoryProvider.overrideWithValue(repo),
        reminderOrchestratorServiceProvider.overrideWithValue(
          ReminderOrchestratorService(
            preferences: DisabledPreferences(),
            notifications: NotificationsService(notifications),
            scheduler: NotificationScheduler(),
            accountScope: 'audit-owner-a',
          ),
        ),
      ],
    );

class Habits implements IHabitRepository {
  List<HabitEntity> items = [
    HabitEntity(id: 'walk', title: 'Walk', createdAt: DateTime.utc(2026, 9, 9)),
    HabitEntity(
      id: 'journal',
      title: 'Journal',
      createdAt: DateTime.utc(2026, 9, 9),
    ),
  ];
  @override
  Future<List<HabitEntity>> getHabits() async => List.of(items);
  @override
  Future<void> saveHabits(List<HabitEntity> value) async {
    items = List.of(value);
  }
}

class Notes implements INoteRepository {
  List<NoteEntity> items = [];
  Completer<void>? saveGate;
  final saveEntered = Completer<void>();
  @override
  Future<List<NoteEntity>> getNotes() async => List.of(items);
  @override
  Future<void> saveNote(NoteEntity note) async {
    if (!saveEntered.isCompleted) saveEntered.complete();
    await saveGate?.future;
    items = [note, ...items.where((n) => n.id != note.id)];
  }

  @override
  Future<void> deleteNote(String id) async {
    items.removeWhere((n) => n.id == id);
  }
}

class Projection extends NoteTimelineAdapter {
  Projection(this.titles) : super(UnusedTimeline());
  final List<String> titles;
  @override
  Future<void> record(NoteEntity note, NoteTimelineMutation mutation) async {
    titles.add(note.title);
  }
}

class UnusedTimeline implements ITimelineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DisabledPreferences implements SharedPrefsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => 'false';
  @override
  Future<void> save(String key, String value) async {}
}

class Notifications implements INotificationRepository {
  bool fail = false;
  @override
  Future<void> cancelNotification(String id) async {
    if (fail) throw StateError('synthetic notification failure');
  }

  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}

class MemoryPreferences implements SharedPrefsStore {
  final values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}
