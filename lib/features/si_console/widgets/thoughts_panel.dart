import 'package:flutter/material.dart';

class ThoughtsPanel extends StatelessWidget {
  final List<String> thoughts;
  const ThoughtsPanel({super.key, required this.thoughts});

  @override
  Widget build(BuildContext context) {
    if (thoughts.isEmpty) {
      return const Text('No thoughts captured yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: thoughts.asMap().entries.map((MapEntry<int, String> entry) {
        final int index = entry.key;
        final String thought = entry.value;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('#${index + 1}  $thought'),
        );
      }).toList(),
    );
  }
}
