import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startForegroundTask() {
  FlutterForegroundTask.setTaskHandler(ChronoForegroundHandler());
}

class ChronoForegroundHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    FlutterForegroundTask.sendDataToMain({
      'event': 'started',
      'time': timestamp.toIso8601String(),
      'starter': starter.name,
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({'event': 'tick', 'time': timestamp.toIso8601String()});
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    FlutterForegroundTask.sendDataToMain({
      'event': 'destroyed',
      'time': timestamp.toIso8601String(),
      'timeout': isTimeout,
    });
  }
}
