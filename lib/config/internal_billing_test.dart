import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';

/// Explicit license-test build capability. It never grants premium access.
/// Public subscription and AI launch gates remain independent.
final class InternalBillingTestConfig {
  const InternalBillingTestConfig({
    required this.requested,
    required this.accountDigests,
    this.publicCreditAdmissionQa = false,
  });

  static const compiled = InternalBillingTestConfig(
    requested: bool.fromEnvironment('CHRONOSPARK_INTERNAL_BILLING_TEST'),
    accountDigests: String.fromEnvironment(
      'CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS',
    ),
    publicCreditAdmissionQa: bool.fromEnvironment(
      'CHRONOSPARK_PUBLIC_CREDIT_ADMISSION_QA',
    ),
  );

  final bool requested;
  final String accountDigests;

  /// Routes license-test credit packs through the one-use public admission.
  /// It has no effect without the authenticated internal billing cohort.
  final bool publicCreditAdmissionQa;

  bool get hasValidCohort {
    final List<String> values = accountDigests.split(',');
    final Set<String> excluded = <String>{
      for (final String value in <String>['', 'v2.signed_out', 'v2.unsafe'])
        sha256.convert(utf8.encode(value)).toString(),
    };
    return values.isNotEmpty &&
        values.length <= 100 &&
        values.toSet().length == values.length &&
        values.every(
          (String value) =>
              RegExp(r'^[a-f0-9]{64}$').hasMatch(value) &&
              !excluded.contains(value),
        );
  }

  bool allows({
    required AccountStorageScope scope,
    required bool isProduction,
    required bool cloudServicesEnabled,
    required bool isAndroid,
    required bool hasBillingBypass,
  }) {
    if (!requested ||
        !hasValidCohort ||
        !isProduction ||
        !cloudServicesEnabled ||
        !isAndroid ||
        hasBillingBypass ||
        !scope.isAuthenticated ||
        scope.v2Namespace == null) {
      return false;
    }
    final String digest = sha256
        .convert(utf8.encode(scope.v2Namespace!))
        .toString();
    return accountDigests.split(',').contains(digest);
  }
}
