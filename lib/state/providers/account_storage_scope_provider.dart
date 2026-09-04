import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Derives local persistence eligibility from the lifecycle boundary; it does
/// not listen to authentication or coordinate transitions itself.
final accountStorageScopeProvider = Provider<AccountStorageScope>((ref) {
  final User? user = ref.watch(authUserProvider).asData?.value;
  final AuthSessionBoundary boundary = ref.watch(authSessionBoundaryProvider);
  return resolveAccountStorageScope(user: user, boundary: boundary);
});

/// Legacy data may be read only after the auth boundary proves that the
/// writable account owns it. Different and transitioning accounts preserve
/// legacy values without exposing or migrating them.
final accountLegacyOwnershipProvider = Provider<LegacyScopeOwnership>((ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (scope.state == AccountStorageScopeState.signedOut) {
    return LegacyScopeOwnership.unownedSignedOut;
  }
  if (!scope.isWritable) return LegacyScopeOwnership.ambiguous;
  return ref.watch(authSessionBoundaryProvider).legacyOwnership;
});

AccountStorageScope resolveAccountStorageScope({
  required User? user,
  required AuthSessionBoundary boundary,
}) {
  if (user == null) return const AccountStorageScope.signedOut();
  final String rawUserId = user.id;
  final String normalizedUserId = rawUserId.trim();
  if (normalizedUserId.isEmpty || rawUserId != normalizedUserId) {
    return const AccountStorageScope.unsafe();
  }
  if (boundary.isTransitioning ||
      !boundary.isStorageReady ||
      (boundary.blockingIssue?.trim().isNotEmpty ?? false) ||
      boundary.userId?.trim() != normalizedUserId) {
    return const AccountStorageScope.unsafe();
  }
  return AccountStorageScope.authenticated(rawUserId);
}
