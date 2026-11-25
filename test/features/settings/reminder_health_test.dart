import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/features/settings/ui/reminder_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReminderHealth health({
    bool remindersOn = true,
    bool deviceSupported = true,
    bool? permissionGranted = true,
    List<NotificationScheduleResult?> lastResults = const [],
  }) => reminderHealth(
    remindersOn: remindersOn,
    deviceSupported: deviceSupported,
    permissionGranted: permissionGranted,
    lastResults: lastResults,
  );

  test('each reason is found, in the order a person would fix them', () {
    expect(health(), ReminderHealth.ready);
    expect(
      health(lastResults: const [null, NotificationScheduleResult.scheduled]),
      ReminderHealth.ready,
    );
    expect(
      health(remindersOn: false, permissionGranted: false),
      ReminderHealth.remindersOff,
    );
    expect(
      health(deviceSupported: false, permissionGranted: false),
      ReminderHealth.unsupportedDevice,
    );
    expect(
      health(
        permissionGranted: false,
        lastResults: const [NotificationScheduleResult.failed],
      ),
      ReminderHealth.permissionOff,
    );
    expect(
      health(
        lastResults: const [
          NotificationScheduleResult.unsupported,
          NotificationScheduleResult.failed,
        ],
      ),
      ReminderHealth.lastAttemptFailed,
    );
    expect(
      health(lastResults: const [NotificationScheduleResult.unsupported]),
      ReminderHealth.partlyUnsupported,
    );
    expect(health(permissionGranted: null), ReminderHealth.checking);
    // A stale "permission denied" result is not a reason once allowed.
    expect(
      health(lastResults: const [NotificationScheduleResult.permissionDenied]),
      ReminderHealth.ready,
    );
  });

  test('every state says why in English and Spanish', () {
    const Map<ReminderHealth, (String, String)> expected = {
      ReminderHealth.remindersOff: (
        'Reminders are off. Turn on Reminders below to get them again.',
        'Los recordatorios están desactivados. Activa Recordatorios abajo para volver a recibirlos.',
      ),
      ReminderHealth.unsupportedDevice: (
        'Reminders are not supported on this device.',
        'Los recordatorios no son compatibles con este dispositivo.',
      ),
      ReminderHealth.permissionOff: (
        'Notifications are off for Axiomara, so reminders cannot arrive.',
        'Las notificaciones de Axiomara están desactivadas, así que los recordatorios no pueden llegar.',
      ),
      ReminderHealth.lastAttemptFailed: (
        'The last reminder update did not finish, so some reminders may be missing.',
        'La última actualización de recordatorios no terminó, así que pueden faltar algunos.',
      ),
      ReminderHealth.partlyUnsupported: (
        'Reminders can arrive, but some are not supported on this device.',
        'Los recordatorios pueden llegar, pero algunos no son compatibles con este dispositivo.',
      ),
      ReminderHealth.checking: (
        'Checking whether reminders can arrive.',
        'Comprobando si los recordatorios pueden llegar.',
      ),
      ReminderHealth.ready: (
        'Reminders can arrive on this device.',
        'Los recordatorios pueden llegar a este dispositivo.',
      ),
    };
    expect(expected.keys, unorderedEquals(ReminderHealth.values));
    for (final MapEntry<ReminderHealth, (String, String)> entry
        in expected.entries) {
      expect(reminderHealthMessage(entry.key, spanish: false), entry.value.$1);
      expect(reminderHealthMessage(entry.key, spanish: true), entry.value.$2);
    }
  });
}
