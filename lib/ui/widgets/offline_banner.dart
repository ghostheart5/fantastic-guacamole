import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final int pendingSyncCount = ref
        .watch(offlineQueueCountProvider)
        .maybeWhen(data: (int count) => count, orElse: () => 0);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isOnline
              ? const SizedBox.shrink()
              : _OfflineBannerBar(pendingSyncCount: pendingSyncCount),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _OfflineBannerBar extends StatelessWidget {
  const _OfflineBannerBar({required this.pendingSyncCount});

  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('offline_banner_live_region'),
      liveRegion: true,
      container: true,
      label: pendingSyncCount > 0
          ? 'Offline mode. $pendingSyncCount actions queued. Actions will sync later.'
          : 'Offline mode. Actions will sync later.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          color: AppColors.memoryAmber.withValues(alpha: 0.15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 13,
                color: AppColors.memoryAmber,
              ),
              const SizedBox(width: 6),
              Text(
                pendingSyncCount > 0
                    ? 'Offline Mode — $pendingSyncCount queued, syncing later'
                    : 'Offline Mode — actions will sync later',
                style: const TextStyle(
                  color: AppColors.memoryAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
