import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

class LoadingOverlay extends ConsumerWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MotionProfile motionProfile = ref.watch(motionProfileProvider);
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool shouldLoop = switch (motionProfile) {
      MotionProfile.calm => false,
      MotionProfile.standard => true,
      MotionProfile.expressive => true,
    };
    final double lottieSize = switch (motionProfile) {
      MotionProfile.calm => 92,
      MotionProfile.standard => 120,
      MotionProfile.expressive => 132,
    };
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (reduceMotion)
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    Lottie.asset(
                      AppAssets.animFocusPulse,
                      width: lottieSize,
                      height: lottieSize,
                      repeat: shouldLoop,
                      fit: BoxFit.contain,
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'SYNCING',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
