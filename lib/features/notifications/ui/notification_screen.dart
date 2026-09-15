import 'package:fantastic_guacamole/core/extensions/string_extensions.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<NotificationEntity> items = ref.watch(notificationProvider);
    final DateTime now = DateTime.now();
    final int scheduledCount = items
        .where((item) => item.isEnabled && item.scheduledAt.isAfter(now))
        .length;
    final int unreadCount = items
        .where(
          (item) =>
              !item.isRead &&
              (!item.isEnabled || !item.scheduledAt.isAfter(now)),
        )
        .length;

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgTimelineThreads,
      overlayOpacity: 0.5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: _Header(
                  unreadCount: unreadCount,
                  scheduledCount: scheduledCount,
                  totalCount: items.length,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _NotificationTile(
                          item: items[i],
                          onMarkRead: () async {
                            await ref
                                .read(notificationProvider.notifier)
                                .markRead(items[i].id);
                          },
                          onDelete: () async {
                            await ref
                                .read(notificationProvider.notifier)
                                .delete(items[i].id);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
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
    return TemporalScreenHeader(
      title: es ? 'NOTIFICACIONES' : 'NOTIFICATIONS',
      subtitle: es
          ? 'Actividad y recordatorios programados.'
          : 'Activity and scheduled reminders.',
      eyebrow: es
          ? '$unreadCount nuevas · $scheduledCount programadas · $totalCount en total'
          : '$unreadCount new · $scheduledCount scheduled · $totalCount total',
      onBack: onBack,
      trailing: Icon(
        unreadCount == 0
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_outlined,
        color: AppColors.neonCyan,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onMarkRead,
    required this.onDelete,
  });

  final NotificationEntity item;
  final Future<void> Function() onMarkRead;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    final DateTime now = DateTime.now();
    final bool futureSchedule = item.isEnabled && item.scheduledAt.isAfter(now);
    final bool newActivity = !futureSchedule && !item.isRead;
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
          label: futureSchedule
              ? '${es ? 'Recordatorio programado' : 'Scheduled reminder'}: $title'
              : item.isRead
              ? title
              : '${es ? 'Actividad nueva' : 'New activity'}: $title',
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
                                '${futureSchedule ? (es ? 'Programado' : 'Scheduled') : (item.isEnabled ? (es ? 'Hora prevista' : 'Scheduled time') : (es ? 'Actividad en la app' : 'In-app activity'))} · ${MaterialLocalizations.of(context).formatCompactDate(item.scheduledAt.toLocal())}',
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

String _localizedTitle(String raw, bool es) {
  if (!es) return raw.capitalize;
  return switch (raw.trim().toLowerCase()) {
    'goal reminder' => 'Recordatorio de meta',
    'decision alert' => 'Decisión actual',
    'completion' => 'Finalización',
    'task skipped' => 'Tarea omitida',
    _ => raw.capitalize,
  };
}

String _localizedMessage(String raw, bool es) {
  if (!es) return raw;
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
      );
}
