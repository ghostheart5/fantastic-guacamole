import 'package:flutter/foundation.dart';

import '../config/env.dart';

class Logger {
  static void debug(String message) {
    assert(() {
      if (Env.enableVerboseLogs) debugPrint('[DEBUG] $message');
      return true;
    }());
  }

  static void info(String message) {
    if (Env.enableVerboseLogs) debugPrint('[INFO] $message');
  }

  static void warn(String message) {
    debugPrint('[WARN] $message');
  }

  static void error(String message) {
    debugPrint('[ERROR] $message');
  }
}
