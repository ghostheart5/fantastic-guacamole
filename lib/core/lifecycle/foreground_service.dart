import 'package:fantastic_guacamole/core/lifecycle/foreground_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _initAndStart();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    FlutterForegroundTask.stopService();
  }

  void _initAndStart() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'chronospark_focus',
        channelName: 'Focus Session',
        channelDescription: 'Keeps ChronoSpark active during focus sessions.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    FlutterForegroundTask.startService(
      notificationTitle: 'Focus Session Active',
      notificationText: 'ChronoSpark is tracking your session.',
      callback: startForegroundTask,
    );
  }
}
