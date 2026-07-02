import 'package:fantastic_guacamole/ui/layout/holo_background.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoloBackground(child: SafeArea(child: child)),
    );
  }
}
