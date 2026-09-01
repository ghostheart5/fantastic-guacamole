import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  group('AppConfig', () {
    test('captures one immutable environment snapshot', () {
      dotenv.loadFromString(
        envString: '''
CHRONOSPARK_VERBOSE_LOGS=true
CHRONOSPARK_PAYWALL_DISABLED=true
''',
      );
      final bool expectedVerboseLogs = Env.enableVerboseLogs;
      final bool expectedPaywallDisabled = Env.isPaywallDisabled;
      final AppConfig first = AppConfig.fromEnv();

      dotenv.loadFromString(
        envString: '''
CHRONOSPARK_VERBOSE_LOGS=false
CHRONOSPARK_PAYWALL_DISABLED=false
''',
      );
      final AppConfig second = AppConfig.fromEnv();

      expect(identical(first, AppConfig.current), isTrue);
      expect(identical(first, second), isTrue);
      expect(first.appName, Env.appName);
      expect(second.flavor, first.flavor);
      expect(first.verboseLogs, expectedVerboseLogs);
      expect(first.paywallDisabled, expectedPaywallDisabled);
    });

    test('legacy paywall alias preserves paywall-disabled behavior', () {
      expect(paywallTestingMode, AppConfig.current.paywallDisabled);
    });
  });
}
