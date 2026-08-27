import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap();

  static Future<String?>? _initialization;

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode) {
      return null;
    }
    final Future<String?>? inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final Future<String?> initialization = _initializeOnce();
    _initialization = initialization;
    return initialization;
  }

  Future<String?> _initializeOnce() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 12));

        if (_supportsCrashlytics) {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
            Env.enableCrashReporting,
          );
        }
      }
      return null;
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        return null;
      }
      return 'Firebase initialization failed: $error';
    } on TimeoutException {
      return 'Firebase initialization timed out. The app started in degraded mode.';
    } on Object catch (error) {
      return 'Firebase initialization failed: $error';
    }
  }

  bool get _supportsCrashlytics {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }
}
