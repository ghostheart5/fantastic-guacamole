import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// OS reminder text follows the app language, and a language change replaces
/// what the OS holds through the ordinary change-driven update.
void main() {
  final DateTime now = DateTime(2026, 11, 13, 14); // Friday afternoon.

  const spanish = <String, (String, String)>{
    'goal_reminder_g_3d': ('Meta próxima', '«Run a 5K» vence en 3 días.'),
    'goal_reminder_g': ('Meta para mañana', '«Run a 5K» vence mañana.'),
    'goal_reminder_g_due': ('Meta para hoy', '«Run a 5K» vence hoy.'),
    'goal_reminder_h_close': ('Ya casi', 'Queda un paso en «Read 4 books».'),
    'habit_reminder_walk': (
      'Evening walk',
      'Es hora de «Evening walk». Toca para registrarlo.',
    ),
    'daily_planning_reminder': (
      'Recordatorio de planificación diaria',
      'Abre Axiomara y elige un próximo paso manejable.',
    ),
  };
  const english = <String, (String, String)>{
    'goal_reminder_g_3d': ('Goal coming up', '"Run a 5K" is due in 3 days.'),
    'goal_reminder_g': ('Goal due tomorrow', '"Run a 5K" is due tomorrow.'),
    'goal_reminder_g_due': ('Goal due today', '"Run a 5K" is due today.'),
    'goal_reminder_h_close': (
      'Almost there',
      'One step left on "Read 4 books".',
    ),
    'habit_reminder_walk': (
      'Evening walk',
      'Time for "Evening walk". Tap to check in.',
    ),
    'daily_planning_reminder': (
      'Daily Planning Reminder',
      'Open Axiomara and choose one manageable next step.',
    ),
  };

  test('Spanish app language writes every reminder in Spanish, and a '
      'language change replaces each registration', () async {
    final fixture = _Fixture(now)..spanish = true;
    expect(await fixture.reconcile(), isTrue);
    expect(fixture.scheduler.texts, spanish);

    fixture.spanish = false;
    fixture.scheduler.registered.clear();
    expect(await fixture.reconcile(), isTrue);
    expect(fixture.scheduler.registered.toSet(), spanish.keys.toSet());
    expect(fixture.scheduler.texts, english);

    // Nothing changed since: nothing is registered again.
    fixture.scheduler.registered.clear();
    expect(await fixture.reconcile(), isTrue);
    expect(fixture.scheduler.registered, isEmpty);
  });

  test('the remaining goal texts and the step count are in Spanish', () {
    final fixture = _Fixture(now)..spanish = true;
    String closeBody(int done) => fixture.service
        .goalReminderSlots(
          GoalEntity(id: 'h', title: 'Read 4 books', createdAt: _created),
          progress: _progress(done: done, total: 4),
          progressKnown: true,
          now: now,
          previousNudges: {},
          nextNudges: {},
        )
        .single
        .body;
    expect(closeBody(4), contains('Todos los pasos de «Read 4 books» están'));
    expect(closeBody(3), 'Queda un paso en «Read 4 books».');

    final slots = fixture.service.goalReminderSlots(
      GoalEntity(
        id: 'g',
        title: 'Run a 5K',
        createdAt: _created,
        targetDate: DateTime(2026, 11, 23),
      ),
      progress: _progress(done: 1, total: 4),
      progressKnown: true,
      now: now,
      previousNudges: {},
      nextNudges: {},
    );
    expect(slots.last.body, '«Run a 5K» vence hoy. 1 de 4 pasos hechos.');
  });
}

GoalProgressView _progress({required int done, required int total}) =>
    GoalProgressView.fromTasks(_steps('any', done: done, total: total));

final DateTime _created = DateTime(2026, 11, 1);

List<TaskEntity> _steps(
  String goalId, {
  required int done,
  required int total,
}) => [
  for (var i = 0; i < total; i++)
    TaskEntity(
      id: '$goalId-step-$i',
      title: 'Step $i',
      goalId: goalId,
      isCompleted: i < done,
    ),
];

class _Fixture {
  _Fixture(this.now) {
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
  }

  final DateTime now;
  bool spanish = false;
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(_Repository()),
    scheduler: scheduler,
    accountScope: 'qa',
    now: () => now,
    timeZoneName: () => 'Etc/UTC',
    loadHabitOccurrences: () async => [],
    loadGoalTasks: () async => _steps('h', done: 3, total: 4),
    isSpanish: () => spanish,
  );

  Future<bool> reconcile() => service.reconcileAfterRestore(
    goals: [
      GoalEntity(
        id: 'g',
        title: 'Run a 5K',
        createdAt: _created,
        targetDate: DateTime(2026, 11, 23),
      ),
      GoalEntity(id: 'h', title: 'Read 4 books', createdAt: _created),
    ],
    habits: [
      HabitEntity(
        id: 'walk',
        title: 'Evening walk',
        createdAt: DateTime(2026, 11, 1),
        reminderMinutes: 17 * 60,
      ),
    ],
    permissionGranted: true,
    shouldContinue: () => true,
  );
}

class _Preferences implements SharedPrefsStore {
  final values = <String, String>{};
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

/// Records what the OS would show for each registered id.
class _Scheduler implements NotificationSchedulerPort {
  final texts = <String, (String, String)>{};
  final registered = <String>[];

  NotificationScheduleResult _record(String id, String title, String body) {
    registered.add(id);
    texts[id] = (title, body);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async =>
      _record(notification.id, notification.title, notification.message);

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => _record(id, title, body);

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async => _record(id, title, body);

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    texts.remove(id);
    return true;
  }

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      texts.keys.toList();
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> cancelAll() async => true;
  @override
  void clearTappedPayload() {}
}

class _Repository implements INotificationRepository {
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
