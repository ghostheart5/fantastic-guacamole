import 'package:flutter/material.dart';

class BaseScreen extends StatelessWidget {
  final Widget child;

  const BaseScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
