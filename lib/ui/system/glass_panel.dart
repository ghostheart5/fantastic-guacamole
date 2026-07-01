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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color baseSurface = scheme.surface;
    final Color borderColor = isActive ? scheme.primary : scheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: baseSurface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: isActive ? 0.55 : 0.32)),
        boxShadow: <BoxShadow>[
          const BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
          if (isActive)
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
<<<<<<< HEAD
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 240),
                  opacity: isActive ? 0.32 : 0.12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          scheme.secondary.withValues(alpha: 0.16),
                          scheme.primary.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
=======
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
>>>>>>> 979f416d61500b1beabf212d483428b7431dab3e
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
