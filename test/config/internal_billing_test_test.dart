import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/config/internal_billing_test.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scope = AccountStorageScope.authenticated('billing-test-owner');
  final digest = sha256.convert(utf8.encode(scope.v2Namespace!)).toString();
  final config = InternalBillingTestConfig(
    requested: true,
    accountDigests: digest,
  );

  bool allowed({
    AccountStorageScope? account,
    bool production = true,
    bool cloud = true,
    bool android = true,
    bool bypass = false,
    InternalBillingTestConfig? policy,
  }) => (policy ?? config).allows(
    scope: account ?? scope,
    isProduction: production,
    cloudServicesEnabled: cloud,
    isAndroid: android,
    hasBillingBypass: bypass,
  );

  test(
    'only the verified cohort in an explicit Android cloud release can buy',
    () {
      expect(allowed(), isTrue);
      expect(allowed(account: const AccountStorageScope.signedOut()), isFalse);
      expect(allowed(account: const AccountStorageScope.unsafe()), isFalse);
      expect(
        allowed(account: AccountStorageScope.authenticated('another-owner')),
        isFalse,
      );
      expect(allowed(production: false), isFalse);
      expect(allowed(cloud: false), isFalse);
      expect(allowed(android: false), isFalse);
      expect(allowed(bypass: true), isFalse);
      expect(
        allowed(
          policy: InternalBillingTestConfig(
            requested: false,
            accountDigests: digest,
          ),
        ),
        isFalse,
      );
    },
  );

  test('empty, malformed, duplicate and unsafe cohorts fail closed', () {
    for (final value in [
      '',
      'raw-account-id',
      '$digest,',
      '$digest,$digest',
      sha256.convert(utf8.encode('v2.signed_out')).toString(),
      sha256.convert(utf8.encode('v2.unsafe')).toString(),
    ]) {
      expect(
        allowed(
          policy: InternalBillingTestConfig(
            requested: true,
            accountDigests: value,
          ),
        ),
        isFalse,
      );
    }
  });

  test('ordinary builds and paid AI containment stay closed', () {
    expect(InternalBillingTestConfig.compiled.requested, isFalse);
    expect(LaunchContainment.subscriptionsEnabled, isFalse);
    expect(LaunchContainment.paidCreditPlansEnabled, isFalse);
    expect(LaunchContainment.externalAiEnabled, isFalse);
    expect(LaunchContainment.creditSpendingEnabled, isFalse);
  });
}
