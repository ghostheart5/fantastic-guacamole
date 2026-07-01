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
    final AppState appState = Provider.of<AppState>(context);
    final Decision? decision = appState.decision;
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
