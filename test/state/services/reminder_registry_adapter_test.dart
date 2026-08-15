import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final a = AccountStorageScope.authenticated('A');
  final b = AccountStorageScope.authenticated('B');

  test('isolates A and B registry entries', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    final service = _service(prefs, repo, a);
    await service.registerScheduledReminder(scope: a, id: 'reminder.goal.${a.v2Namespace}.same');
    await service.registerScheduledReminder(scope: b, id: 'reminder.goal.${b.v2Namespace}.same');
    expect(_ids(prefs, a), hasLength(1));
    expect(_ids(prefs, b), hasLength(1));
    expect(_ids(prefs, b).single, isNot(_ids(prefs, a).single));
  });

  test('single cancellation removes only after success and retries after failure', () async {
    final prefs = _Prefs();
    final repo = _Repo()..fail = true;
    final service = _service(prefs, repo, a);
    const id = 'reminder.goal.a.one';
    await service.registerScheduledReminder(scope: a, id: id);
    await expectLater(service.cancelRegisteredReminder(scope: a, id: id), throwsStateError);
    expect(_ids(prefs, a), contains(id));
    repo.fail = false;
    await service.cancelRegisteredReminder(scope: a, id: id);
    expect(repo.cancelled, <String>[id, id]);
    expect(_ids(prefs, a), isEmpty);
  });

  test('kind cancellation preserves other scopes and partial-failure evidence', () async {
    final prefs = _Prefs();
    final repo = _Repo()..failIds.add('reminder.goal.a.two');
    final service = _service(prefs, repo, a);
    for (final id in <String>['reminder.goal.a.one', 'reminder.goal.a.two', 'reminder.habit.a.keep']) {
      await service.registerScheduledReminder(scope: a, id: id);
    }
    await service.registerScheduledReminder(scope: b, id: 'reminder.goal.b.one');
    await expectLater(service.cancelRegisteredKind(scope: a, kind: 'goal'), throwsStateError);
    expect(_ids(prefs, a), containsAll(<String>['reminder.goal.a.two', 'reminder.habit.a.keep']));
    expect(_ids(prefs, a), isNot(contains('reminder.goal.a.one')));
    expect(_ids(prefs, b), <String>['reminder.goal.b.one']);
  });

  test('registry survives service recreation and A cancellation cannot remove B', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    const aId = 'reminder.goal.a.same';
    const bId = 'reminder.goal.b.same';
    await _service(prefs, repo, a).registerScheduledReminder(scope: a, id: aId);
    await _service(prefs, repo, b).registerScheduledReminder(scope: b, id: bId);
    final restarted = _service(prefs, repo, a);
    expect(_ids(prefs, a), <String>[aId]);
    await restarted.cancelRegisteredReminder(scope: a, id: aId);
    expect(_ids(prefs, a), isEmpty);
    expect(_ids(prefs, b), <String>[bId]);
  });
}

ReminderOrchestratorService _service(_Prefs prefs, _Repo repo, AccountStorageScope scope) => ReminderOrchestratorService(
  preferences: prefs,
  notifications: NotificationsService(repo),
  scheduler: NotificationScheduler(),
  storageScope: scope,
);

List<String> _ids(_Prefs prefs, AccountStorageScope scope) => (jsonDecode(prefs.values['reminder_schedule_registry_v2.${scope.v2Namespace}'] ?? '[]') as List).cast<String>();

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override Future<void> clear() async => values.clear();
  @override Future<void> delete(String key) async => values.remove(key);
  @override Future<void> init() async {}
  @override String? load(String key) => values[key];
  @override Future<void> save(String key, String value) async => values[key] = value;
}

class _Repo implements INotificationRepository {
  bool fail = false;
  final Set<String> failIds = <String>{};
  final List<String> cancelled = <String>[];
  @override Future<void> cancelNotification(String id) async { cancelled.add(id); if (fail || failIds.contains(id)) throw StateError('cancel $id'); }
  @override Future<void> delete(String id) async {}
  @override Future<List<NotificationEntity>> getNotifications() async => <NotificationEntity>[];
  @override Future<void> markRead(String id) async {}
  @override Future<void> scheduleNotification(NotificationEntity notification) async {}
}
