import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/notifications/managers/notification_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationController {
  const NotificationController(this._ref);

  final Ref _ref;

  AsyncValue<List<NotificationEntity>> watch() {
    return _ref.watch(notificationManagerProvider);
  }

  Future<void> refresh() {
    return _ref.read(notificationManagerProvider.notifier).refresh();
  }

  Future<void> markRead(String id) {
    return _ref.read(notificationManagerProvider.notifier).markRead(id);
  }

  Future<void> delete(String id) {
    return _ref.read(notificationManagerProvider.notifier).delete(id);
  }
}

final notificationControllerProvider = Provider<NotificationController>(
  (Ref ref) => NotificationController(ref),
);
