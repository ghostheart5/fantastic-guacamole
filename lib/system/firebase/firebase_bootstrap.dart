import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap({
    @visibleForTesting Future<String?> Function()? initializeCore,
    @visibleForTesting Future<String?> Function()? configureCrashlytics,
    @visibleForTesting bool? supportsCrashlytics,
  }) : _initializeCoreOverride = initializeCore,
       _configureCrashlyticsOverride = configureCrashlytics,
       _supportsCrashlyticsOverride = supportsCrashlytics;

  final Future<String?> Function()? _initializeCoreOverride;
  final Future<String?> Function()? _configureCrashlyticsOverride;
  final bool? _supportsCrashlyticsOverride;

  static Future<String?>? _coreInitialization;
  static Future<String?>? _crashlyticsConfiguration;

  @visibleForTesting
  static void resetForTesting() {
    _coreInitialization = null;
    _crashlyticsConfiguration = null;
  }

  Future<String?> initialize({
    required bool isMockMode,
    bool Function()? shouldContinue,
  }) async {
    if (!Env.cloudServicesEnabled || isMockMode) {
      return null;
    }
    if (shouldContinue?.call() == false) {
      return null;
    }
    final Future<String?> coreInitialization = _coreInitialization ??=
        _initializeCoreOverride?.call() ?? _initializeCore();
    final String? coreIssue = await coreInitialization;
    if (coreIssue != null) {
      if (identical(_coreInitialization, coreInitialization)) {
        _coreInitialization = null;
      }
      return coreIssue;
    }
    if (shouldContinue?.call() == false) {
      return null;
    }
    if (!(_supportsCrashlyticsOverride ?? _supportsCrashlytics)) {
      return null;
    }
    final Future<String?> crashlyticsConfiguration =
        _crashlyticsConfiguration ??=
            _configureCrashlyticsOverride?.call() ?? _configureCrashlytics();
    final String? crashlyticsIssue = await crashlyticsConfiguration;
    if (crashlyticsIssue != null &&
        identical(_crashlyticsConfiguration, crashlyticsConfiguration)) {
      _crashlyticsConfiguration = null;
    }
    return crashlyticsIssue;
  }

  Future<String?> _initializeCore() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return null;
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        return null;
      }
      return 'Firebase initialization failed: $error';
    } on Object catch (error) {
      return 'Firebase initialization failed: $error';
    }
  }

  Future<String?> _configureCrashlytics() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      return null;
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
