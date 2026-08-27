import 'package:flutter/material.dart';
import 'package:fantastic_guacamole/theme/radii.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: cardRadius),
      child: Padding(padding: padding, child: child),
    );
  }
}
