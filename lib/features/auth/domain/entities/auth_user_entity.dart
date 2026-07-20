class AuthUserEntity {
  const AuthUserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.isAnonymous,
    this.avatarUrl,
    this.roles = const <String>[],
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final bool isAnonymous;
  final String? avatarUrl;
  final List<String> roles;

  AuthUserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? emailVerified,
    bool? isAnonymous,
    String? avatarUrl,
    List<String>? roles,
  }) {
    return AuthUserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'displayName': displayName,
      'emailVerified': emailVerified,
      'isAnonymous': isAnonymous,
      'avatarUrl': avatarUrl,
      'roles': roles,
    };
  }

  factory AuthUserEntity.fromMap(Map<String, dynamic> map) {
    return AuthUserEntity(
      id: (map['id'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      emailVerified: map['emailVerified'] == true,
      isAnonymous: map['isAnonymous'] == true,
      avatarUrl: map['avatarUrl']?.toString(),
      roles: (map['roles'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic role) => role.toString())
          .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthUserEntity &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.emailVerified == emailVerified &&
        other.isAnonymous == isAnonymous &&
        other.avatarUrl == avatarUrl &&
        _listEquals(other.roles, roles);
  }

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        emailVerified,
        isAnonymous,
        avatarUrl,
        Object.hashAll(roles),
      );

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
