import 'dart:async';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/providers/automation_schedule_projection.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationActionsProvider = Provider<NotificationActions>((Ref ref) {
  return NotificationActions(ref);
});

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<NotificationEntity>>(
      NotificationNotifier.new,
    );

/// Daily automations bypass the one-shot notification repository. Read their
/// actual OS registrations instead of treating enabled preferences as evidence.
class AutomationNotification extends NotificationEntity {
  const AutomationNotification({
    required super.id,
    required super.title,
    required super.message,
    required super.scheduledAt,
    required this.registeredTimeKnown,
    this.cadence,
  });
  final bool registeredTimeKnown;
  final HabitCadence? cadence;
}

final automationNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationEntity>>((ref) async {
      final scope = ref.watch(accountStorageScopeProvider);
      if (!scope.isWritable || scope.rawUserId == null) return const [];
      final owner = AccountOperation.capture(ref);
      final prefs = ref.read(reminderOrchestratorServiceProvider).loadPrefs();
      final reflection = ref
          .read(reflectionReminderServiceProvider)
          .loadPrefs();
      final pending = await owner.wait(
        ref
            .read(notificationSchedulerProvider)
            .pendingForAccount(
              AccountDataRegistry.accountDigest(scope.rawUserId!),
            ),
      );
      final now = DateTime.now();
      DateTime next(int hour, int minute) {
        final today = DateTime(now.year, now.month, now.day, hour, minute);
        return today.isAfter(now)
            ? today
            : DateTime(now.year, now.month, now.day + 1, hour, minute);
      }

      return [
        for (final item in pending)
          if (item.id == 'daily_planning_reminder' ||
              item.id.startsWith('habit_reminder_') ||
              item.id == 'reflection_reminder')
            AutomationNotification(
              registeredTimeKnown:
                  item.hour != null &&
                  item.minute != null &&
                  !item.cadenceMetadataMalformed,
              cadence: item.cadence,
              id: item.id,
              title: item.title,
              message: item.body,
              scheduledAt:
                  item.hour != null &&
                      item.minute != null &&
                      !item.cadenceMetadataMalformed
                  ? nextRegisteredAutomationTime(
                      now: now,
                      hour: item.hour!,
                      minute: item.minute!,
                      cadence: item.cadence,
                      firstScheduledLocal: item.firstScheduledLocal,
                    )
                  : switch (item.id) {
                      'daily_planning_reminder' => next(
                        prefs.dailyPlanningHour,
                        prefs.dailyPlanningMinute,
                      ),
                      'reflection_reminder' => next(
                        reflection.time.hour,
                        reflection.time.minute,
                      ),
                      _ => next(20, 0),
                    },
            ),
      ];
    });

/// The reminders the OS holds for this account right now, and whether
/// notifications are allowed. A stored reminder reads "Scheduled" only when
/// its id is in [ids]: the reminder updater registers and clears reminders
/// without rewriting the stored list.
class RegisteredReminders {
  const RegisteredReminders({
    required this.ids,
    required this.permissionGranted,
  });

  final Set<String> ids;

  /// Null when not known.
  final bool? permissionGranted;
}

final registeredRemindersProvider =
    FutureProvider.autoDispose<RegisteredReminders>((ref) async {
      // Read again whenever the list changes.
      ref.watch(notificationProvider);
      final scope = ref.watch(accountStorageScopeProvider);
      if (!scope.isWritable || scope.rawUserId == null) {
        return const RegisteredReminders(
          ids: <String>{},
          permissionGranted: null,
        );
      }
      final owner = AccountOperation.capture(ref);
      final scheduler = ref.read(notificationSchedulerProvider);
      final pending = await owner.wait(
        scheduler.pendingForAccount(
          AccountDataRegistry.accountDigest(scope.rawUserId!),
        ),
      );
      return RegisteredReminders(
        ids: <String>{for (final item in pending) item.id},
        permissionGranted: scheduler.permissionStatusListenable.value,
      );
    });

/// How a stored entry reads in the notification list.
enum NotificationListStatus {
  /// In-app history; never handed to the OS.
  inApp,

  /// A reminder whose time has passed: it went off (or was due), so it is
  /// past activity whether or not it was later switched off.
  past,

  /// A future reminder the OS holds.
  scheduled,

  /// A future reminder the OS does not hold.
  notScheduled,

  /// A future reminder whose OS state could not be read; claimed neither way.
  unconfirmed,
}

NotificationListStatus notificationListStatus(
  NotificationEntity item, {
  required DateTime now,
  required RegisteredReminders? registered,
}) {
  final bool reminder =
      item.isEnabled || NotificationEntity.isReminderId(item.id);
  if (!reminder) return NotificationListStatus.inApp;
  if (!item.scheduledAt.isAfter(now)) return NotificationListStatus.past;
  // Switched off before its time (older builds kept such rows).
  if (!item.isEnabled) return NotificationListStatus.notScheduled;
  if (registered == null) {
    final NotificationScheduleResult? stored = item.scheduleResult;
    return stored == null || stored == NotificationScheduleResult.scheduled
        ? NotificationListStatus.unconfirmed
        : NotificationListStatus.notScheduled;
  }
  return registered.ids.contains(item.id)
      ? NotificationListStatus.scheduled
      : NotificationListStatus.notScheduled;
}

/// Why a reminder is not scheduled, or null when that is not known.
/// Notifications being off now outranks what was stored earlier.
NotificationScheduleResult? notScheduledReason(
  NotificationEntity item,
  RegisteredReminders? registered,
) {
  if (registered?.permissionGranted == false) {
    return NotificationScheduleResult.permissionDenied;
  }
  final NotificationScheduleResult? stored = item.scheduleResult;
  return stored == NotificationScheduleResult.scheduled ? null : stored;
}

/// The one definition of "new" shared by the list and the badge: unread and
/// no longer waiting for its time. In-app entries and reminders that went
/// off count; future and switched-off reminders do not.
bool isNewNotificationActivity(NotificationEntity item, DateTime now) =>
    !item.isRead &&
    (!item.scheduledAt.isAfter(now) ||
        (!item.isEnabled && !NotificationEntity.isReminderId(item.id)));

/// The time used to decide which notifications are new. Tests override it.
final notificationClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

/// The badge count. It depends on the time, so it re-evaluates itself when
/// the next unread reminder comes due; the shell also invalidates it on
/// resume, when timers may have been held back. The timer is cancelled
/// whenever the provider is rebuilt or disposed, including on an account
/// change (the notification list rebuilds then).
final unreadNotificationsProvider = Provider<int>((Ref ref) {
  final DateTime now = ref.watch(notificationClockProvider)();
  final List<NotificationEntity> items = ref.watch(notificationProvider);
  int count = 0;
  DateTime? nextDue;
  for (final NotificationEntity item in items) {
    if (item.isRead) continue;
    if (isNewNotificationActivity(item, now)) {
      count++;
    } else if (item.scheduledAt.isAfter(now) &&
        (nextDue == null || item.scheduledAt.isBefore(nextDue))) {
      nextDue = item.scheduledAt;
    }
  }
  if (nextDue != null) {
    final Timer timer = Timer(nextDue.difference(now), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return count;
});

class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  Future<void> push(NotificationEntity notification) {
    return _ref.read(notificationProvider.notifier).push(notification);
  }

  Future<void> pushMirroredCompletionFeedback(String taskTitle) {
    return _ref
        .read(notificationProvider.notifier)
        .pushCompletionFeedback(
          taskTitle,
          refreshPlanner: false,
          refreshPlan: true,
        );
  }

  Future<void> pushMirroredTaskSkipped(String taskTitle) {
    return _ref
        .read(notificationProvider.notifier)
        .pushTaskSkipped(taskTitle, refreshPlanner: false, refreshPlan: true);
  }

  /// In-app only: a completed goal is acknowledged in the notification list,
  /// never by the OS.
  Future<void> pushMirroredGoalCompleted(String goalTitle) {
    return _ref
        .read(notificationProvider.notifier)
        .pushInApp(
          NotificationNotifier.goalCompleted(goalTitle),
          refreshPlanner: false,
          refreshPlan: false,
        );
  }
}

class NotificationNotifier extends Notifier<List<NotificationEntity>> {
  late INotificationRepository _repository;
  int _generation = 0;

  @override
  List<NotificationEntity> build() {
    final INotificationRepository notificationRepository = ref.watch(
      domainNotificationRepositoryProvider,
    );
    _repository = notificationRepository;
    final int generation = ++_generation;
    bool disposed = false;
    ref.onDispose(() {
      disposed = true;
    });

    unawaited(
      Future<void>(() async {
        final List<NotificationEntity> notifications =
            await notificationRepository.getNotifications();

        if (disposed || !_isCurrent(generation, notificationRepository)) {
          return;
        }

        final Map<String, NotificationEntity> mergedById =
            <String, NotificationEntity>{
              for (final NotificationEntity item in notifications)
                item.id: item,
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
      }),
    );

    return const <NotificationEntity>[];
  }

  Future<void> push(
    NotificationEntity notification, {
    bool refreshPlanner = true,
    bool refreshPlan = true,
  }) async {
    final int generation = _generation;
    final INotificationRepository repository = _repository;
    final scheduleNotification = ref.read(scheduleNotificationUseCaseProvider);
    await scheduleNotification.call(notification);
    if (!_isCurrent(generation, repository)) return;
    final bool soundEnabled = ref.read(soundEnabledProvider);
    await AudioService.playNotification(soundEnabled);
    state = <NotificationEntity>[notification, ...state];

    if (refreshPlan) {
      ref.invalidate(tasksProvider);
    }
    if (refreshPlanner) {
      await _refreshPlannerDecision();
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
  /// "in-app only". Used for transient interaction feedback — completion,
  /// skip — which previously each produced a real system notification one
  /// second later.
  Future<void> pushInApp(
    NotificationEntity notification, {
    bool refreshPlanner = true,
    bool refreshPlan = true,
  }) async {
    // Straight to the repository: ScheduleNotification enforces
    // NotificationPolicy.canSchedule, which correctly rejects a disabled
    // entity, so the use case is not the right path for an in-app record.
    final int generation = _generation;
    final INotificationRepository repository = _repository;
    await repository.scheduleNotification(notification);
    if (!_isCurrent(generation, repository)) return;
    final bool soundEnabled = ref.read(soundEnabledProvider);
    await AudioService.playNotification(soundEnabled);
    state = <NotificationEntity>[notification, ...state];

    if (refreshPlan) {
      ref.invalidate(tasksProvider);
    }
    if (refreshPlanner) {
      await _refreshPlannerDecision();
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

  Future<void> pushCompletionFeedback(
    String taskTitle, {
    bool refreshPlanner = true,
    bool refreshPlan = true,
  }) async {
    final bool soundEnabled = ref.read(soundEnabledProvider);
    await Future.wait<void>(<Future<void>>[
      AudioService.playAchievement(soundEnabled),
      pushInApp(
        _inAppNotification(
          title: 'Completion',
          message: '$taskTitle completed. Recomputing next move.',
        ),
        refreshPlanner: refreshPlanner,
        refreshPlan: refreshPlan,
      ),
    ]);
  }

  Future<void> pushTaskSkipped(
    String taskTitle, {
    bool refreshPlanner = true,
    bool refreshPlan = true,
  }) {
    return pushInApp(
      _inAppNotification(
        title: 'Task Skipped',
        message: '$taskTitle skipped. The Assistant will adapt the next pick.',
      ),
      refreshPlanner: refreshPlanner,
      refreshPlan: refreshPlan,
    );
  }

  Future<void> markRead(String id) async {
    final int generation = _generation;
    final INotificationRepository repository = _repository;
    await repository.markRead(id);
    if (!_isCurrent(generation, repository)) return;
    state = state
        .map(
          (NotificationEntity item) => item.id == id ? item.markRead() : item,
        )
        .toList(growable: false);
  }

  Future<void> delete(String id) async {
    final int generation = _generation;
    final INotificationRepository repository = _repository;
    final cancelNotification = ref.read(cancelNotificationUseCaseProvider);
    await cancelNotification.call(id);
    await repository.delete(id);
    if (!_isCurrent(generation, repository)) return;
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

  Future<void> _refreshPlannerDecision() async {
    ref
      ..invalidate(operatingSnapshotProvider)
      ..invalidate(operatingDecisionPlanProvider)
      ..invalidate(operatingDecisionReceiptProvider)
      ..invalidate(decisionIntelligenceProvider)
      ..invalidate(
        operatingDecisionForSurfaceProvider(
          OperatingDecisionSurface.notifications,
        ),
      );
  }

  bool _isCurrent(int generation, INotificationRepository repository) {
    return generation == _generation && identical(repository, _repository);
  }

  /// Creates transient feedback that must never reach the OS scheduler.
  ///
  /// `isEnabled: false` marks it as never-to-be-posted by the OS, and
  /// `scheduledAt` is now rather than a second in the future because there is
  /// no future delivery to schedule.
  /// The in-app entry for a completed goal. Stored in English like the other
  /// entries; the notification list shows it in the app language.
  static NotificationEntity goalCompleted(String goalTitle) =>
      _inAppNotification(
        title: 'Goal completed',
        message: '"$goalTitle" is complete.',
      );

  static NotificationEntity _inAppNotification({
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
