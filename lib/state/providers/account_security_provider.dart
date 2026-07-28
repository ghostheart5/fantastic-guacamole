import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AccountSecurityLevel { signedOut, basic, verified, trusted }

class AccountSecurityState {
  const AccountSecurityState({
    required this.level,
    required this.emailVerified,
    required this.sessionActive,
    required this.deviceTrusted,
    required this.passwordResetAvailable,
    required this.summary,
    required this.recommendation,
  });

  final AccountSecurityLevel level;
  final bool emailVerified;
  final bool sessionActive;
  final bool deviceTrusted;
  final bool passwordResetAvailable;
  final String summary;
  final String recommendation;
}

final accountSecurityProvider = Provider<AccountSecurityState>((ref) {
  final ChronoSparkIdentity? identity = ref.watch(identityAccountProvider);

  if (identity == null) {
    return const AccountSecurityState(
      level: AccountSecurityLevel.signedOut,
      emailVerified: false,
      sessionActive: false,
      deviceTrusted: false,
      passwordResetAvailable: false,
      summary: 'No account identity is currently connected.',
      recommendation: 'Connect an account to enable secure identity sync.',
    );
  }

  final bool emailVerified = identity.emailVerified;
  final bool sessionActive = identity.isSignedIn;
  final bool deviceTrusted =
      identity.syncStatus == ChronoSparkIdentitySyncStatus.synced;

  final AccountSecurityLevel level = emailVerified && deviceTrusted
      ? AccountSecurityLevel.trusted
      : emailVerified
      ? AccountSecurityLevel.verified
      : AccountSecurityLevel.basic;

  final String summary = switch (level) {
    AccountSecurityLevel.trusted => 'Identity is verified and synchronized.',
    AccountSecurityLevel.verified =>
      'Email is verified. Device trust is still local or pending.',
    AccountSecurityLevel.basic =>
      'Account exists but verification is still incomplete.',
    AccountSecurityLevel.signedOut => 'No active identity session.',
  };

  final String recommendation = switch (level) {
    AccountSecurityLevel.trusted =>
      'Security posture is ready for account-based Life OS sync.',
    AccountSecurityLevel.verified =>
      'Enable full sync when backend identity persistence is connected.',
    AccountSecurityLevel.basic =>
      'Verify email before enabling advanced account sync.',
    AccountSecurityLevel.signedOut =>
      'Sign in or create an account to protect identity state.',
  };

  return AccountSecurityState(
    level: level,
    emailVerified: emailVerified,
    sessionActive: sessionActive,
    deviceTrusted: deviceTrusted,
    passwordResetAvailable: identity.email.trim().isNotEmpty,
    summary: summary,
    recommendation: recommendation,
  );
});
