import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';

abstract class ChronoSparkAuthService {
  Future<ChronoSparkIdentity?> currentIdentity();

  Future<ChronoSparkIdentity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<ChronoSparkIdentity> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> sendEmailVerification();

  Future<void> signOut();

  Future<void> deleteAccount();
}
