import 'package:flutter/material.dart';

class ModuleToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ModuleToggleTile({
    super.key,
    required this.label,
    required this.subtitle,
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
        title: Text(label),
        subtitle: Text(subtitle),
      ),
    );
  }
}
