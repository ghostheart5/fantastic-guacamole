import 'dart:convert';

import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/chronospark_identity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalIdentityRepository implements ChronoSparkIdentityRepository {
  static const String _identityKey = 'chronospark.identity';

  @override
  Future<ChronoSparkIdentity?> loadIdentity() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? raw = prefs.getString(_identityKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return ChronoSparkIdentity.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  }

  @override
  Future<void> saveIdentity(ChronoSparkIdentity identity) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(_identityKey, jsonEncode(identity.toJson()));
  }

  @override
  Future<void> clearIdentity() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(_identityKey);
  }

  @override
  Future<void> updateLifeOs({
    required String mission,
    required String identityStage,
    required String futureVersionName,
  }) async {
    final ChronoSparkIdentity? identity = await loadIdentity();

    if (identity == null) {
      return;
    }

    await saveIdentity(
      identity.copyWith(
        lifeOsMission: mission,
        identityStage: identityStage,
        futureVersionName: futureVersionName,
      ),
    );
  }

  @override
  Future<void> updateLastActive(DateTime lastActiveAt) async {
    final ChronoSparkIdentity? identity = await loadIdentity();

    if (identity == null) {
      return;
    }

    await saveIdentity(identity.copyWith(lastActiveAt: lastActiveAt));
  }
}
