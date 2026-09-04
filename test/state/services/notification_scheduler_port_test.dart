import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reflection reminders delegate through the scheduler port', () async {
    final _MemoryPreferences preferences = _MemoryPreferences();
    final _RecordingScheduler scheduler = _RecordingScheduler();
    final ReflectionReminderService service = ReflectionReminderService(
      preferences: preferences,
      scheduler: scheduler,
      permissionListenable: scheduler.permissionSignal,
      accountScope: 'account-scope',
    );

    expect(service.permissionListenable, same(scheduler.permissionSignal));
    expect(
      await service.setEnabled(
        enabled: true,
        time: const TimeOfDay(hour: 9, minute: 15),
      ),
      isTrue,
    );

    expect(preferences.load(ReflectionReminderService.enabledKey), 'true');
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.dailySchedules.single.id, 'reflection_reminder');
    expect(scheduler.dailySchedules.single.hour, 9);
    expect(scheduler.dailySchedules.single.minute, 15);
    expect(scheduler.dailySchedules.single.accountScope, 'account-scope');

    await service.setEnabled(
      enabled: false,
      time: const TimeOfDay(hour: 9, minute: 15),
    );
    expect(scheduler.cancelled, contains('reflection_reminder'));
  });

  test('daily planning orchestration uses the scheduler port', () async {
    final _MemoryPreferences preferences = _MemoryPreferences();
    final _RecordingScheduler scheduler = _RecordingScheduler();
    final _RecordingNotificationRepository notifications =
        _RecordingNotificationRepository();
    final ReminderOrchestratorService service = ReminderOrchestratorService(
      preferences: preferences,
      notifications: NotificationsService(notifications),
      scheduler: scheduler,
      accountScope: 'account-scope',
    );

    await service.ensureDailyPlanningReminder();
    expect(scheduler.dailySchedules.single.id, 'daily_planning_reminder');
    expect(scheduler.dailySchedules.single.hour, 7);
    expect(scheduler.dailySchedules.single.minute, 30);

    await service.setDailyPlanningReminder(enabled: false, hour: 8, minute: 45);
    expect(notifications.cancelled, contains('daily_planning_reminder'));
  });

  test(
    'notification cleanup clears platform navigation through the port',
    () async {
      final _RecordingScheduler scheduler = _RecordingScheduler();
      final NotificationsRepository repository = NotificationsRepository(
        scheduler,
        SecureStore(backend: InMemorySecureStoreBackend()),
        accountId: 'account-a',
      );

      await repository.clearAccountData();

      expect(scheduler.clearTappedPayloadCalls, 1);
      expect(
        scheduler.cancelled,
        containsAll(<String>[
          'habit_reminder_daily',
          'daily_planning_reminder',
          'reflection_reminder',
        ]),
      );
    },
  );
}

final class _MemoryPreferences implements SharedPrefsStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}

final class _RecordingScheduler implements NotificationSchedulerPort {
  final ValueNotifier<bool?> permissionSignal = ValueNotifier<bool?>(true);
  final List<_DailySchedule> dailySchedules = <_DailySchedule>[];
  final List<String> cancelled = <String>[];
  int permissionRequests = 0;
  int clearTappedPayloadCalls = 0;

  @override
  Future<bool> requestPermissions() async {
    permissionRequests += 1;
    return permissionSignal.value ?? false;
  }

  @override
  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => true;

  @override
  Future<bool> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async {
    dailySchedules.add(
      _DailySchedule(
        id: id,
        hour: hour,
        minute: minute,
        accountScope: accountScope,
      ),
    );
    return true;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    cancelled.add(id);
    return true;
  }

  @override
  Future<bool> cancelAll() async => true;

  @override
  void clearTappedPayload() {
    clearTappedPayloadCalls += 1;
  }
}

final class _DailySchedule {
  const _DailySchedule({
    required this.id,
    required this.hour,
    required this.minute,
    required this.accountScope,
  });

  final String id;
  final int hour;
  final int minute;
  final String? accountScope;
}

final class _RecordingNotificationRepository
    implements INotificationRepository {
  final List<String> cancelled = <String>[];

  @override
  Future<void> cancelNotification(String id) async {
    cancelled.add(id);
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
