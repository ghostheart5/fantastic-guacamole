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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isActive ? const Color(0x66C2A7FF) : const Color(0x33FFFFFF)),
        boxShadow: <BoxShadow>[
          const BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
          if (isActive) const BoxShadow(color: Color(0x44C2A7FF), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: isActive ? 0.28 : 0,
                    child: Image.asset(
                      'assets/glows/glow_secondary.png',
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
