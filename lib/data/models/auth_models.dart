class FirebaseAuthException implements Exception {
  FirebaseAuthException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() => 'FirebaseAuthException($code, $message)';
}

const Duration defaultAccountDeletionRecentSignInWindow = Duration(minutes: 10);
const Duration defaultAccountDeletionAllowedClockSkew = Duration(minutes: 2);

bool isAccountDeletionSignInRecent(
  DateTime? lastSignInAt, {
  required DateTime now,
  Duration recentSignInWindow = defaultAccountDeletionRecentSignInWindow,
  Duration allowedClockSkew = defaultAccountDeletionAllowedClockSkew,
}) {
  if (lastSignInAt == null ||
      recentSignInWindow <= Duration.zero ||
      allowedClockSkew.isNegative) {
    return false;
  }

  final Duration age = now.toUtc().difference(lastSignInAt.toUtc());
  return age >= -allowedClockSkew && age < recentSignInWindow;
}

enum AccountDeletionReauthenticationMethod {
  password,
  recentGoogleSignIn,
  recentPhoneSignIn,
  unsupported,
}

class User {
  const User({
    required this.id,
    this.email,
    this.displayName,
    required this.emailVerified,
    this.authenticationProvider,
    this.authenticationProviders = const <String>[],
    this.lastSignInAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final String? authenticationProvider;
  final List<String> authenticationProviders;
  final DateTime? lastSignInAt;

  AccountDeletionReauthenticationMethod
  get accountDeletionReauthenticationMethod {
    final String primary = authenticationProvider?.trim().toLowerCase() ?? '';
    final Set<String> providers = <String>{
      if (primary.isNotEmpty) primary,
      ...authenticationProviders
          .map((String provider) => provider.trim().toLowerCase())
          .where((String provider) => provider.isNotEmpty),
    };
    if (providers.length == 1 && providers.contains('email')) {
      return AccountDeletionReauthenticationMethod.password;
    }
    if (providers.length == 1 && providers.contains('google')) {
      return AccountDeletionReauthenticationMethod.recentGoogleSignIn;
    }
    if (providers.length == 1 && providers.contains('phone')) {
      return AccountDeletionReauthenticationMethod.recentPhoneSignIn;
    }
    return AccountDeletionReauthenticationMethod.unsupported;
  }
}

class UserCredential {
  const UserCredential({this.user});

  final User? user;
}

class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.issuedAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final DateTime issuedAt;
}
