import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/notification_record.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

class NotificationsRepository implements INotificationRepository {
  NotificationsRepository(
    this._scheduler,
    this._store, {
    this._scheduleNotification,
    this._cancelScheduledNotification,
    this._cancelAllScheduledNotifications,
  });

  static const String _storageKey = 'notification_entries_v1';

  final NotificationScheduler _scheduler;
  final SecureStore _store;
  final Future<void> Function(NotificationEntity notification)?
  _scheduleNotification;
  final Future<void> Function(String id)? _cancelScheduledNotification;
  final Future<void> Function()? _cancelAllScheduledNotifications;

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
    await _upsert(notification);
    try {
      final schedule = _scheduleNotification;
      if (schedule != null) {
        await schedule(notification);
      } else {
        final result = await _scheduler.scheduleWithStatus(notification);
        if (result != NotificationScheduleResult.scheduled) {
          Logger.warn(
            'Notification ${notification.id} was not scheduled: $result',
          );
        }
      }
    } catch (error) {
      Logger.warn('Failed to schedule notification ${notification.id}: $error');
    }
  }

  @override
  Future<void> cancelNotification(String id) async {
    try {
      final cancel = _cancelScheduledNotification;
      if (cancel != null) {
        await cancel(id);
      } else {
        await _scheduler.cancel(id);
      }
    } catch (error) {
      Logger.warn('Failed to cancel scheduled notification $id: $error');
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
    try {
      final cancel = _cancelScheduledNotification;
      if (cancel != null) {
        await cancel(id);
      } else {
        await _scheduler.cancel(id);
      }
    } catch (error) {
      Logger.warn(
        'Failed to cancel scheduled notification during delete $id: $error',
      );
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
