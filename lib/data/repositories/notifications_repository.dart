import 'dart:convert';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/notification_record.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';

class NotificationsRepository implements INotificationRepository {
  NotificationsRepository(
    this._scheduler,
    this._store, {
    String? accountId,
    KeyedMutationCoordinator? mutationCoordinator,
    this._scheduleNotification,
    this._cancelScheduledNotification,
    this._cancelAllScheduledNotifications,
  }) : _accountId = accountId?.trim().isEmpty == true
           ? null
           : accountId?.trim(),
       _mutations = mutationCoordinator ?? KeyedMutationCoordinator.shared;

  final NotificationSchedulerPort _scheduler;
  final SecureStore _store;
  final String? _accountId;
  final KeyedMutationCoordinator _mutations;
  final Future<void> Function(NotificationEntity notification)?
  _scheduleNotification;
  final Future<void> Function(String id)? _cancelScheduledNotification;
  final Future<void> Function()? _cancelAllScheduledNotifications;

  String? get accountId => _accountId;

  String? get _storageKey => _accountId == null
      ? null
      : AccountDataRegistry.notificationSecureKeyFor(_accountId);

  String? get _accountScope =>
      _accountId == null ? null : AccountDataRegistry.accountDigest(_accountId);

  String? get _mutationKey => _accountId == null
      ? null
      : AccountDataRegistry.notificationMutationKeyFor(_accountId);

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    final String? mutationKey = _mutationKey;
    if (mutationKey == null) return const <NotificationEntity>[];
    return _mutations.runExclusive<List<NotificationEntity>>(
      mutationKey,
      _readNotifications,
    );
  }

  Future<List<NotificationEntity>> _readNotifications() async {
    final String? storageKey = _storageKey;
    return _readNotificationsAt(storageKey);
  }

  Future<List<NotificationEntity>> _readNotificationsAt(
    String? storageKey,
  ) async {
    if (storageKey == null) return const <NotificationEntity>[];
    final String? raw = await _store.readString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <NotificationEntity>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Notification storage is not a list.');
      }
      final List<NotificationEntity> entries = <NotificationEntity>[];
      int malformedCount = 0;
      for (final Object? value in decoded) {
        if (value is! Map) {
          continue;
        }
        try {
          entries.add(
            NotificationRecord.fromJson(
              value.map(
                (dynamic key, dynamic item) => MapEntry(key.toString(), item),
              ),
            ).toEntity(),
          );
        } on FormatException catch (error) {
          malformedCount++;
          if (malformedCount == 1) {
            Logger.warn('Skipping malformed notification: $error');
          }
        }
      }
      if (malformedCount > 1) {
        Logger.warn(
          'Skipped $malformedCount malformed notifications while reading storage.',
        );
      }
      entries.sort(
        (NotificationEntity a, NotificationEntity b) =>
            b.scheduledAt.compareTo(a.scheduledAt),
      );
      return entries;
    } on FormatException catch (error) {
      Logger.error('Stored notifications are corrupt.', error);
      return const <NotificationEntity>[];
    }
  }

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    await _runMutation(() async {
      await _upsert(notification);
      try {
        final schedule = _scheduleNotification;
        if (schedule != null) {
          await schedule(notification);
        } else {
          await _scheduler.schedule(notification, accountScope: _accountScope);
        }
      } catch (error) {
        Logger.warn(
          'Failed to schedule notification ${notification.id}: $error',
        );
      }
    });
  }

  @override
  Future<void> cancelNotification(String id) async {
    await _runMutation(() async {
      await _cancelPlatform(id);
      final List<NotificationEntity> entries = await _readNotifications();
      final NotificationEntity? existing = _find(entries, id);
      if (existing == null) return;
      await _upsert(_copy(existing, isEnabled: false));
    });
  }

  @override
  Future<void> markRead(String id) async {
    await _runMutation(() async {
      final List<NotificationEntity> entries = await _readNotifications();
      final NotificationEntity? existing = _find(entries, id);
      if (existing == null) return;
      await _upsert(_copy(existing, isRead: true));
    });
  }

  @override
  Future<void> delete(String id) async {
    await _runMutation(() async {
      await _cancelPlatform(id, deleting: true);
      final List<NotificationEntity> entries = await _readNotifications();
      await _save(
        entries
            .where((NotificationEntity entry) => entry.id != id)
            .toList(growable: false),
      );
    });
  }

  Future<void> cancelAll() async {
    await _runMutation(() async {
      final List<NotificationEntity> entries = await _readNotifications();
      final cancelAll = _cancelAllScheduledNotifications;
      if (cancelAll != null) {
        try {
          await cancelAll();
        } catch (error) {
          Logger.warn('Failed to cancel all scheduled notifications: $error');
        }
      } else {
        for (final NotificationEntity entry in entries) {
          await _cancelPlatform(entry.id);
        }
      }
      await _save(
        entries
            .map((NotificationEntity entry) => _copy(entry, isEnabled: false))
            .toList(growable: false),
      );
    });
  }

  /// Cancels only this account's platform schedules while retaining its local
  /// notification records. Normal sign-out uses this isolation step so a
  /// later sign-in can restore repository state without leaking reminder text
  /// from the departing account on the device lock screen.
  Future<void> cancelAccountSchedules({
    bool includeLegacyOwnedData = false,
  }) async {
    await _runMutation(() async {
      final Set<String> scopedIds = <String>{
        ...((await _readNotifications()).map(
          (NotificationEntity entry) => entry.id,
        )),
        'habit_reminder_daily',
        'daily_planning_reminder',
        'reflection_reminder',
      };
      for (final String id in scopedIds) {
        await _cancelPlatformStrict(id, accountScope: _accountScope);
      }

      if (includeLegacyOwnedData) {
        final Set<String> legacyIds = <String>{
          ...((await _readNotificationsAt(
            AccountDataRegistry.legacyNotificationSecureKey,
          )).map((NotificationEntity entry) => entry.id)),
          'habit_reminder_daily',
          'daily_planning_reminder',
          'reflection_reminder',
        };
        for (final String id in legacyIds) {
          await _cancelPlatformStrict(id, accountScope: null);
        }
      }
      _scheduler.clearTappedPayload();
    });
  }

  Future<void> clearAccountData({bool includeLegacyOwnedData = false}) async {
    await _runMutation(() async {
      final List<NotificationEntity> entries = await _readNotifications();
      for (final NotificationEntity entry in entries) {
        await _cancelPlatform(entry.id);
      }
      for (final String id in const <String>[
        'habit_reminder_daily',
        'daily_planning_reminder',
        'reflection_reminder',
      ]) {
        await _cancelPlatform(id);
      }
      final String? storageKey = _storageKey;
      if (storageKey != null) await _store.delete(storageKey);
      if (includeLegacyOwnedData) {
        await _store.delete(AccountDataRegistry.legacyNotificationSecureKey);
      }
      _scheduler.clearTappedPayload();
    });
  }

  Future<void> _upsert(NotificationEntity notification) async {
    final List<NotificationEntity> entries = await _readNotifications();
    await _save(<NotificationEntity>[
      notification,
      ...entries.where(
        (NotificationEntity entry) => entry.id != notification.id,
      ),
    ]);
  }

  Future<void> _save(List<NotificationEntity> entries) {
    final String? storageKey = _storageKey;
    if (storageKey == null) return Future<void>.value();
    return _store.writeString(
      storageKey,
      jsonEncode(
        entries
            .map(
              (NotificationEntity entry) =>
                  NotificationRecord.fromEntity(entry).toJson(),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _runMutation(Future<void> Function() mutation) {
    final String? mutationKey = _mutationKey;
    if (mutationKey == null) return Future<void>.value();
    return _mutations.runExclusive<void>(mutationKey, mutation);
  }

  Future<void> _cancelPlatform(String id, {bool deleting = false}) async {
    try {
      final cancel = _cancelScheduledNotification;
      if (cancel != null) {
        await cancel(id);
      } else {
        await _scheduler.cancel(id, accountScope: _accountScope);
      }
    } catch (error) {
      Logger.warn(
        deleting
            ? 'Failed to cancel scheduled notification during delete $id: $error'
            : 'Failed to cancel scheduled notification $id: $error',
      );
    }
  }

  Future<void> _cancelPlatformStrict(
    String id, {
    required String? accountScope,
  }) async {
    final cancel = _cancelScheduledNotification;
    if (cancel != null) {
      await cancel(id);
      return;
    }
    final bool cancelled = await _scheduler.cancel(
      id,
      accountScope: accountScope,
    );
    if (!cancelled) {
      throw StateError('A scheduled notification could not be cancelled.');
    }
  }

  NotificationEntity _copy(
    NotificationEntity entry, {
    bool? isEnabled,
    bool? isRead,
  }) {
    return NotificationEntity(
      id: entry.id,
      title: entry.title,
      message: entry.message,
      scheduledAt: entry.scheduledAt,
      isEnabled: isEnabled ?? entry.isEnabled,
      isRead: isRead ?? entry.isRead,
    );
  }

  NotificationEntity? _find(List<NotificationEntity> entries, String id) {
    for (final NotificationEntity entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}
