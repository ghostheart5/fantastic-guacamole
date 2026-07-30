import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';

class ProfileRepository implements IProfileRepository {
  ProfileRepository(this._store);

  static const String _profileKey = 'profile_entity_v1';
  final SecureStore _store;

  @override
  Future<ProfileEntity?> getProfile() async {
    final String? raw = await _store.readString(_profileKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return ProfileEntity(
      xp: (decoded['xp'] as num?)?.toInt() ?? 0,
      level: (decoded['level'] as num?)?.toInt() ?? 1,
      streak: (decoded['streak'] as num?)?.toInt() ?? 0,
      leveledUp: (decoded['leveledUp'] as bool?) ?? false,
    );
  }

  @override
  Future<void> saveProfile(ProfileEntity profile) {
    return _store.writeString(
      _profileKey,
      jsonEncode(<String, dynamic>{
        'xp': profile.xp,
        'level': profile.level,
        'streak': profile.streak,
        'leveledUp': profile.leveledUp,
      }),
    );
  }
}
