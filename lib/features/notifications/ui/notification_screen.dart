import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/core/extensions/string_extensions.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _recovering = false;

  Future<void> _recover({required bool permissionDenied}) async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      if (permissionDenied) {
        await turnOnNotifications(context, ref);
      } else {
        await ref
            .read(settingsUiActionsProvider)
            .refreshNotificationPermissionAndReminders();
      }
    } on StaleAccountOperation {
      // The original account is no longer active.
    } on Object {
      if (!mounted) return;
      final es = Localizations.localeOf(context).languageCode == 'es';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            es
                ? 'No se pudieron comprobar los recordatorios. Inténtalo de nuevo.'
                : 'Could not check reminders. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    // Reminders older builds switched off before their time are not
    // activity.
    final List<NotificationEntity> items = ref
        .watch(notificationProvider)
        .where((NotificationEntity item) => !item.isCancelledReminderAt(now))
        .toList(growable: false);
    final RegisteredReminders? registered = ref
        .watch(registeredRemindersProvider)
        .asData
        ?.value;
    final es = Localizations.localeOf(context).languageCode == 'es';
    final localizations = MaterialLocalizations.of(context);
    final automations = ref.watch(automationNotificationsProvider);
    final repeating = automations.asData?.value ?? const <NotificationEntity>[];
    final int scheduledCount =
        repeating.length +
        items
            .where(
              (item) =>
                  notificationListStatus(
                    item,
                    now: now,
                    registered: registered,
                  ) ==
                  NotificationListStatus.scheduled,
            )
            .length;
    final int unreadCount = items
        .where((item) => isNewNotificationActivity(item, now))
        .length;

    final recoverable = items.where(
      (item) =>
          item.isEnabled &&
          NotificationEntity.isReminderId(item.id) &&
          notificationListStatus(item, now: now, registered: registered) ==
              NotificationListStatus.notScheduled &&
          item.scheduleResult != NotificationScheduleResult.unsupported,
    );
    final permissionDenied =
        registered?.permissionGranted == false ||
        (registered?.permissionGranted == null &&
            recoverable.any(
              (item) =>
                  item.scheduleResult ==
                  NotificationScheduleResult.permissionDenied,
            ));

    return PlainScreen(
      children: <Widget>[
        _Header(
          unreadCount: unreadCount,
          scheduledCount: scheduledCount,
          totalCount: items.length + repeating.length,
          onBack: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 16),
        if (permissionDenied && recoverable.isEmpty)
          Text(
            es
                ? 'Las notificaciones de Axiomara están desactivadas.'
                : 'Notifications are off for Axiomara.',
            style: const TextStyle(color: Colors.white70),
          ),
        if (permissionDenied || recoverable.isNotEmpty)
          TextButton(
            onPressed: _recovering
                ? null
                : () async => _recover(permissionDenied: permissionDenied),
            child: Text(
              _recovering
                  ? (es ? 'Comprobando recordatorios…' : 'Checking reminders…')
                  : permissionDenied
                  ? (es ? 'Activar notificaciones' : 'Turn on notifications')
                  : (es ? 'Reintentar recordatorios' : 'Retry reminders'),
            ),
          ),
        if (automations.isLoading) const LinearProgressIndicator(),
        if (automations.hasError)
          TextButton(
            onPressed: () => ref.invalidate(automationNotificationsProvider),
            child: Text(
              es
                  ? 'Estado del recordatorio no disponible. Reintentar'
                  : 'Reminder schedule status unavailable. Retry',
            ),
          ),
        for (final reminder in repeating)
          Card(
            child: ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(reminder.title),
              subtitle: Text(
                '${reminder.message}\n${reminder is AutomationNotification && !reminder.registeredTimeKnown ? (es ? "Hora configurada; hora registrada no disponible" : "Configured time; registered time unavailable") : (es ? "Pr\u00f3xima hora programada" : "Next scheduled time")}: ${localizations.formatMediumDate(reminder.scheduledAt)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(reminder.scheduledAt))}\n${es ? "La entrega es aproximada. Administra este recordatorio recurrente en Ajustes." : "Delivery is approximate. Manage this repeating reminder in Settings."}',
              ),
            ),
          ),
        if (items.isEmpty &&
            repeating.isEmpty &&
            !automations.isLoading &&
            !automations.hasError)
          const _EmptyState(),
        for (final item in items)
          _NotificationTile(
            item: item,
            registered: registered,
            onMarkRead: () =>
                ref.read(notificationProvider.notifier).markRead(item.id),
            onDelete: () =>
                ref.read(notificationProvider.notifier).delete(item.id),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.unreadCount,
    required this.scheduledCount,
    required this.totalCount,
  });

  final VoidCallback onBack;
  final int unreadCount;
  final int scheduledCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PlainHeader(
          title: es ? 'NOTIFICACIONES' : 'NOTIFICATIONS',
          actions: <PlainHeaderAction>[
            PlainHeaderAction(
              icon: Icons.arrow_back_rounded,
              label: es ? 'Atrás' : 'Back',
              onPressed: onBack,
            ),
          ],
        ),
        Text(
          es
              ? 'Actividad y recordatorios programados.'
              : 'Activity and scheduled reminders.',
        ),
        const SizedBox(height: 4),
        Text(
          es
              ? '$unreadCount nuevas · $scheduledCount programadas · $totalCount en total'
              : '$unreadCount new · $scheduledCount scheduled · $totalCount total',
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.registered,
    required this.onMarkRead,
    required this.onDelete,
  });

  final NotificationEntity item;
  final RegisteredReminders? registered;
  final Future<void> Function() onMarkRead;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    final DateTime now = DateTime.now();
    final NotificationListStatus status = notificationListStatus(
      item,
      now: now,
      registered: registered,
    );
    final bool newActivity = isNewNotificationActivity(item, now);
    final String title = _localizedTitle(item.title, es);
    final String message = _localizedMessage(item.message, es);
    final Color accent = !item.isEnabled
        ? AppColors.memoryAmber
        : !newActivity
        ? AppColors.neonViolet
        : AppColors.neonCyan;
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.recallRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.recallRed.withValues(alpha: 0.4)),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.recallRed,
          size: 24,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          button: true,
          label: switch (status) {
            NotificationListStatus.notScheduled =>
              '${es ? 'Recordatorio no programado' : 'Reminder not scheduled'}: $title',
            NotificationListStatus.scheduled =>
              '${es ? 'Recordatorio programado' : 'Scheduled reminder'}: $title',
            NotificationListStatus.unconfirmed =>
              '${es ? 'Recordatorio, hora prevista' : 'Reminder, scheduled time'}: $title',
            NotificationListStatus.past || NotificationListStatus.inApp =>
              item.isRead
                  ? title
                  : '${es ? 'Actividad nueva' : 'New activity'}: $title',
          },
          child: InkWell(
            onTap: onMarkRead,
            borderRadius: BorderRadius.circular(8),
            child: TemporalGlassSurface(
              accent: accent,
              opacity: newActivity ? 0.93 : 0.86,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox.square(
                    dimension: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Icon(
                        !item.isEnabled
                            ? Icons.history_rounded
                            : !newActivity
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_active_outlined,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: newActivity
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 15,
                                  fontWeight: newActivity
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (newActivity)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.6),
                                      blurRadius: 7,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (message.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.45,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_statusLabel(status, notScheduledReason(item, registered), es)} · ${MaterialLocalizations.of(context).formatCompactDate(item.scheduledAt.toLocal())}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TemporalGlassSurface(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.notifications_none_rounded,
                  size: 48,
                  color: AppColors.neonCyan.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 16),
                Text(
                  es ? 'SIN AVISOS' : 'NO ALERTS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  es
                      ? 'No hay actividad ni recordatorios programados.'
                      : 'There is no activity or scheduled reminder.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _statusLabel(
  NotificationListStatus status,
  NotificationScheduleResult? reason,
  bool es,
) => switch (status) {
  NotificationListStatus.scheduled => es ? 'Programado' : 'Scheduled',
  NotificationListStatus.past ||
  NotificationListStatus.unconfirmed => es ? 'Hora prevista' : 'Scheduled time',
  NotificationListStatus.inApp =>
    es ? 'Actividad en la app' : 'In-app activity',
  NotificationListStatus.notScheduled => switch (reason) {
    NotificationScheduleResult.permissionDenied =>
      es
          ? 'No programado: las notificaciones están desactivadas'
          : 'Not scheduled: notifications are off',
    NotificationScheduleResult.unsupported =>
      es
          ? 'No programado: no disponible en este dispositivo'
          : 'Not scheduled: not available on this device',
    NotificationScheduleResult.failed =>
      es
          ? 'No programado: no se pudo programar'
          : 'Not scheduled: could not be set',
    NotificationScheduleResult.scheduled ||
    null => es ? 'No programado' : 'Not scheduled',
  },
};

String _localizedTitle(String raw, bool es) {
  if (!es) return raw.capitalize;
  return switch (raw.trim().toLowerCase()) {
    'goal reminder' => 'Recordatorio de meta',
    'goal due tomorrow' => 'Meta para mañana',
    'decision alert' => 'Decisión actual',
    'completion' => 'Finalización',
    'task skipped' => 'Tarea omitida',
    'goal completed' => 'Meta completada',
    _ => raw.capitalize,
  };
}

/// The day-before goal reminder, the only goal reminder kept in this list.
/// New ones are written in the app language; this covers English records
/// saved before a switch to Spanish.
final RegExp _goalDueTomorrowMessage = RegExp(
  r'^"(.*)" is due tomorrow\.(?: (\d+) of (\d+) steps done\.)?$',
);

String _localizedMessage(String raw, bool es) {
  if (!es) {
    // Records saved before the rename still say "SI".
    return raw.replaceFirst(
      ' skipped. SI will adapt the next pick.',
      ' skipped. The Assistant will adapt the next pick.',
    );
  }
  final RegExpMatch? goalDue = _goalDueTomorrowMessage.firstMatch(raw);
  if (goalDue != null) {
    final String steps = goalDue.group(2) == null
        ? ''
        : ' ${goalDue.group(2)} de ${goalDue.group(3)} pasos hechos.';
    return '«${goalDue.group(1)}» vence mañana.$steps';
  }
  return raw
      .replaceFirst('Target date is near for', 'Se acerca la fecha de')
      .replaceFirst('Selected ', 'Se seleccionó ')
      .replaceFirst(
        ' as the current execution target.',
        ' como la tarea actual.',
      )
      .replaceFirst(
        ' completed. Recomputing next move.',
        ' se completó. Se está actualizando el próximo paso.',
      )
      .replaceFirst(
        ' skipped and adaptation triggered.',
        ' se omitió y se actualizó la adaptación.',
      )
      .replaceFirst(
        ' skipped. The Assistant will adapt the next pick.',
        ' se omitió. El asistente adaptará la próxima elección.',
      )
      .replaceFirst(
        ' skipped. SI will adapt the next pick.',
        ' se omitió. El asistente adaptará la próxima elección.',
      )
      .replaceFirst('" is complete.', '" se cumplió.');
}
