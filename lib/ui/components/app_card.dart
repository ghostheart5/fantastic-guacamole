import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  const AppCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
