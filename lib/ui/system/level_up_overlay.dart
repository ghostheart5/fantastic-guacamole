import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

Future<void> showLevelUpAnimation(
  BuildContext context, {
  required int level,
  required String title,
}) async {
  final bool reduceMotion =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  MotionProfile motionProfile = MotionProfile.standard;
  try {
    motionProfile = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(motionProfileProvider);
  } on Object {
    motionProfile = MotionProfile.standard;
  }
  final Duration transitionDuration = switch (motionProfile) {
    MotionProfile.calm => const Duration(milliseconds: 140),
    MotionProfile.standard => const Duration(milliseconds: 180),
    MotionProfile.expressive => const Duration(milliseconds: 240),
  };
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Level up animation',
    barrierDismissible: false,
    barrierColor: const Color(0xD907101D),
    transitionDuration: transitionDuration,
    pageBuilder: (_, _, _) => _LevelUpOverlay(level: level, title: title),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          if (reduceMotion) {
            return child;
          }
          final CurvedAnimation curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
  );
}

class _LevelUpOverlay extends StatefulWidget {
  const _LevelUpOverlay({required this.level, required this.title});

  final int level;
  final String title;

  @override
  State<_LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<_LevelUpOverlay> {
  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);
    final bool soundEnabled = container.read(soundEnabledProvider);
    final bool advancedAudioEnabled = container.read(
      advancedAudioProfileEnabledProvider,
    );
    final bool hapticEnabled = container.read(hapticFeedbackEnabledProvider);
    AudioService.playAchievement(
      soundEnabled,
      advancedProfileEnabled: advancedAudioEnabled,
      hapticsEnabled: hapticEnabled,
    );
    MotionProfile motionProfile = MotionProfile.standard;
    try {
      motionProfile = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(motionProfileProvider);
    } on Object {
      motionProfile = MotionProfile.standard;
    }
    final Duration dismissDelay = switch (motionProfile) {
      MotionProfile.calm => const Duration(milliseconds: 760),
      MotionProfile.standard => const Duration(milliseconds: 1050),
      MotionProfile.expressive => const Duration(milliseconds: 1220),
    };
    Future<void>.delayed(dismissDelay, _dismiss);
  }

  void _dismiss() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                const Color(0xFF00E5FF).withValues(alpha: 0.24),
                const Color(0xFF9B8AFB).withValues(alpha: 0.10),
                Colors.transparent,
              ],
              stops: const <double>[0.18, 0.62, 1],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.26),
                blurRadius: 48,
                spreadRadius: 12,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 220,
                height: 220,
                child: reduceMotion
                    ? const SizedBox.shrink()
                    : Lottie.asset(
                        AppAssets.animLevelUp,
                        repeat: false,
                        fit: BoxFit.contain,
                      ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'ACHIEVEMENT UNLOCKED',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Level ${widget.level}',
                    style: const TextStyle(
                      color: Color(0xFF9B8AFB),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Level Up - ${widget.title}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
