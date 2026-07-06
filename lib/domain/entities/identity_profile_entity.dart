class IdentityProfileEntity {
  const IdentityProfileEntity({
    this.disciplineIdentity = 0.1,
    this.focusIdentity = 0.1,
    this.growthIdentity = 0.1,
  });

  final double disciplineIdentity;
  final double focusIdentity;
  final double growthIdentity;

  IdentityProfileEntity copyWith({
    double? disciplineIdentity,
    double? focusIdentity,
    double? growthIdentity,
  }) {
    return IdentityProfileEntity(
      disciplineIdentity: disciplineIdentity ?? this.disciplineIdentity,
      focusIdentity: focusIdentity ?? this.focusIdentity,
      growthIdentity: growthIdentity ?? this.growthIdentity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'discipline': disciplineIdentity,
    'focus': focusIdentity,
    'growth': growthIdentity,
  };

  factory IdentityProfileEntity.fromJson(Map<String, dynamic> json) {
    return IdentityProfileEntity(
      disciplineIdentity: (json['discipline'] as num?)?.toDouble() ?? 0.1,
      focusIdentity: (json['focus'] as num?)?.toDouble() ?? 0.1,
      growthIdentity: (json['growth'] as num?)?.toDouble() ?? 0.1,
    );
  }
}
