import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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
  int _loadGeneration = 0;
  Future<void> _playCategoryAwareReminderSound(
    NotificationEntity notification,
  ) {
    final bool soundEnabled = ref.read(soundEnabledProvider);
    final bool advancedAudioEnabled = ref.read(
      advancedAudioProfileEnabledProvider,
    );
    final String title = notification.title.toLowerCase();
    final String message = notification.message.toLowerCase();
    final String combined = '$title $message';

    if (combined.contains('routine') || combined.contains('habit')) {
      return AudioService.playReminderRoutine(
        soundEnabled,
        advancedProfileEnabled: advancedAudioEnabled,
      );
    }

    if (combined.contains('daily') ||
        combined.contains('plan') ||
        combined.contains('reflection')) {
      return AudioService.playReminderDaily(
        soundEnabled,
        advancedProfileEnabled: advancedAudioEnabled,
      );
    }

    return AudioService.playNotification(
      soundEnabled,
      advancedProfileEnabled: advancedAudioEnabled,
    );
  }

  @override
  List<NotificationEntity> build() {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    final notificationRepository = ref.watch(
      domainNotificationRepositoryProvider,
    );
    final int generation = ++_loadGeneration;
    if (scope.isAuthenticated) {
      unawaited(_reloadForScope(notificationRepository, scope, generation));
    }

    return const <NotificationEntity>[];
  }

  Future<void> _reloadForScope(
    INotificationRepository repository,
    AccountStorageScope scope,
    int generation,
  ) async {
    try {
      final List<NotificationEntity> notifications = await repository
          .getNotifications();
      if (generation != _loadGeneration ||
          ref.read(accountStorageScopeProvider).v2Namespace !=
              scope.v2Namespace) {
        return;
      }
      state = notifications;
    } on Object {
      if (generation == _loadGeneration) {
        state = const <NotificationEntity>[];
      }
    }
  }

  Future<void> push(
    NotificationEntity notification, {
    bool refreshCoach = true,
    bool refreshPlan = true,
    bool playSound = true,
  }) async {
    await ref
        .read(domainNotificationRepositoryProvider)
        .scheduleNotification(notification);
    if (playSound) {
      await _playCategoryAwareReminderSound(notification);
    }
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

  Future<void> pushDecision(
    String taskTitle, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) {
    return push(
      _notification(
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
    final bool advancedAudioEnabled = ref.read(
      advancedAudioProfileEnabledProvider,
    );
    final bool hapticEnabled = ref.read(hapticFeedbackEnabledProvider);
    AudioService.playAchievement(
      soundEnabled,
      advancedProfileEnabled: advancedAudioEnabled,
      hapticsEnabled: hapticEnabled,
    );
    return push(
      _notification(
        title: 'Completion',
        message: '$taskTitle completed. Recomputing next move.',
      ),
      refreshCoach: refreshCoach,
      refreshPlan: refreshPlan,
      playSound: false,
    );
  }

  Future<void> pushTaskSkipped(
    String taskTitle, {
    bool refreshCoach = true,
    bool refreshPlan = true,
  }) {
    final bool soundEnabled = ref.read(soundEnabledProvider);
    final bool advancedAudioEnabled = ref.read(
      advancedAudioProfileEnabledProvider,
    );
    AudioService.playSkip(
      soundEnabled,
      advancedProfileEnabled: advancedAudioEnabled,
    );
    return push(
      _notification(
        title: 'Task Skipped',
        message: '$taskTitle skipped. SI will adapt the next pick.',
      ),
      refreshCoach: refreshCoach,
      refreshPlan: refreshPlan,
      playSound: false,
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
}
