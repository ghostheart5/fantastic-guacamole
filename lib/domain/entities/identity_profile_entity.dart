/// CHRONOSPARK-CLASS: SHIPPING | Feature: Identity/onboarding
class IdentityProfileEntity {
  const IdentityProfileEntity({
    this.disciplineIdentity = 0.1,
    this.executionIdentity = 0.1,
    this.growthIdentity = 0.1,
  });

  final double disciplineIdentity;
  final double executionIdentity;
  final double growthIdentity;

  IdentityProfileEntity copyWith({
    double? disciplineIdentity,
    double? executionIdentity,
    double? growthIdentity,
  }) {
    return IdentityProfileEntity(
      disciplineIdentity: disciplineIdentity ?? this.disciplineIdentity,
      executionIdentity: executionIdentity ?? this.executionIdentity,
      growthIdentity: growthIdentity ?? this.growthIdentity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'discipline': disciplineIdentity,
    'execution': executionIdentity,
    'growth': growthIdentity,
  };

  factory IdentityProfileEntity.fromJson(Map<String, dynamic> json) {
    return IdentityProfileEntity(
      disciplineIdentity: (json['discipline'] as num?)?.toDouble() ?? 0.1,
      executionIdentity:
          (json['execution'] as num?)?.toDouble() ??
          (json['fo'
                      'cus']
                  as num?)
              ?.toDouble() ??
          0.1,
      growthIdentity: (json['growth'] as num?)?.toDouble() ?? 0.1,
    );
  }
}
