class UserEntity {
  const UserEntity({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.preferences = const {},
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final Map<String, dynamic> preferences;

  UserEntity copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) => UserEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    preferences: preferences ?? this.preferences,
  );
}
