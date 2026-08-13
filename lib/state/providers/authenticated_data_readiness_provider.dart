import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single decision used before authenticated domain UI is admitted.
enum AuthenticatedDataReadiness {
  signedOut,
  transitioning,
  storageNotReady,
  blocked,
  userMismatch,
  ready,
}

final authenticatedDataReadinessProvider =
    Provider<AuthenticatedDataReadiness>((ref) {
      final User? user = ref.watch(authUserProvider).asData?.value;
      final AuthSessionBoundary boundary = ref.watch(
        authSessionBoundaryProvider,
      );
      return resolveAuthenticatedDataReadiness(user: user, boundary: boundary);
    });

AuthenticatedDataReadiness resolveAuthenticatedDataReadiness({
  required User? user,
  required AuthSessionBoundary boundary,
}) {
  final String? userId = _normalizedUserId(user?.id);
  if (userId == null) {
    return AuthenticatedDataReadiness.signedOut;
  }
  if (boundary.blockingIssue?.trim().isNotEmpty ?? false) {
    return AuthenticatedDataReadiness.blocked;
  }
  if (boundary.isTransitioning) {
    return AuthenticatedDataReadiness.transitioning;
  }
  if (!boundary.isStorageReady) {
    return AuthenticatedDataReadiness.storageNotReady;
  }
  if (_normalizedUserId(boundary.userId) != userId) {
    return AuthenticatedDataReadiness.userMismatch;
  }
  return AuthenticatedDataReadiness.ready;
}

bool isAuthenticatedDataReady(AuthenticatedDataReadiness readiness) {
  return readiness == AuthenticatedDataReadiness.ready;
}

String? _normalizedUserId(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
