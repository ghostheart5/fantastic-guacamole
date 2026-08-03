import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
void main() {
  group('settings integration flow', () {
    test('settings actions delegate reminder and planning updates', () async {
      final _FakeReflectionReminderService reminder =
          _FakeReflectionReminderService();
      final _FakeReminderOrchestratorService orchestrator =
          _FakeReminderOrchestratorService();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          reflectionReminderServiceProvider.overrideWithValue(reminder),
          reminderOrchestratorServiceProvider.overrideWithValue(orchestrator),
        ],
      );
      addTearDown(container.dispose);

      final SettingsUiActions actions = container.read(settingsUiActionsProvider);
      final bool enabled = await actions.setReflectionReminderEnabled(
        enabled: true,
        time: const TimeOfDay(hour: 20, minute: 30),
      );
      await actions.setDailyPlanningReminder(
        enabled: true,
        time: const TimeOfDay(hour: 7, minute: 45),
      );

      expect(enabled, isTrue);
      expect(reminder.lastEnabled, isTrue);
      expect(reminder.lastEnabledTime?.hour, 20);
      expect(reminder.lastEnabledTime?.minute, 30);
      expect(orchestrator.lastDailyPlanningEnabled, isTrue);
      expect(orchestrator.lastDailyPlanningHour, 7);
      expect(orchestrator.lastDailyPlanningMinute, 45);
    });

    test('openSystemAppSettings falls back to second URI candidate', () async {
      final _FakeExternalUrlService external = _FakeExternalUrlService(
        accepted: <String>{'app-prefs:root'},
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          externalUrlServiceProvider.overrideWithValue(external),
        ],
      );
      addTearDown(container.dispose);

      final bool opened = await container
          .read(settingsUiActionsProvider)
          .openSystemAppSettings();

      expect(opened, isTrue);
      expect(external.openedUris.length, 2);
      expect(external.openedUris.first.toString(), 'app-settings:');
      expect(external.openedUris.last.toString(), 'app-prefs:root');
    });

    test('notification permission snapshot reflects reminder service state', () async {
      final _FakeReflectionReminderService reminder =
          _FakeReflectionReminderService(
            initialGranted: false,
            permissionState: NotificationPermissionState.denied,
          );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          reflectionReminderServiceProvider.overrideWithValue(reminder),
        ],
      );
      addTearDown(container.dispose);

      final NotificationPermissionSnapshot before = await container
          .read(notificationPermissionProvider.notifier)
          .refresh();
      expect(before.granted, isFalse);
      expect(before.permissionState, NotificationPermissionState.denied);

      reminder.setGranted(true, NotificationPermissionState.granted);
      final NotificationPermissionSnapshot after = await container
          .read(notificationPermissionProvider.notifier)
          .requestPermission();

      expect(after.granted, isTrue);
      expect(after.permissionState, NotificationPermissionState.granted);
      expect(after.isGranted, isTrue);
    });
  });
}

class _InMemoryPrefsStore implements SharedPrefsStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  String? load(String key) => _store[key];

  @override
  Future<void> save(String key, String value) async {
    _store[key] = value;
  }
}

class _FakeNotificationRepository implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    return const <NotificationEntity>[];
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}

class _FakeReflectionReminderService extends ReflectionReminderService {
  _FakeReflectionReminderService({
    bool? initialGranted,
    this._permissionState = NotificationPermissionState.unknown,
  }) : _permission = ValueNotifier<bool?>(initialGranted),
       super(
         preferences: _InMemoryPrefsStore(),
         scheduler: NotificationScheduler(),
       );

  final ValueNotifier<bool?> _permission;
  NotificationPermissionState _permissionState;
  bool? lastEnabled;
  TimeOfDay? lastEnabledTime;

  @override
  ValueListenable<bool?> get permissionListenable => _permission;

  void setGranted(bool granted, NotificationPermissionState state) {
    _permission.value = granted;
    _permissionState = state;
  }

  @override
  ReflectionReminderPrefs loadPrefs() {
    return const ReflectionReminderPrefs(
      enabled: false,
      time: TimeOfDay(hour: 20, minute: 0),
    );
  }

  @override
  Future<bool> setEnabled({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    lastEnabled = enabled;
    lastEnabledTime = time;
    return enabled;
  }

  @override
  Future<void> setTime({required TimeOfDay time}) async {}

  @override
  Future<NotificationPermissionState>
  requestNotificationPermissionDetailed() async {
    return _permissionState;
  }

  @override
  Future<NotificationPermissionState> getNotificationPermissionState() async {
    return _permissionState;
  }
}

class _FakeReminderOrchestratorService extends ReminderOrchestratorService {
  _FakeReminderOrchestratorService()
    : super(
        preferences: _InMemoryPrefsStore(),
        notifications: NotificationsService(_FakeNotificationRepository()),
        scheduler: NotificationScheduler(),
      );

  bool? lastDailyPlanningEnabled;
  int? lastDailyPlanningHour;
  int? lastDailyPlanningMinute;

  @override
  ReminderOrchestratorPrefs loadPrefs() {
    return const ReminderOrchestratorPrefs(
      goalRemindersEnabled: true,
      habitRemindersEnabled: true,
      dailyPlanningEnabled: true,
      dailyPlanningHour: 7,
      dailyPlanningMinute: 30,
    );
  }

  @override
  Future<void> setGoalRemindersEnabled(bool enabled) async {}

  @override
  Future<void> setHabitRemindersEnabled(bool enabled) async {}

  @override
  Future<void> setDailyPlanningReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    lastDailyPlanningEnabled = enabled;
    lastDailyPlanningHour = hour;
    lastDailyPlanningMinute = minute;
  }
}

class _FakeExternalUrlService extends ExternalUrlService {
  _FakeExternalUrlService({required this.accepted});

  final Set<String> accepted;
  final List<Uri> openedUris = <Uri>[];

  @override
  Future<bool> open(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    openedUris.add(uri);
    return accepted.contains(uri.toString());
  }
}
