import 'package:flutter/material.dart';

class ThemeSettingsTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ThemeSettingsTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: const Text('Neon Recall Theme'),
        subtitle: const Text('Switch to memory-focused color profile'),
      ),
    );
  }
}
