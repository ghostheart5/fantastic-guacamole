import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isOnline ? const SizedBox.shrink() : const _OfflineBannerBar(),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _OfflineBannerBar extends StatelessWidget {
  const _OfflineBannerBar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('offline_banner_live_region'),
      liveRegion: true,
      container: true,
      label: 'Offline mode. Actions will sync later.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          color: AppColors.memoryAmber.withValues(alpha: 0.15),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 13, color: AppColors.memoryAmber),
              SizedBox(width: 6),
              Text(
                'Offline Mode — actions will sync later',
                style: TextStyle(
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
