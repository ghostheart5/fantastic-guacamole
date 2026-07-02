import 'package:fantastic_guacamole/data/models/notification.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/ui/system/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationCenterSheet extends ConsumerWidget {
  const NotificationCenterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ChronoNotification> notifications = ref.watch(
      notificationProvider,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Notification Center',
                    style: TextStyle(
                      color: Color(0xFFEFE7FF),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(notificationProvider.notifier).clear();
                    },
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (notifications.isEmpty)
              const GlassPanel(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No active alerts. System is quiet.',
                    style: TextStyle(color: Color(0xFFDAD1EE)),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final ChronoNotification notification =
                        notifications[index];
                    return GlassPanel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: _priorityColor(notification.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _titleFor(notification.type),
                                  style: const TextStyle(
                                    color: Color(0xFFEFE7FF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  style: const TextStyle(
                                    color: Color(0xFFDAD1EE),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeLabel(notification.timestamp),
                                  style: const TextStyle(
                                    color: Color(0xFFA99DBE),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ref
                                  .read(notificationProvider.notifier)
                                  .dismiss(index);
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFFCFC4E8),
                            ),
                            tooltip: 'Dismiss',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _priorityColor(ChronoNotificationPriority priority) {
    switch (priority) {
      case ChronoNotificationPriority.high:
        return const Color(0xFFFF6E98);
      case ChronoNotificationPriority.medium:
        return const Color(0xFFFFC66D);
      case ChronoNotificationPriority.low:
        return const Color(0xFF7AD8FF);
    }
  }

  static String _titleFor(ChronoNotificationType type) {
    switch (type) {
      case ChronoNotificationType.info:
        return 'Info';
      case ChronoNotificationType.success:
        return 'Success';
      case ChronoNotificationType.warning:
        return 'Warning';
      case ChronoNotificationType.primaryDecisionAlert:
        return 'Decision Alert';
      case ChronoNotificationType.overloadWarning:
        return 'Overload Warning';
      case ChronoNotificationType.energyAdjustment:
        return 'Energy Update';
      case ChronoNotificationType.siInsight:
        return 'SI Insight';
      case ChronoNotificationType.temporalAlert:
        return 'Temporal Alert';
      case ChronoNotificationType.completionFeedback:
        return 'Completion';
      case ChronoNotificationType.systemPrompt:
        return 'System Prompt';
    }
  }

  static String _timeLabel(DateTime timestamp) {
    final Duration delta = DateTime.now().difference(timestamp);
    if (delta.inMinutes < 1) {
      return 'Just now';
    }
    if (delta.inHours < 1) {
      return '${delta.inMinutes}m ago';
    }
    if (delta.inDays < 1) {
      return '${delta.inHours}h ago';
    }
    return '${delta.inDays}d ago';
  }
}
