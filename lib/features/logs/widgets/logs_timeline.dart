import 'package:fantastic_guacamole/features/logs/ui/log_time.dart';
import 'package:flutter/material.dart';

class LogsTimeline extends StatelessWidget {
  const LogsTimeline({super.key, required this.entries});

  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    logTimeFromIndex(i),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 8,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entries[i],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
