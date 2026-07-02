import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

Future<void> showLevelUpAnimation(
  BuildContext context, {
  required int level,
  required String title,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Level up animation',
    barrierDismissible: false,
    barrierColor: const Color(0xD9110C1E),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _LevelUpOverlay(level: level, title: title),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
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
    Future<void>.delayed(const Duration(milliseconds: 1050), _dismiss);
  }

  void _dismiss() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                const Color(0xFFFFC85A).withValues(alpha: 0.28),
                const Color(0xFFFFA629).withValues(alpha: 0.12),
                Colors.transparent,
              ],
              stops: const <double>[0.18, 0.62, 1],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFFB347).withValues(alpha: 0.35),
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
                child: Lottie.asset(
                  'assets/animations/level_up.json',
                  repeat: false,
                  fit: BoxFit.contain,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'LEVEL UP',
                    style: TextStyle(
                      color: Color(0xFFFFE3A3),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Level ${widget.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Level Up - ${widget.title}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFF1CF),
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
