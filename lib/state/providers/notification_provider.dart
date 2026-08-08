import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationActionsProvider = Provider<NotificationActions>((Ref ref) {
  return NotificationActions(ref);
});

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<NotificationEntity>>(
      NotificationNotifier.new,
    );

final unreadNotificationsProvider = Provider<int>(
  (Ref ref) => ref
      .watch(notificationProvider)
      .where((NotificationEntity item) => !item.isRead)
      .length,
);

class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  Future<void> push(NotificationEntity notification) {
    return _ref.read(notificationProvider.notifier).push(notification);
  }

  Future<void> pushMirroredDecision(String taskTitle) {
    return _ref
        .read(notificationProvider.notifier)
        .pushDecision(taskTitle, refreshCoach: false, refreshPlan: true);
  }

  Future<void> pushMirroredCompletionFeedback(String taskTitle) {
    return _ref
        .read(notificationProvider.notifier)
        .pushCompletionFeedback(
          taskTitle,
          refreshCoach: false,
          refreshPlan: true,
        );
  }

  Future<void> pushMirroredTaskSkipped(String taskTitle) {
    return _ref
        .read(notificationProvider.notifier)
        .pushTaskSkipped(taskTitle, refreshCoach: false, refreshPlan: true);
  }
}

class NotificationNotifier extends Notifier<List<NotificationEntity>> {
  @override
  List<NotificationEntity> build() {
    final notificationRepository = ref.read(
      domainNotificationRepositoryProvider,
    );
    bool disposed = false;
    ref.onDispose(() {
      disposed = true;
    });

    Future<void>(() async {
      final List<NotificationEntity> notifications =
          await notificationRepository.getNotifications();

      if (disposed) {
        return;
      }

      final Map<String, NotificationEntity> mergedById =
          <String, NotificationEntity>{
            for (final NotificationEntity item in notifications) item.id: item,
          };

      for (final NotificationEntity item in state) {
        mergedById[item.id] = item;
      }

      final List<NotificationEntity> merged =
          mergedById.values.toList(growable: false)..sort(
            (NotificationEntity a, NotificationEntity b) =>
                b.scheduledAt.compareTo(a.scheduledAt),
          );

      state = merged;
    });

    return const <NotificationEntity>[];
  }

  Future<void> push(
    NotificationEntity notification, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) async {
    await ref.read(scheduleNotificationUseCaseProvider).call(notification);
    final bool soundEnabled = ref.read(soundEnabledProvider);
    await AudioService.playNotification(soundEnabled);
    state = <NotificationEntity>[notification, ...state];

    if (refreshPlan) {
      ref.invalidate(tasksProvider);
    }
    if (refreshCoach) {
      await _refreshCoachDecision();
    }
    ref
        .read(eventBusProvider)
        .emit(
          NotificationLifecycleEvent(
            notificationId: notification.id,
            title: notification.title,
            action: 'scheduled',
          ),
        );
  }

  /// Records an in-app-only notification.
  ///
  /// Identical to [push] except it never asks the OS to post anything. The
  /// entity is persisted (so it appears in the in-app list) with
  /// `isEnabled: false`, which `NotificationScheduler.schedule` treats as
  /// "in-app only". Used for transient interaction feedback — task decision,
  /// completion, skip — which previously each produced a real system
  /// notification one second later.
  Future<void> pushInApp(
    NotificationEntity notification, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) async {
    // Straight to the repository: ScheduleNotification enforces
    // NotificationPolicy.canSchedule, which correctly rejects a disabled
    // entity, so the use case is not the right path for an in-app record.
    await ref
        .read(domainNotificationRepositoryProvider)
        .scheduleNotification(notification);
    final bool soundEnabled = ref.read(soundEnabledProvider);
    await AudioService.playNotification(soundEnabled);
    state = <NotificationEntity>[notification, ...state];

    if (refreshPlan) {
      ref.invalidate(tasksProvider);
    }
    if (refreshCoach) {
      await _refreshCoachDecision();
    }
    ref
        .read(eventBusProvider)
        .emit(
          NotificationLifecycleEvent(
            notificationId: notification.id,
            title: notification.title,
            action: 'in_app',
          ),
        );
  }

  Future<void> pushDecision(
    String taskTitle, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) {
    return pushInApp(
      _inAppNotification(
        title: 'Decision Alert',
        message: 'Selected $taskTitle as the current focus target.',
      ),
      refreshCoach: refreshCoach,
      refreshPlan: refreshPlan,
    );
  }

  Future<void> pushCompletionFeedback(
    String taskTitle, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) {
    final bool soundEnabled = ref.read(soundEnabledProvider);
    AudioService.playAchievement(soundEnabled);
    return pushInApp(
      _inAppNotification(
        title: 'Completion',
        message: '$taskTitle completed. Recomputing next move.',
      ),
      refreshCoach: refreshCoach,
      refreshPlan: refreshPlan,
    );
  }

  Future<void> pushTaskSkipped(
    String taskTitle, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) {
    return pushInApp(
      _inAppNotification(
        title: 'Task Skipped',
        message: '$taskTitle skipped. SI will adapt the next pick.',
      ),
      refreshCoach: refreshCoach,
      refreshPlan: refreshPlan,
    );
  }

  Future<void> markRead(String id) async {
    await ref.read(domainNotificationRepositoryProvider).markRead(id);
    state = state
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
        .toList(growable: false);
  }

  Future<void> delete(String id) async {
    await ref.read(cancelNotificationUseCaseProvider).call(id);
    await ref.read(domainNotificationRepositoryProvider).delete(id);
    String title = 'Notification';
    for (final NotificationEntity item in state) {
      if (item.id == id) {
        title = item.title;
        break;
      }
    }
    state = state
        .where((NotificationEntity item) => item.id != id)
        .toList(growable: false);
    ref
        .read(eventBusProvider)
        .emit(
          NotificationLifecycleEvent(
            notificationId: id,
            title: title,
            action: 'deleted',
          ),
        );
  }

  void clear() => state = const <NotificationEntity>[];

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking notification scheduling if coach refresh fails.
    }
  }

  /// Factory for a real, OS-scheduled notification.
  ///
  /// Retained deliberately: this is the correct shape for an actual reminder
  /// (enabled, scheduled in the future) and is the counterpart to
  /// [_inAppNotification]. It is currently unreferenced only because the three
  /// interaction-feedback callers were moved to the in-app path; any future
  /// reminder pushed through [push] should use this.
  // ignore: unused_element
  NotificationEntity _notification({
    required String title,
    required String message,
  }) {
    final DateTime now = DateTime.now();
    return NotificationEntity(
      id: 'notification-${now.microsecondsSinceEpoch}',
      title: title,
      message: message,
      scheduledAt: now.add(const Duration(seconds: 1)),
    );
  }

  /// In-app-only counterpart of [_notification].
  ///
  /// `isEnabled: false` marks it as never-to-be-posted by the OS, and
  /// `scheduledAt` is now rather than a second in the future because there is
  /// no future delivery to schedule.
  NotificationEntity _inAppNotification({
    required String title,
    required String message,
  }) {
    final DateTime now = DateTime.now();
    return NotificationEntity(
      id: 'notification-${now.microsecondsSinceEpoch}',
      title: title,
      message: message,
      scheduledAt: now,
      isEnabled: false,
    );
  }
}
