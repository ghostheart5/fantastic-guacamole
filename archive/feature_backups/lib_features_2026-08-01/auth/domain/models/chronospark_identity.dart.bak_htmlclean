enum ChronoSparkAccountTier { guest, free, pro, founder, enterprise }

enum ChronoSparkAuthProvider {
  email,
  google,
  github,
  apple,
  microsoft,
  anonymous,
}

enum ChronoSparkIdentitySyncStatus { signedOut, localOnly, synced, degraded }

class ChronoSparkIdentity {
  const ChronoSparkIdentity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.lastActiveAt,
    this.photoUrl,
    this.futureVersionName,
    this.lifeOsMission,
    this.identityStage,
    this.accountTier = ChronoSparkAccountTier.free,
    this.authProvider = ChronoSparkAuthProvider.email,
    this.syncStatus = ChronoSparkIdentitySyncStatus.localOnly,
    this.emailVerified = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? futureVersionName;
  final String? lifeOsMission;
  final String? identityStage;
  final ChronoSparkAccountTier accountTier;
  final ChronoSparkAuthProvider authProvider;
  final ChronoSparkIdentitySyncStatus syncStatus;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  bool get isSignedIn => syncStatus != ChronoSparkIdentitySyncStatus.signedOut;

  String get displayLabel {
    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    if (email.trim().isNotEmpty) {
      return email.trim();
    }
    return 'Operator';
  }

  ChronoSparkIdentity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? futureVersionName,
    String? lifeOsMission,
    String? identityStage,
    ChronoSparkAccountTier? accountTier,
    ChronoSparkAuthProvider? authProvider,
    ChronoSparkIdentitySyncStatus? syncStatus,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return ChronoSparkIdentity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      futureVersionName: futureVersionName ?? this.futureVersionName,
      lifeOsMission: lifeOsMission ?? this.lifeOsMission,
      identityStage: identityStage ?? this.identityStage,
      accountTier: accountTier ?? this.accountTier,
      authProvider: authProvider ?? this.authProvider,
      syncStatus: syncStatus ?? this.syncStatus,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'futureVersionName': futureVersionName,
      'lifeOsMission': lifeOsMission,
      'identityStage': identityStage,
      'accountTier': accountTier.name,
      'authProvider': authProvider.name,
      'syncStatus': syncStatus.name,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
    };
  }

  static ChronoSparkIdentity fromJson(Map<String, Object?> json) {
    return ChronoSparkIdentity(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Operator',
      photoUrl: json['photoUrl']?.toString(),
      futureVersionName: json['futureVersionName']?.toString(),
      lifeOsMission: json['lifeOsMission']?.toString(),
      identityStage: json['identityStage']?.toString(),
      accountTier: ChronoSparkAccountTier.values.firstWhere(
        (ChronoSparkAccountTier value) =>
            value.name == json['accountTier']?.toString(),
        orElse: () => ChronoSparkAccountTier.free,
      ),
      authProvider: ChronoSparkAuthProvider.values.firstWhere(
        (ChronoSparkAuthProvider value) =>
            value.name == json['authProvider']?.toString(),
        orElse: () => ChronoSparkAuthProvider.email,
      ),
      syncStatus: ChronoSparkIdentitySyncStatus.values.firstWhere(
        (ChronoSparkIdentitySyncStatus value) =>
            value.name == json['syncStatus']?.toString(),
        orElse: () => ChronoSparkIdentitySyncStatus.localOnly,
      ),
      emailVerified: json['emailVerified'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      lastActiveAt:
          DateTime.tryParse(json['lastActiveAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
