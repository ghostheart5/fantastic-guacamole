import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';

class IdentityRepository implements IIdentityRepository {
  IdentityRepository(this._store);

  final SecureStore _store;

  static const String _key = 'identity_id';
  static const String _profileKey = 'identity_profile_v1';

  @override
  Future<String?> getIdentityId() => _store.readString(_key);

  @override
  Future<void> saveIdentityId(String id) => _store.writeString(_key, id);

  @override
  Future<IdentityProfileEntity?> getIdentityProfile() async {
    final String? raw = await _store.readString(_profileKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return IdentityProfileEntity.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveIdentityProfile(IdentityProfileEntity profile) {
    return _store.writeString(_profileKey, jsonEncode(profile.toJson()));
  }
}
