import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// A device whose notification permission the test controls. Nothing here
/// touches a platform channel.
class FakePermissionScheduler implements NotificationScheduler {
  bool granted = false;
  int queries = 0;
  final ValueNotifier<bool?> signal = ValueNotifier<bool?>(null);

  @override
  ValueListenable<bool?> get permissionStatusListenable => signal;

  @override
  Future<bool> init({bool requestPermissions = false}) async {
    if (requestPermissions) {
      throw StateError('Only the Settings actions may show the OS dialog.');
    }
    queries++;
    signal.value = granted;
    return granted;
  }

  NotificationScheduleResult get _result => granted
      ? NotificationScheduleResult.scheduled
      : NotificationScheduleResult.permissionDenied;

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => _result;

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => _result;

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async => _result;

  @override
  Future<bool> cancel(String id, {String? accountScope}) async => true;

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      const <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what the permission flow asks of Settings.
class FakePermissionActions extends SettingsUiActions {
  FakePermissionActions(super.ref, this.scheduler);

  final FakePermissionScheduler scheduler;
  bool grantOnRequest = false;
  int requests = 0;
  int refreshes = 0;
  int settingsOpened = 0;
  ReminderOrchestratorPrefs reminderPrefs = const ReminderOrchestratorPrefs(
    goalRemindersEnabled: true,
    habitRemindersEnabled: true,
    dailyPlanningEnabled: true,
    dailyPlanningHour: 7,
    dailyPlanningMinute: 30,
  );
  bool reflectionEnabled = false;

  @override
  Future<bool> requestNotificationPermission() async {
    requests++;
    scheduler.granted = grantOnRequest;
    scheduler.signal.value = grantOnRequest;
    return grantOnRequest;
  }

  @override
  Future<void> refreshNotificationPermissionAndReminders() async {
    refreshes++;
  }

  @override
  ReminderOrchestratorPrefs loadAdvancedReminderPrefs() => reminderPrefs;

  @override
  ReflectionReminderPrefs loadReflectionReminderPrefs() =>
      ReflectionReminderPrefs(
        enabled: reflectionEnabled,
        time: const TimeOfDay(hour: 20, minute: 0),
      );

  @override
  Future<bool> openSystemAppSettings() async {
    settingsOpened++;
    return true;
  }
}

class MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

final permissionTestAccount =
    NotifierProvider<PermissionTestAccount, AccountStorageScope>(
      PermissionTestAccount.new,
    );

class PermissionTestAccount extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('a');
  void select(String user) => state = AccountStorageScope.authenticated(user);
}

class PermissionFixture {
  PermissionFixture._(this.container, this.scheduler, this.prefs);

  factory PermissionFixture({List<Override> overrides = const <Override>[]}) {
    final scheduler = FakePermissionScheduler();
    final prefs = MemoryPrefs();
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (ref) => ref.watch(permissionTestAccount),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        settingsUiActionsProvider.overrideWith(
          (ref) => FakePermissionActions(ref, scheduler),
        ),
        notificationPermissionListenableProvider.overrideWithValue(
          scheduler.signal,
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return PermissionFixture._(container, scheduler, prefs);
  }

  final ProviderContainer container;
  final FakePermissionScheduler scheduler;
  final MemoryPrefs prefs;

  FakePermissionActions get actions =>
      container.read(settingsUiActionsProvider) as FakePermissionActions;

  void selectAccount(String user) =>
      container.read(permissionTestAccount.notifier).select(user);

  Widget app(Widget home, {bool spanish = false}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: Locale(spanish ? 'es' : 'en'),
      supportedLocales: ChronoSparkLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ChronoSparkLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}
