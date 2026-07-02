import 'package:flutter/material.dart';

class AppBackground extends StatefulWidget {
  const AppBackground({super.key, this.image, required this.child, this.active = false});

  final String? image;
  final Widget child;
  final bool active;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double glow = widget.active ? 0.2 + _controller.value * 0.4 : 0.1;
        final String? image = widget.image;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF050510),
                image: image == null
                    ? null
                    : DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.3,
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: glow),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
