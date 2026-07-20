import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';

class AuthSessionEntity {
  const AuthSessionEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
    required this.issuedAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUserEntity user;
  final DateTime issuedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AuthSessionEntity copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    AuthUserEntity? user,
    DateTime? issuedAt,
  }) {
    return AuthSessionEntity(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
      'issuedAt': issuedAt.toIso8601String(),
      'user': user.toMap(),
    };
  }

  factory AuthSessionEntity.fromMap(Map<String, dynamic> map) {
    return AuthSessionEntity(
      accessToken: (map['accessToken'] ?? '').toString(),
      refreshToken: (map['refreshToken'] ?? '').toString(),
      expiresAt: DateTime.tryParse((map['expiresAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      issuedAt: DateTime.tryParse((map['issuedAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      user: AuthUserEntity.fromMap(Map<String, dynamic>.from(map['user'] as Map? ?? <String, dynamic>{})),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthSessionEntity &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt == expiresAt &&
        other.user == user &&
        other.issuedAt == issuedAt;
  }

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, expiresAt, user, issuedAt);
}
