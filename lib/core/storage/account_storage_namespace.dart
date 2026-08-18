import 'dart:convert';

/// Storage namespace formats kept distinct for safe compatibility decisions.
enum StorageScopeVersion { legacyV1, v2 }

/// Whether a legacy V1 record may be associated with the current scope.
enum LegacyScopeOwnership {
  provenOwned,
  provenNotOwned,
  ambiguous,
  unownedSignedOut,
}

/// Eligibility only; this foundation never copies or removes stored data.
enum LegacyMigrationEligibility { copyAllowed, retainExistingV2, preserveLegacy }

/// Canonical, versioned local storage namespace for one account or signed out.
///
/// V1 is retained only for compatibility with existing underscore-normalized
/// keys. V2 encodes the exact UTF-8 identity and therefore does not introduce
/// replacement-character collisions.
final class AccountStorageNamespace {
  const AccountStorageNamespace._authenticated(this.rawUserId);
  const AccountStorageNamespace._signedOut() : rawUserId = null;

  static const String signedOutV2 = 'v2.signed_out';
  static const String signedOutV1 = 'signed_out';

  final String? rawUserId;

  bool get isSignedOut => rawUserId == null;

  factory AccountStorageNamespace.authenticated(String userId) {
    if (userId.isEmpty || userId.trim().isEmpty || userId != userId.trim()) {
      throw ArgumentError.value(userId, 'userId', 'must be non-empty and trimmed');
    }
    return AccountStorageNamespace._authenticated(userId);
  }

  const AccountStorageNamespace.signedOut() : this._signedOut();

  /// Exact historical algorithm. Never use it to infer legacy ownership.
  static String legacyV1ScopeForUser(String? userId) {
    final String value = userId?.trim() ?? '';
    return value.isEmpty
        ? signedOutV1
        : value.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
  }

  String get v2Scope {
    final String? userId = rawUserId;
    if (userId == null) return signedOutV2;
    return 'v2.${base64UrlEncode(utf8.encode(userId))}';
  }

  String get legacyV1Scope => legacyV1ScopeForUser(rawUserId);

  String scopedKey(String baseKey, {StorageScopeVersion version = StorageScopeVersion.v2}) {
    if (baseKey.trim().isEmpty) {
      throw ArgumentError.value(baseKey, 'baseKey', 'must be non-empty');
    }
    final String scope = switch (version) {
      StorageScopeVersion.legacyV1 => legacyV1Scope,
      StorageScopeVersion.v2 => v2Scope,
    };
    return '$baseKey.$scope';
  }

  static LegacyMigrationEligibility legacyMigrationEligibility({
    required bool v2Exists,
    required bool legacyExists,
    required LegacyScopeOwnership ownership,
  }) {
    if (v2Exists) return LegacyMigrationEligibility.retainExistingV2;
    if (!legacyExists || ownership != LegacyScopeOwnership.provenOwned) {
      return LegacyMigrationEligibility.preserveLegacy;
    }
    return LegacyMigrationEligibility.copyAllowed;
  }
}
