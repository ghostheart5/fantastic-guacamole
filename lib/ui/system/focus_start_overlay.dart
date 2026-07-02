import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

Future<void> runFocusStartAnimation(
  BuildContext context, {
  required VoidCallback onStart,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Focus start animation',
    barrierDismissible: false,
    barrierColor: const Color(0xCC08101F),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => const _FocusStartOverlay(),
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
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
  );

  if (!context.mounted) {
    return;
  }
  onStart();
}

class _FocusStartOverlay extends StatefulWidget {
  const _FocusStartOverlay();

  @override
  State<_FocusStartOverlay> createState() => _FocusStartOverlayState();
}

class _FocusStartOverlayState extends State<_FocusStartOverlay> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), _dismiss);
  }

  void _dismiss() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                primary.withValues(alpha: 0.3),
                primary.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const <double>[0.18, 0.62, 1],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: primary.withValues(alpha: 0.32),
                blurRadius: 42,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 184,
                height: 184,
                child: Lottie.asset(
                  'assets/animations/focus_pulse.json',
                  repeat: false,
                  fit: BoxFit.contain,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.18),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Focus Starting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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
