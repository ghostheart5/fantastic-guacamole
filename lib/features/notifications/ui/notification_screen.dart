import 'package:fantastic_guacamole/core/extensions/date_extensions.dart';
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
    final int unreadCount = items.where((item) => !item.isRead).length;

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
    required this.totalCount,
  });

  final VoidCallback onBack;
  final int unreadCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return TemporalScreenHeader(
      title: 'NOTIFICATIONS',
      subtitle: 'Signals that may change your next move.',
      eyebrow: unreadCount == 0
          ? '$totalCount signals · all read'
          : '$unreadCount unread · $totalCount total',
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
    final Color accent = !item.isEnabled
        ? AppColors.memoryAmber
        : item.isRead
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
          label: item.isRead
              ? item.title.capitalize
              : 'Unread notification: ${item.title.capitalize}',
          child: InkWell(
            onTap: onMarkRead,
            borderRadius: BorderRadius.circular(8),
            child: TemporalGlassSurface(
              accent: accent,
              opacity: item.isRead ? 0.86 : 0.93,
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
                            ? Icons.notifications_off_outlined
                            : item.isRead
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
                                item.title.capitalize,
                                style: TextStyle(
                                  color: item.isRead
                                      ? Colors.white70
                                      : Colors.white,
                                  fontSize: 15,
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            if (!item.isRead)
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
                        if (item.message.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            item.message,
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
                            Text(
                              item.scheduledAt.short,
                              style: TextStyle(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            if (!item.isEnabled) ...<Widget>[
                              const SizedBox(width: 12),
                              const Text(
                                'Disabled',
                                style: TextStyle(
                                  color: AppColors.memoryAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
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
                const Text(
                  'NO ALERTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All clear. There are no pending notifications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
