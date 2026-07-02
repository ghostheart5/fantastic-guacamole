import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationManager extends AsyncNotifier<List<NotificationEntity>> {
  @override
  Future<List<NotificationEntity>> build() async => <NotificationEntity>[];

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => await build());
  }

  Future<void> markRead(String id) async {
    final List<NotificationEntity> current =
        state.asData?.value ?? <NotificationEntity>[];
    state = AsyncData(
      current
          .map(
            (NotificationEntity item) => item.id == id
                ? NotificationEntity(
                    id: item.id,
                    title: item.title,
                    message: item.message,
                    scheduledAt: item.scheduledAt,
                    isEnabled: item.isEnabled,
                    isRead: true,
                  )
                : item,
          )
          .toList(growable: false),
    );
  }

  Future<void> delete(String id) async {
    final List<NotificationEntity> current =
        state.asData?.value ?? <NotificationEntity>[];
    state = AsyncData(
      current
          .where((NotificationEntity item) => item.id != id)
          .toList(growable: false),
    );
  }
}

final notificationManagerProvider =
    AsyncNotifierProvider<NotificationManager, List<NotificationEntity>>(
      NotificationManager.new,
    );
