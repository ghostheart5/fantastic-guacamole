import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/cancel_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CancelNotification delegates cancel call with id', () async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();

    await CancelNotification(repository).call('notif-1');

    expect(repository.canceledId, 'notif-1');
  });
}

class _FakeNotificationRepository implements INotificationRepository {
  String? canceledId;

  @override
  Future<void> cancelNotification(String id) async {
    canceledId = id;
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      <NotificationEntity>[];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
