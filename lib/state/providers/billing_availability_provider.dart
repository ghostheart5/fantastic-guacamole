import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/internal_billing_test.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final internalBillingTestConfigProvider = Provider<InternalBillingTestConfig>(
  (ref) => InternalBillingTestConfig.compiled,
);

final internalBillingTestEnabledProvider = Provider<bool>((ref) {
  final config = ref.watch(internalBillingTestConfigProvider);
  if (!config.requested || !config.hasValidCohort) return false;
  return config.allows(
    scope: ref.watch(accountStorageScopeProvider),
    isProduction: Env.isProduction,
    cloudServicesEnabled: Env.cloudServicesEnabled,
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    hasBillingBypass:
        Env.isMockLoginEnabled ||
        Env.isMockMode ||
        Env.isPaywallDisabled ||
        Env.hasTesterFullAccess,
  );
});

final subscriptionPurchasingEnabledProvider = Provider<bool>((ref) {
  return Env.paidCreditPlansEnabled ||
      ref.watch(internalBillingTestEnabledProvider);
});
