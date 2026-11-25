import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';

/// Whether reminders can reach this device, and if not, why. Shown at the
/// top of the notification settings.
enum ReminderHealth {
  /// The main reminder switch is off.
  remindersOff,

  /// This device cannot show reminders at all.
  unsupportedDevice,

  /// Notifications are off for the app.
  permissionOff,

  /// The last reminder update did not finish.
  lastAttemptFailed,

  /// Reminders work, but some kinds cannot be set on this device.
  partlyUnsupported,

  /// Notification permission has not been read yet.
  checking,

  ready,
}

/// The first reason, in the order a person would fix them.
ReminderHealth reminderHealth({
  required bool remindersOn,
  required bool deviceSupported,
  required bool? permissionGranted,
  required Iterable<NotificationScheduleResult?> lastResults,
}) {
  if (!remindersOn) return ReminderHealth.remindersOff;
  if (!deviceSupported) return ReminderHealth.unsupportedDevice;
  if (permissionGranted == false) return ReminderHealth.permissionOff;
  if (lastResults.contains(NotificationScheduleResult.failed)) {
    return ReminderHealth.lastAttemptFailed;
  }
  if (permissionGranted == null) return ReminderHealth.checking;
  if (lastResults.contains(NotificationScheduleResult.unsupported)) {
    return ReminderHealth.partlyUnsupported;
  }
  return ReminderHealth.ready;
}

/// The plain words for [health].
String reminderHealthMessage(ReminderHealth health, {required bool spanish}) {
  String copy(String english, String spanishText) =>
      spanish ? spanishText : english;
  return switch (health) {
    ReminderHealth.remindersOff => copy(
      'Reminders are off. Turn on Reminders below to get them again.',
      'Los recordatorios están desactivados. Activa Recordatorios abajo para volver a recibirlos.',
    ),
    ReminderHealth.unsupportedDevice => copy(
      'Reminders are not supported on this device.',
      'Los recordatorios no son compatibles con este dispositivo.',
    ),
    ReminderHealth.permissionOff => copy(
      'Notifications are off for Axiomara, so reminders cannot arrive.',
      'Las notificaciones de Axiomara están desactivadas, así que los recordatorios no pueden llegar.',
    ),
    ReminderHealth.lastAttemptFailed => copy(
      'The last reminder update did not finish, so some reminders may be missing.',
      'La última actualización de recordatorios no terminó, así que pueden faltar algunos.',
    ),
    ReminderHealth.partlyUnsupported => copy(
      'Reminders can arrive, but some are not supported on this device.',
      'Los recordatorios pueden llegar, pero algunos no son compatibles con este dispositivo.',
    ),
    ReminderHealth.checking => copy(
      'Checking whether reminders can arrive.',
      'Comprobando si los recordatorios pueden llegar.',
    ),
    ReminderHealth.ready => copy(
      'Reminders can arrive on this device.',
      'Los recordatorios pueden llegar a este dispositivo.',
    ),
  };
}
