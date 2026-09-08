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

/// Credit testing uses the same authenticated private license-test cohort.
/// Public launch gates remain closed and per-account external-AI consent is
/// still required by the request controller and proxy.
final internalCreditTestEnabledProvider = Provider<bool>((ref) {
  return allowsInternalCreditTest(
    billingCohortAllowed: ref.watch(internalBillingTestEnabledProvider),
    aiProxyEndpoint: Env.aiProxyEndpoint,
    supabaseUrl: Env.supabaseUrl,
  );
});

bool allowsInternalCreditTest({
  required bool billingCohortAllowed,
  required String aiProxyEndpoint,
  required String supabaseUrl,
}) {
  if (!billingCohortAllowed) return false;
  final endpoint = Uri.tryParse(aiProxyEndpoint);
  final backend = Uri.tryParse(supabaseUrl);
  return endpoint != null &&
      backend != null &&
      backend.scheme == 'https' &&
      backend.host.endsWith('.supabase.co') &&
      endpoint.scheme == 'https' &&
      endpoint.host == backend.host &&
      endpoint.port == 443 &&
      backend.port == 443 &&
      endpoint.path == '/functions/v1/ai-proxy' &&
      !endpoint.hasQuery &&
      !endpoint.hasFragment &&
      endpoint.userInfo.isEmpty;
}

final externalAiAvailableProvider = Provider<bool>(
  (ref) =>
      Env.externalAiEnabled || ref.watch(internalCreditTestEnabledProvider),
);

final creditSpendingAvailableProvider = Provider<bool>(
  (ref) =>
      Env.creditSpendingEnabled || ref.watch(internalCreditTestEnabledProvider),
);

final aiProxyAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(externalAiAvailableProvider) &&
      Env.resolveIsAiProxyConfigured(Env.aiProxyEndpoint),
);
