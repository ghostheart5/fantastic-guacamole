import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_state.dart';
import '../../../ui/system/glass_panel.dart';
import '../../../ui/system/pulse_bar.dart';
import '../../../ui/system/spark_card.dart';

class NexusPage extends StatelessWidget {
  const NexusPage({required this.onPortalTap, super.key});

  final ValueChanged<int> onPortalTap;

  @override
  Widget build(BuildContext context) {
    final Decision? decision =
        context.select<AppState, Decision?>((AppState s) => s.decision);
    if (decision == null) {
      return const Center(child: Text('Initializing system...'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        GlassPanel(
          child: Text(
            decision.systemNote,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: PulseBar(energy: decision.energy, load: decision.workload),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.6, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (BuildContext context, double value, Widget? child) {
                return Opacity(opacity: value, child: child);
              },
              child: Image.asset(
                'assets/glows/glow_primary.png',
                width: 200,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: TweenAnimationBuilder<double>(
                key: ValueKey<String>(decision.primaryDecision),
                tween: Tween<double>(begin: 0.95, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (BuildContext context, double value, Widget? child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: SparkCard(
                  primary: true,
                  title: decision.primaryDecision,
                  subtitle: 'Primary Decision',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SparkCard(title: decision.secondaryAction, subtitle: 'Secondary Action'),
        SparkCard(title: decision.optionalAction, subtitle: 'Optional Action'),
        const SizedBox(height: 12),
        GlassPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonal(onPressed: () => onPortalTap(1), child: const Text('Creator')),
              FilledButton.tonal(onPressed: () => onPortalTap(2), child: const Text('Logs')),
              FilledButton.tonal(onPressed: () => onPortalTap(3), child: const Text('Temporal')),
              FilledButton.tonal(onPressed: () => onPortalTap(4), child: const Text('SI Console')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Mini Timeline',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text('09:00 - Focus launch', style: TextStyle(color: Color(0xFFD8D0E6))),
              Text('13:00 - Midday reassess', style: TextStyle(color: Color(0xFFD8D0E6))),
              Text('17:30 - Chronicle lock', style: TextStyle(color: Color(0xFFD8D0E6))),
            ],
          ),
        ),
      ],
    );
  }
}
