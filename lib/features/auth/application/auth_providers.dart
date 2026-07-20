import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:fantastic_guacamole/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/secure_store_auth_local_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/validators/auth_input_validator.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_controller.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((Ref ref) {
  return SupabaseAuthRemoteDataSource(authService: ref.read(authServiceProvider));
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((Ref ref) {
  return SecureStoreAuthLocalDataSource(secureStore: ref.read(secureStoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.read(authRemoteDataSourceProvider),
    localDataSource: ref.read(authLocalDataSourceProvider),
  );
});

final authInputValidatorProvider = Provider<AuthInputValidator>((Ref ref) {
  return const AuthInputValidator();
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (Ref ref) {
    return AuthController(
      repository: ref.read(authRepositoryProvider),
      validator: ref.read(authInputValidatorProvider),
    );
  },
);
