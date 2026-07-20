import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/sensitive_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (Ref ref) => const FlutterSecureStorage(),
);

final secureStoreProvider = Provider<SecureStore>((Ref ref) {
  return SecureStore(
    backend: Env.isMockMode
        ? InMemorySecureStoreBackend()
        : RealSecureStoreBackend(
            storage: ref.read(flutterSecureStorageProvider),
          ),
  );
});

final hiveStoreProvider = Provider<HiveStore>(
  (Ref ref) {
    HiveService.configureSecureStore(ref.read(secureStoreProvider));
    return const HiveStoreAdapter();
  },
);

final sharedPrefsStoreProvider = Provider<SharedPrefsStore>(
  (Ref ref) => const SharedPrefsStoreAdapter(),
);

final sensitivePrefsStoreProvider = Provider<SharedPrefsStore>(
  (Ref ref) => SensitivePrefsStore.instance,
);

final supabaseClientProvider = Provider<sb.SupabaseClient?>((Ref ref) {
  if (!Env.isSupabaseConfigured) {
    return null;
  }
  try {
    return sb.Supabase.instance.client;
  } on Object catch (error) {
    Logger.warn('Supabase is configured but not initialized: $error');
    return null;
  }
});
