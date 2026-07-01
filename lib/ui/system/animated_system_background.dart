import 'package:flutter/material.dart';

class AnimatedSystemBackground extends StatelessWidget {
  const AnimatedSystemBackground({super.key, required this.backgroundAsset});

  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Image.asset(
      backgroundAsset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
          const ColoredBox(color: Color(0xFF0C0812)),
=======
    return ExcludeSemantics(
      child: AnimatedBuilder(
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
      ),
>>>>>>> 979f416d61500b1beabf212d483428b7431dab3e
    );
  }
}
