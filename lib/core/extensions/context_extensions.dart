import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;

  void popSafe<T extends Object?>([T? result]) {
    if (Navigator.canPop(this)) {
      Navigator.pop(this, result);
    }
  }
}
