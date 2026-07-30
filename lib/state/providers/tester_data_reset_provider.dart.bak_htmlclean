import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/state/controllers/tester_data_reset_controller.dart';
import 'package:fantastic_guacamole/state/services/tester_data_reset_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final testerDataResetServiceProvider = Provider<TesterDataResetService>((ref) {
  return TesterDataResetService(
    preferences: ref.read(sharedPrefsStoreProvider),
    sensitivePreferences: ref.read(sensitivePrefsStoreProvider),
    hive: ref.read(hiveStoreProvider),
    secureStore: ref.read(secureStoreProvider),
  );
});

final testerDataResetControllerProvider = Provider<TesterDataResetController>((
  ref,
) {
  return TesterDataResetController(
    ref,
    ref.read(testerDataResetServiceProvider),
  );
});
