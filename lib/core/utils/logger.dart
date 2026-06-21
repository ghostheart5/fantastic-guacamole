import '../config/env.dart';

class Logger {
  static void info(String message) {
    if (Env.enableVerboseLogs) {
      // ignore: avoid_print
      print('[INFO] $message');
    }
  }

  static void error(String message) {
    // ignore: avoid_print
    print('[ERROR] $message');
  }
}
