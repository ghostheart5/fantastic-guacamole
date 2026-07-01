import 'package:flutter/material.dart';

class ThemeSettingsTile extends StatelessWidget {
  const ThemeSettingsTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Image.asset(
          'assets/icons/theme_icon.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.palette_outlined, size: 28),
        ),
        title: const Text('Neon Recall Theme'),
        subtitle: const Text('Switch to memory-focused color profile'),
      ),
    );
  }
}
