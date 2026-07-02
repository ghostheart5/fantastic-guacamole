import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';

class NotificationsService {
  NotificationsService(this.repo);

  final INotificationRepository repo;

  Future<List<NotificationEntity>> loadNotifications() async {
    final result = await repo.getNotifications();
    Logger.log('NotificationsService', 'Loaded ${result.length} notifications');
    return result;
  }

  Future<void> markRead(String id) async {
    Logger.log('NotificationsService', 'Marking read → $id');
    await repo.markRead(id);
  }

  Future<void> delete(String id) async {
    Logger.log('NotificationsService', 'Deleting → $id');
    await repo.delete(id);
  }
}
