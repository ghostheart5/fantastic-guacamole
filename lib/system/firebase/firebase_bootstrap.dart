import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap();

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode) {
      return null;
    }

    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 12));
        }

        if (_supportsCrashlytics) {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
            Env.enableCrashReporting,
          );
          _reportCollectionState(
            name: 'Crashlytics',
            enabled: Env.enableCrashReporting,
          );
        }

        if (_supportsAnalytics) {
          final bool analyticsEnabled =
              Env.enableAnalytics && kReleaseMode && Env.isProduction;
          await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
            analyticsEnabled,
          );
          _reportCollectionState(name: 'Analytics', enabled: analyticsEnabled);
        } else {
          Logger.warn(
            'Firebase Analytics bootstrap skipped on unsupported platform: $defaultTargetPlatform',
          );
          RuntimeDiagnostics.record(
            'Firebase Analytics bootstrap skipped on unsupported platform: $defaultTargetPlatform',
          );
        }
        return null;
      } on FirebaseException catch (error) {
        if (error.code == 'duplicate-app') {
          return null;
        }
        if (attempt >= maxAttempts) {
          return 'Firebase initialization failed: $error';
        }
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          return 'Firebase initialization timed out. The app started in degraded mode.';
        }
      } on Exception catch (error) {
        if (attempt >= maxAttempts) {
          return 'Firebase initialization failed: $error';
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return 'Firebase initialization failed after retries.';
  }

  bool get _supportsCrashlytics {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  bool get _supportsAnalytics {
    if (kIsWeb) {
      return true;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _reportCollectionState({required String name, required bool enabled}) {
    final String state =
        '$name collection enabled=$enabled '
        '(release=$kReleaseMode production=${Env.isProduction} configured=${name == 'Analytics' ? Env.enableAnalytics : Env.enableCrashReporting}).';
    RuntimeDiagnostics.record(state);
    if (kReleaseMode && Env.isProduction && !enabled) {
      Logger.error(
        '$name collection is disabled in a production release build.',
      );
    } else {
      Logger.log('Firebase', state);
    }
  }
}
