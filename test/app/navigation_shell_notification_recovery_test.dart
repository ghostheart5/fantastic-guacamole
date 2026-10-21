import 'dart:async';

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cold mounted shell reconciles revoked reminders without resume',
    (tester) async {
      final fixture = await _Fixture.create();
      await fixture.mount(tester);
      expect(fixture.scheduler.ownPending('a'), isEmpty);
      expect(fixture.scheduler.ownPending('b'), hasLength(4));
      expect(fixture.scheduler.cancelled, hasLength(4));
      expect(fixture.scheduler.permissionRequests, 0);
      expect(fixture.scheduler.scheduled, isEmpty);
      fixture.expectPreferencesPreserved();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fenced mount waits for ready account without another resume', (
    tester,
  ) async {
    final fixture = await _Fixture.create(ready: false);
    await fixture.mount(tester);
    expect(fixture.scheduler.cancelled, isEmpty);
    fixture.ready('a');
    await _flush(tester);
    expect(fixture.scheduler.ownPending('a'), isEmpty);
    expect(fixture.scheduler.permissionQueries, 1);
  });

  testWidgets('cold mount and queued resume coalesce granted registration', (
    tester,
  ) async {
    final fixture = await _Fixture.create(granted: true);
    await fixture.mount(tester, resumeBeforeDispatch: true);
    expect(fixture.scheduler.permissionQueries, 1);
    expect(
      fixture.scheduler.scheduled
          .where((row) => row.id == 'daily_planning_reminder')
          .single
          .time,
      (7, 30),
    );
    expect(
      fixture.scheduler.scheduled
          .where((row) => row.id == 'reflection_reminder')
          .single
          .time,
      (20, 0),
    );
    expect(
      fixture.scheduler.scheduled.where(
        (row) => row.cadence == HabitCadence.weekly,
      ),
      hasLength(1),
    );
    expect(fixture.scheduler.ownPending('a'), hasLength(4));
    expect(fixture.scheduler.permissionRequests, 0);
    fixture.expectPreferencesPreserved();
  });

  testWidgets('later resume clears newly revoked requests', (tester) async {
    final fixture = await _Fixture.create(granted: true);
    await fixture.mount(tester);
    fixture.scheduler.granted = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    expect(fixture.scheduler.ownPending('a'), isEmpty);
    expect(fixture.scheduler.permissionQueries, 2);
    expect(fixture.scheduler.permissionRequests, 0);
    fixture.expectPreferencesPreserved();
  });

  testWidgets('resume preserves the matching account reflection registration', (
    tester,
  ) async {
    final fixture = await _Fixture.create(granted: true);
    await fixture.mount(tester);
    fixture.scheduler.scheduled.clear();
    fixture.scheduler.cancelled.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    expect(
      fixture.scheduler.scheduled.where(
        (row) => row.id == 'reflection_reminder',
      ),
      isEmpty,
    );
    expect(
      fixture.scheduler.cancelled.where(
        (key) => key.endsWith(':reflection_reminder'),
      ),
      isEmpty,
    );
    expect(fixture.scheduler.ownPending('a'), hasLength(4));
    expect(fixture.scheduler.ownPending('b'), hasLength(4));
    fixture.expectPreferencesPreserved();
  });

  testWidgets(
    'A to B to A while permission awaits rejects the old generation',
    (tester) async {
      final fixture = await _Fixture.create();
      final gate = Completer<void>();
      fixture.scheduler.nextQuery = gate.future;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await fixture.mount(tester);
      expect(fixture.scheduler.permissionQueries, 1);
      expect(fixture.scheduler.cancelled, isEmpty);
      fixture.ready('b');
      fixture.ready('a');
      await _flush(tester);
      expect(
        fixture.scheduler.permissionQueries,
        1,
        reason: 'A newer lease must wait for the previous attempt.',
      );
      gate.complete();
      await _flush(tester);
      expect(fixture.scheduler.permissionQueries, 2);
      expect(fixture.scheduler.cancelled, hasLength(4));
      expect(fixture.scheduler.ownPending('a'), isEmpty);
      expect(fixture.scheduler.ownPending('b'), hasLength(4));
      expect(
        fixture.scheduler.cancelled.every(
          (key) => key.startsWith('${AccountDataRegistry.accountDigest('a')}:'),
        ),
        isTrue,
      );
    },
  );

  testWidgets('new account ready during an old request still reconciles', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    final gate = Completer<void>();
    fixture.scheduler.nextQuery = gate.future;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await fixture.mount(tester);
    fixture.ready('b');
    gate.complete();
    await _flush(tester);
    expect(fixture.scheduler.permissionQueries, 2);
    expect(fixture.scheduler.ownPending('a'), hasLength(4));
    expect(fixture.scheduler.ownPending('b'), isEmpty);
  });

  testWidgets('disposed shell never dispatches queued account recovery', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.mount(tester, flush: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    expect(fixture.scheduler.permissionQueries, 0);
    expect(fixture.scheduler.cancelled, isEmpty);
  });

  testWidgets(
    'cancellation failure retains pending request and resume can retry',
    (tester) async {
      final fixture = await _Fixture.create();
      fixture.scheduler.failCancellation = true;
      await fixture.mount(tester);
      expect(fixture.scheduler.ownPending('a'), hasLength(4));
      expect(fixture.scheduler.scheduled, isEmpty);
      expect(tester.takeException(), isNull);
      fixture.scheduler.failCancellation = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(fixture.scheduler.ownPending('a'), isEmpty);
      fixture.expectPreferencesPreserved();
    },
  );
}

Future<void> _flush(WidgetTester tester) async {
  for (var n = 0; n < 16; n++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

final _scopeSource = NotifierProvider<_ScopeSource, AccountStorageScope>(
  _ScopeSource.new,
);

class _ScopeSource extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('a');
  void select(String user) => state = AccountStorageScope.authenticated(user);
}

class _Fixture {
  _Fixture(this.container, this.scheduler);
  final ProviderContainer container;
  final _Scheduler scheduler;
  static Future<_Fixture> create({
    bool ready = true,
    bool granted = false,
  }) async {
    final scheduler = _Scheduler()..granted = granted;
    final prefs = _MemoryPreferences();
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (ref) => ref.watch(_scopeSource),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        domainGoalRepositoryProvider.overrideWithValue(_Goals()),
        domainHabitRepositoryProvider.overrideWithValue(_Habits()),
        unreadNotificationsProvider.overrideWithValue(0),
        goalsProvider.overrideWith(_StaticGoals.new),
      ],
    );
    addTearDown(container.dispose);
    final fixture = _Fixture(container, scheduler);
    if (ready) fixture.ready('a');
    final scoped = container.read(accountSharedPrefsStoreProvider);
    for (final entry in <String, String>{
      'reflection_reminder_enabled': 'true',
      'reflection_reminder_time': '20:0',
      'daily_planning_reminder_enabled': 'true',
      'daily_planning_reminder_time': '7:30',
      'goal_reminders_enabled': 'true',
      'habit_reminders_enabled': 'true',
      'scheduled_goal_reminder_ids': '["prior-goal"]',
    }.entries) {
      await scoped.save(entry.key, entry.value);
    }
    scheduler.seed('a');
    scheduler.seed('b');
    return fixture;
  }

  void ready(String user) {
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(userId: user, isTransitioning: true);
    container.read(_scopeSource.notifier).select(user);
    boundary.markStorageReady(
      generation,
      legacyOwnership: LegacyScopeOwnership.provenNotOwned,
    );
    boundary.complete(generation);
  }

  Future<void> mount(
    WidgetTester tester, {
    bool flush = true,
    bool resumeBeforeDispatch = false,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NavigationShell()),
      ),
    );
    if (resumeBeforeDispatch) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    if (flush) await _flush(tester);
  }

  void expectPreferencesPreserved() {
    final scoped = container.read(accountSharedPrefsStoreProvider);
    expect(scoped.load('daily_planning_reminder_enabled'), 'true');
    expect(scoped.load('daily_planning_reminder_time'), '7:30');
    expect(scoped.load('reflection_reminder_enabled'), 'true');
    expect(scoped.load('reflection_reminder_time'), '20:0');
    expect(scoped.load('goal_reminders_enabled'), 'true');
    expect(scoped.load('habit_reminders_enabled'), 'true');
  }
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => [];
}

class _Goals implements IGoalRepository {
  @override
  List<GoalEntity> getGoals() => [
    GoalEntity(
      id: 'prior-goal',
      title: 'Fixture goal',
      createdAt: DateTime(2026),
      targetDate: DateTime.now().add(const Duration(days: 4)),
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Habits implements IHabitRepository {
  @override
  Future<List<HabitEntity>> getHabits() async => [
    HabitEntity(
      id: 'prior-habit',
      title: 'Fixture rhythm',
      cadence: HabitCadence.weekly,
      createdAt: DateTime(2026),
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryPreferences implements SharedPrefsStore {
  final Map<String, String> values = {};
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

typedef _Registration = ({String id, (int, int)? time, HabitCadence? cadence});

class _Scheduler implements NotificationScheduler {
  bool granted = false;
  bool failCancellation = false;
  int permissionQueries = 0;
  int permissionRequests = 0;
  Future<void>? nextQuery;
  final signal = ValueNotifier<bool?>(null);
  final pending = <String>{};
  final cancelled = <String>[];
  final scheduled = <_Registration>[];
  final dailyTimes = <String, (int, int)>{};
  void seed(String user) {
    for (final id in [
      'daily_planning_reminder',
      'reflection_reminder',
      'habit_reminder_daily',
      'goal_reminder_prior-goal',
    ]) {
      pending.add('${AccountDataRegistry.accountDigest(user)}:$id');
    }
  }

  Set<String> ownPending(String user) => pending
      .where(
        (key) => key.startsWith('${AccountDataRegistry.accountDigest(user)}:'),
      )
      .toSet();
  @override
  ValueListenable<bool?> get permissionStatusListenable => signal;
  @override
  Future<bool> init({bool requestPermissions = false}) async {
    if (requestPermissions) permissionRequests++;
    permissionQueries++;
    final gate = nextQuery;
    nextQuery = null;
    if (gate != null) await gate;
    signal.value = granted;
    return granted;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    if (failCancellation) throw StateError('Fixture OS cancellation failed');
    if (accountScope == null) {
      throw StateError('Unscoped cancellation forbidden');
    }
    final key = '$accountScope:$id';
    cancelled.add(key);
    pending.remove(key);
    dailyTimes.remove(key);
    return true;
  }

  @override
  Future<bool> cancelAll() async =>
      throw StateError('Global cancellation forbidden');
  @override
  Future<bool> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async {
    scheduled.add((id: id, time: (hour, minute), cadence: null));
    pending.add('$accountScope:$id');
    dailyTimes['$accountScope:$id'] = (hour, minute);
    return true;
  }

  @override
  Future<
    List<
      ({
        String id,
        String title,
        String body,
        int? hour,
        int? minute,
        HabitCadence? cadence,
        DateTime? firstScheduledLocal,
        bool cadenceMetadataMalformed,
      })
    >
  >
  pendingForAccount(String accountScope) async {
    final prefix = '$accountScope:';
    return [
      for (final key in pending.where((key) => key.startsWith(prefix)))
        (
          id: key.substring(prefix.length),
          title: 'Fixture reminder',
          body: '',
          hour: dailyTimes[key]?.$1,
          minute: dailyTimes[key]?.$2,
          cadence: null,
          firstScheduledLocal: null,
          cadenceMetadataMalformed: false,
        ),
    ];
  }

  @override
  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    scheduled.add((id: notification.id, time: null, cadence: null));
    pending.add('$accountScope:${notification.id}');
    return true;
  }

  @override
  Future<bool> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    scheduled.add((
      id: id,
      time: (firstAt.hour, firstAt.minute),
      cadence: cadence,
    ));
    pending.add('$accountScope:$id');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
