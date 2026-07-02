import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';

bool get paywallTestingMode => Env.isPaywallDisabled;

void logPaywallBypass() {
  if (!paywallTestingMode) return;
  Logger.log('Paywall', 'Paywall bypassed (testing mode).');
}
