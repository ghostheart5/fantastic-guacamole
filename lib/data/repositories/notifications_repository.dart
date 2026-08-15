import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/notification_record.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

class NotificationsRepository implements SchedulingResultNotificationRepository {
  NotificationsRepository(
    this._scheduler,
    this._store, {
    required this.storageScope,
    Future<void> Function(NotificationEntity notification)? platformScheduleNotification,
    this._cancelScheduledNotification,
    this._cancelAllScheduledNotifications,
  }) : _scheduleNotification = platformScheduleNotification;

  static const String legacyStorageKey = 'notification_entries_v1';
  static const String _v2KeyPrefix = 'notification_entries_v2';

  final NotificationScheduler _scheduler;
  final SecureStore _store;
  final AccountStorageScope storageScope;
  final Future<void> Function(NotificationEntity notification)?
  _scheduleNotification;
  final Future<void> Function(String id)? _cancelScheduledNotification;
  final Future<void> Function()? _cancelAllScheduledNotifications;

  String get _storageKey {
    final String? namespace = storageScope.v2Namespace;
    if (!storageScope.isAuthenticated || namespace == null) {
      throw StateError(
        'Notification persistence is unavailable outside a safe authenticated scope.',
      );
    }
    return '$_v2KeyPrefix.$namespace';
  }

  static String canonicalStorageKeyForScope(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isAuthenticated || namespace == null) {
      throw StateError(
        'Notification persistence is unavailable outside a safe authenticated scope.',
      );
    }
    return '$_v2KeyPrefix.$namespace';
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    final String? raw = await _store.readString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <NotificationEntity>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Notification storage is not a list.');
      }
      final List<NotificationEntity> entries = <NotificationEntity>[];
      for (final Object? value in decoded) {
        if (value is! Map) {
          throw const FormatException(
            'Notification storage contains a non-object entry.',
          );
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
          throw FormatException(
            'Notification storage contains an invalid entry: $error',
          );
        }
      }
      entries.sort(
        (NotificationEntity a, NotificationEntity b) =>
            b.scheduledAt.compareTo(a.scheduledAt),
      );
      return entries;
    } on FormatException catch (error) {
      Logger.error('Stored notifications are corrupt.', error);
      throw StorageException('Notification storage is corrupted: $error');
    }
  }

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    try {
      await scheduleNotificationWithResult(notification);
    } catch (error) {
      Logger.warn('Failed to schedule notification ${notification.id}: $error');
    }
  }

  @override
  Future<NotificationScheduleResult> scheduleNotificationWithResult(
    NotificationEntity notification,
  ) async {
    await _upsert(notification);
    final schedule = _scheduleNotification;
    if (schedule != null) {
      await schedule(notification);
      return NotificationScheduleResult.scheduled;
    }
    final result = await _scheduler.scheduleWithStatus(notification);
    if (result != NotificationScheduleResult.scheduled) {
      Logger.warn(
        'Notification ${notification.id} was not scheduled: $result',
      );
    }
    return result;
  }

  @override
  Future<void> cancelNotification(String id) async {
    final cancel = _cancelScheduledNotification;
    if (cancel != null) {
      await cancel(id);
    } else {
      await _scheduler.cancel(id);
    }
    final List<NotificationEntity> entries = await getNotifications();
    final NotificationEntity? existing = _find(entries, id);
    if (existing == null) {
      return;
    }
    await _upsert(
      NotificationEntity(
        id: existing.id,
        title: existing.title,
        message: existing.message,
        scheduledAt: existing.scheduledAt,
        isEnabled: false,
        isRead: existing.isRead,
      ),
    );
  }

  @override
  Future<void> markRead(String id) async {
    final List<NotificationEntity> entries = await getNotifications();
    final NotificationEntity? existing = _find(entries, id);
    if (existing == null) {
      return;
    }
    await _upsert(
      NotificationEntity(
        id: existing.id,
        title: existing.title,
        message: existing.message,
        scheduledAt: existing.scheduledAt,
        isEnabled: existing.isEnabled,
        isRead: true,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    final cancel = _cancelScheduledNotification;
    if (cancel != null) {
      await cancel(id);
    } else {
      await _scheduler.cancel(id);
    }
    final List<NotificationEntity> entries = await getNotifications();
    await _save(
      entries
          .where((NotificationEntity entry) => entry.id != id)
          .toList(growable: false),
    );
  }

  Future<void> cancelAll() async {
    try {
      final cancelAll = _cancelAllScheduledNotifications;
      if (cancelAll != null) {
        await cancelAll();
      } else {
        await _scheduler.cancelAll();
      }
    } catch (error) {
      Logger.warn('Failed to cancel all scheduled notifications: $error');
    }
    final List<NotificationEntity> entries = await getNotifications();
    await _save(
      entries
          .map(
            (NotificationEntity entry) => NotificationEntity(
              id: entry.id,
              title: entry.title,
              message: entry.message,
              scheduledAt: entry.scheduledAt,
              isEnabled: false,
              isRead: entry.isRead,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _upsert(NotificationEntity notification) async {
    final List<NotificationEntity> entries = await getNotifications();
    await _save(<NotificationEntity>[
      notification,
      ...entries.where(
        (NotificationEntity entry) => entry.id != notification.id,
      ),
    ]);
  }

  Future<void> _save(List<NotificationEntity> entries) {
    return _store.writeString(
      _storageKey,
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

  NotificationEntity? _find(List<NotificationEntity> entries, String id) {
    for (final NotificationEntity entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}
