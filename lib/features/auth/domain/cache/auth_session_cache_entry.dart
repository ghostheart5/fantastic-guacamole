import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';

class AuthSessionCacheEntry {
  const AuthSessionCacheEntry({
    required this.key,
    required this.session,
    required this.cachedAt,
  });

  final String key;
  final AuthSessionEntity session;
  final DateTime cachedAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'key': key,
      'cachedAt': cachedAt.toIso8601String(),
      'session': session.toMap(),
    };
  }

  factory AuthSessionCacheEntry.fromMap(Map<String, Object?> map) {
    return AuthSessionCacheEntry(
      key: (map['key'] ?? '').toString(),
      cachedAt: DateTime.tryParse((map['cachedAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      session: AuthSessionEntity.fromMap(Map<String, dynamic>.from(map['session'] as Map? ?? <String, dynamic>{})),
    );
  }
}
