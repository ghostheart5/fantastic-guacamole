import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.neonCyan,
          activeTrackColor: AppColors.neonCyan.withValues(alpha: 0.3),
          inactiveTrackColor: Colors.white12,
          inactiveThumbColor: Colors.white38,
        ),
      ],
    );
  }
}
