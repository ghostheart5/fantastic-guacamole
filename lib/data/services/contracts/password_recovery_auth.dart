import 'package:fantastic_guacamole/data/models/auth_models.dart';

/// Optional capability: a callback URL alone never grants password recovery.
abstract interface class PasswordRecoveryAuth {
  PasswordRecoveryState get passwordRecoveryState;
  Stream<PasswordRecoveryState> get passwordRecoveryChanges;
  Future<void> completePasswordRecovery({required String newPassword});
  Future<void> cancelPasswordRecovery();
}

class PasswordRecoveryState {
  const PasswordRecoveryState.inactive() : userId = null, revision = 0;
  const PasswordRecoveryState.pending(this.userId, this.revision);

  final String? userId;
  final int revision;
  bool get isPending => userId != null;
}

FirebaseAuthException recoverySessionRequired() => FirebaseAuthException(
  code: 'recovery-session-required',
  message: 'Open a new password reset email to continue securely.',
);
