class FirebaseAuthException implements Exception {
  FirebaseAuthException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() => 'FirebaseAuthException($code, $message)';
}

class User {
  const User({
    required this.id,
    this.email,
    this.displayName,
    required this.emailVerified,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool emailVerified;
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
