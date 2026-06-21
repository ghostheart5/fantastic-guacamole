import 'package:flutter/material.dart';

class PulseBar extends StatelessWidget {
  const PulseBar({required this.energy, required this.load, super.key});

  final double energy;
  final double load;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'System Pulse',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFA99DBE)),
        ),
        const SizedBox(height: 10),
        _line('Energy', energy, const Color(0xFFC2A7FF)),
        const SizedBox(height: 8),
        _line('Load', load, const Color(0xFFFF8FB6)),
      ],
    );
  }

  Widget _line(String label, double value, Color accent) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      builder: (BuildContext context, double animated, Widget? child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: const TextStyle(color: Color(0xFFD8D0E6), fontSize: 12)),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double trackWidth = constraints.maxWidth;
                return Container(
                  height: 9,
                  width: trackWidth,
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      height: 9,
                      width: animated * trackWidth,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
