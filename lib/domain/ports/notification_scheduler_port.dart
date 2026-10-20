import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Notifications
///
/// Domain-facing boundary for scheduling notifications on a host platform.
///
/// Application orchestration depends on this contract rather than importing
/// the Flutter local-notifications implementation from `lib/system`.
abstract interface class NotificationSchedulerPort {
  Future<bool> requestPermissions();

  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  });

  Future<bool> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  });

  /// Register a calendar recurrence whose first eligible fire is [firstAt].
  /// Unsupported platforms must reject this rather than drop the lower bound.
  Future<bool> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  });

  Future<bool> cancel(String id, {String? accountScope});

  Future<bool> cancelAll();

  void clearTappedPayload();
}
