import 'package:fantastic_guacamole/features/notifications/repositories/notifications_repository.dart';

class NotificationsService {
  NotificationsService(this._repository);

  final NotificationsRepository _repository;

  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _repository.scheduleNotification(
      id: id,
      title: title,
      body: body,
      at: at,
    );
  }

  Future<void> cancel(String id) async {
    await _repository.cancelNotification(id);
  }

  Future<void> cancelAll() async {
    await _repository.cancelAll();
  }
}
