import 'package:fantastic_guacamole/core/debug/logger.dart';
// Storage
import 'package:fantastic_guacamole/core/storage/hive_service.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/storage/storage_migration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ChronoSpark DI Container
/// Initializes all core systems and registers global providers.
@Deprecated(
  'Use app bootstrap and providers in data/di/services_providers.dart instead.',
)
class DI {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Storage initialization
    await HiveService.init();
    await SharedPrefsService.init();
    await StorageMigration.run();

    _initialized = true;
    Logger.log('DI', 'Initialized');
  }
}

/// ------------------------------
/// ROOT PROVIDER SCOPE
/// ------------------------------

@Deprecated('Use ProviderScope directly from main.dart/app root instead.')
ProviderScope buildAppScope(Widget child) {
  return ProviderScope(overrides: [], child: child);
}
