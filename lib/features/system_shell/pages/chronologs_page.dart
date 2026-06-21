import 'package:flutter/material.dart';

import '../../../ui/system/glass_panel.dart';

class ChronoLogsPage extends StatelessWidget {
  const ChronoLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const List<String> logs = <String>[
      '08:22 - SI re-prioritized focus stack to 3 active tasks',
      '10:08 - Deep work block launched in Temporal Ops',
      '13:14 - Reflection synced from SI Console',
      '15:20 - Deadline pressure increased and timeline adjusted',
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        return GlassPanel(
          child: Text(logs[index], style: const TextStyle(color: Color(0xFFE4DDF3))),
        );
      },
    );
  }
}
