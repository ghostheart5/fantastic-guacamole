import 'package:flutter/material.dart';

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

    return ElevatedButton(
      onPressed: action,
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
      child: Text(caption),
    );
  }
}
