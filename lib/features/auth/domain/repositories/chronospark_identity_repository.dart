import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';

abstract class ChronoSparkIdentityRepository {
  Future<ChronoSparkIdentity?> loadIdentity();

  Future<void> saveIdentity(ChronoSparkIdentity identity);

  Future<void> clearIdentity();

  Future<void> updateLifeOs({
    required String mission,
    required String identityStage,
    required String futureVersionName,
  });

  Future<void> updateLastActive(DateTime lastActiveAt);
}
