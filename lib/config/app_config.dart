import 'package:fantastic_guacamole/config/env.dart';

class AppConfig {
  final String appName;
  final String flavor;
  final bool verboseLogs;
  final bool isMockMode;
  final bool isPaywallDisabled;

  const AppConfig({
    required this.appName,
    required this.flavor,
    required this.verboseLogs,
    required this.isMockMode,
    required this.isPaywallDisabled,
  });

  factory AppConfig.fromEnv() {
    return AppConfig(
      appName: Env.appName,
      flavor: Env.appFlavor,
      verboseLogs: Env.enableVerboseLogs,
      isMockMode: Env.isMockMode,
      isPaywallDisabled: Env.isPaywallDisabled,
    );
  }
}
