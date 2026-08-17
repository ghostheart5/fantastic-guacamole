import 'package:flutter/material.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    this.label,
    this.onPressed,
    this.text,
    this.onTap,
  });

  final String? label;
  final VoidCallback? onPressed;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String caption = label ?? text ?? 'Action';
    final VoidCallback? action = onPressed ?? onTap;

    return Semantics(
      button: true,
      label: caption,
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(caption),
      ),
    );
  }
}
