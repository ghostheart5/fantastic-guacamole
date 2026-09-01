import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:fantastic_guacamole/config/env.dart';

class AppConfig {
  const AppConfig._({
    required this.appName,
    required this.flavor,
    required this.verboseLogs,
    required this.paywallDisabled,
  });

  final String appName;
  final AppFlavor flavor;
  final bool verboseLogs;
  final bool paywallDisabled;

  static final AppConfig current = AppConfig._(
    appName: Env.appName,
    flavor: Env.flavor,
    verboseLogs: Env.enableVerboseLogs,
    paywallDisabled: Env.isPaywallDisabled,
  );

  factory AppConfig.fromEnv() => current;
}

// Legacy billing/UI alias. This indicates an explicit paywall bypass, not a
// generic billing test environment. UI should prefer appAccessProvider.
bool get paywallTestingMode => AppConfig.current.paywallDisabled;
