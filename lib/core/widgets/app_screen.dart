import 'package:fantastic_guacamole/theme/theme.dart';
import 'package:flutter/material.dart';

class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.child,
    this.floatingActionButton,
    this.padding,
    super.key,
  });

  final Widget child;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
