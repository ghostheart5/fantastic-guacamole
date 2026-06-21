import 'env.dart';

class AppConfig {
  final String appName;
  final String flavor;
  final bool verboseLogs;

  const AppConfig({
    required this.appName,
    required this.flavor,
    required this.verboseLogs,
  });

  factory AppConfig.fromEnv() {
    return const AppConfig(
      appName: Env.appName,
      flavor: Env.appFlavor,
      verboseLogs: Env.enableVerboseLogs,
    );
  }
}
