import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedSystemBackground extends StatefulWidget {
  const AnimatedSystemBackground({super.key});

  @override
  State<AnimatedSystemBackground> createState() => _AnimatedSystemBackgroundState();
}

class _AnimatedSystemBackgroundState extends State<AnimatedSystemBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const String _rootBackgroundAsset = 'assets/backgrounds/main_bg.png';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 18))
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
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final Color color1 = Color.lerp(const Color(0xCC08040E), const Color(0xCC170C1F), t)!;
        final Color color2 = Color.lerp(const Color(0xCC221029), const Color(0xCC0D0916), t)!;
        final Alignment begin = Alignment(-1 + (t * 0.6), -1 + (t * 0.2));
        final Alignment end = Alignment(1 - (t * 0.4), 1 - (t * 0.1));
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              _rootBackgroundAsset,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                  const ColoredBox(color: Color(0xFF0C0812)),
            ),
            AnimatedContainer(
              duration: const Duration(seconds: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: <Color>[color1, color2, Color.lerp(color2, color1, 0.5)!, color2],
                ),
              ),
            ),
            Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/overlays/particles_overlay.png',
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/overlays/glass_overlay.png',
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            AnimatedOpacity(
              opacity: t > 0.02 ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: CustomPaint(
                painter: _GlowPainter(progress: t),
                size: Size.infinite,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pinkGlow = Paint()
      ..color = const Color(0x66FF7BB7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    final Paint lavenderGlow = Paint()
      ..color = const Color(0x66C2A7FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final Offset p1 = Offset(
      size.width * (0.2 + (0.15 * math.sin(progress * math.pi * 2))),
      size.height * 0.25,
    );
    final Offset p2 = Offset(
      size.width * (0.75 + (0.1 * math.cos(progress * math.pi * 2))),
      size.height * 0.72,
    );

    canvas.drawCircle(p1, size.shortestSide * 0.2, pinkGlow);
    canvas.drawCircle(p2, size.shortestSide * 0.23, lavenderGlow);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
