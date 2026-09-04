import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
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
    final bool cloudSyncAvailable = ref.watch(cloudSyncCapabilityProvider);
    final int pendingSyncCount = ref
        .watch(offlineQueueCountProvider)
        .maybeWhen(data: (int count) => count, orElse: () => 0);

    return SafeArea(
      top: !isOnline,
      left: !isOnline,
      right: !isOnline,
      bottom: false,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isOnline
                ? const SizedBox.shrink()
                : _OfflineBannerBar(
                    pendingSyncCount: pendingSyncCount,
                    cloudSyncAvailable: cloudSyncAvailable,
                  ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _OfflineBannerBar extends StatelessWidget {
  const _OfflineBannerBar({
    required this.pendingSyncCount,
    required this.cloudSyncAvailable,
  });

  final int pendingSyncCount;
  final bool cloudSyncAvailable;

  @override
  Widget build(BuildContext context) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final String semanticLabel = l10n.offlineSemanticLabel(
      cloudSyncAvailable: cloudSyncAvailable,
      pendingSyncCount: pendingSyncCount,
    );
    final String visibleLabel = l10n.offlineVisibleLabel(
      cloudSyncAvailable: cloudSyncAvailable,
      pendingSyncCount: pendingSyncCount,
    );
    return Semantics(
      key: const Key('offline_banner_live_region'),
      liveRegion: true,
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              Flexible(
                child: Text(
                  visibleLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.memoryAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
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
