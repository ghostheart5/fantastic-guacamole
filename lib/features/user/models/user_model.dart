import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.preferences = const {},
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final Map<String, dynamic> preferences;

  UserModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) => UserModel(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    preferences: preferences ?? this.preferences,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'preferences': preferences,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    preferences: (json['preferences'] as Map<String, dynamic>?) ?? const {},
  );
}
