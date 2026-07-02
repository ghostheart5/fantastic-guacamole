import 'package:flutter/material.dart';

class AppTap extends StatelessWidget {
  const AppTap({
    required this.child,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: child,
    );
  }
}
