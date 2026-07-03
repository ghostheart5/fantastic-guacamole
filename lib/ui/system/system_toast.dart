import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

void showXPGain(BuildContext context, int xp) {
  final OverlayState overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _XPToast(xp: xp, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _XPToast extends StatefulWidget {
  const _XPToast({required this.xp, required this.onDone});

  final int xp;
  final VoidCallback onDone;

  @override
  State<_XPToast> createState() => _XPToastState();
}

class _XPToastState extends State<_XPToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 64),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 18,
      ),
    ]).animate(_ctrl);

    _slide = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 16.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 82),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _slide.value),
            child: Opacity(opacity: _opacity.value, child: child),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF050D1A),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.memoryAmber.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.memoryAmber.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.memoryAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${widget.xp} XP',
                    style: const TextStyle(
                      color: AppColors.memoryAmber,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
