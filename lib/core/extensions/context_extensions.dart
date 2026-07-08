import 'package:flutter/material.dart';

extension ContextExt on BuildContext {
  // MediaQuery
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;
  Orientation get orientation => MediaQuery.of(this).orientation;

  // Theme
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isLight => Theme.of(this).brightness == Brightness.light;

  // Navigation
  NavigatorState get navigator => Navigator.of(this);
  void pop<T>([T? result]) => Navigator.of(this).pop(result);

  // Scaffold
  ScaffoldMessengerState get messenger => ScaffoldMessenger.of(this);
  void showSnackBar(SnackBar snackBar) =>
      ScaffoldMessenger.of(this).showSnackBar(snackBar);
}
