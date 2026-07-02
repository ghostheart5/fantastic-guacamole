import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.isActive = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: isActive ? const Offset(0, -0.01) : Offset.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/backgrounds/home_bg.png'),
            fit: BoxFit.cover,
          ),
          color: const Color(0x1A000000),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0x38C2A7FF) : const Color(0x12FFFFFF),
          ),
          boxShadow: <BoxShadow>[
            const BoxShadow(
              color: Color(0x16000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
            if (isActive)
              const BoxShadow(
                color: Color(0x1AC2A7FF),
                blurRadius: 18,
                spreadRadius: 0.5,
                offset: Offset(0, 8),
              ),
          ],
        ),
        child: child,
      ),
    );
  }
}
