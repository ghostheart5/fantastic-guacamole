import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionRecoveryProvider = Provider<SessionRecoveryService>((Ref ref) {
  final AuthSessionBoundary boundary = ref.watch(authSessionBoundaryProvider);
  return SessionRecoveryService(storageScope: boundary.userId ?? 'signed_out');
});
