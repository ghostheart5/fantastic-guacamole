import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/extensions/date_extensions.dart';
import 'package:fantastic_guacamole/core/extensions/string_extensions.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/notifications/controllers/notification_controller.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(notificationControllerProvider);
    final async = controller.watch();

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/nexus_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.neonCyan,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(
                        color: AppColors.recallRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: controller.refresh,
                          color: AppColors.neonCyan,
                          backgroundColor: const Color(0xFF0B111C),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: items.length,
                            itemBuilder: (context, i) => _NotificationTile(
                              item: items[i],
                              onMarkRead: () =>
                                  controller.markRead(items[i].id),
                              onDelete: () => controller.delete(items[i].id),
                            ),
                          ),
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
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          SmartPressable(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.neonCyan,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.neonCyan, AppColors.neonViolet],
                  ).createShader(bounds),
                  child: const Text(
                    'NOTIFICATIONS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Text(
                  'SYSTEM ALERTS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.recallRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.recallRed.withValues(alpha: 0.3)),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.recallRed,
          size: 20,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: SmartPressable(
        onTap: onMarkRead,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF050D1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead
                  ? Colors.white10
                  : AppColors.neonCyan.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 20,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  color: item.isRead ? Colors.white24 : AppColors.neonCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.capitalize,
                      style: TextStyle(
                        color: item.isRead ? Colors.white54 : Colors.white,
                        fontSize: 14,
                        fontWeight: item.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    if (item.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.scheduledAt.short,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.neonCyan.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonCyan,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: AppColors.neonCyan.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO ALERTS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'All clear — no pending notifications',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
