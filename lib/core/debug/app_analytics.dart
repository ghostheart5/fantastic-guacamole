import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/state/intelligence/intelligence_service.dart';

class AppAnalytics {
  const AppAnalytics._();

  static void track(String event, {Map<String, Object?> params = const <String, Object?>{}}) {
    final bool analyticsEnabled = const IntelligenceService()
        .environmentOnly()
        .flags
        .analyticsEnabled;
    if (!analyticsEnabled) return;

    final String payload = params.isEmpty ? '' : ' $params';
    Logger.log('Analytics', '$event$payload');
    RuntimeDiagnostics.record('Analytics: $event$payload');
  }
}
