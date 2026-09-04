import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  Logger.log(
    'Push',
    'Background message received: ${message.messageId ?? 'unknown'}',
  );
  RuntimeDiagnostics.record('Push background message received.');
}

class FirebaseMessagingBootstrap {
  const FirebaseMessagingBootstrap();

  static String? _latestToken;
  static Future<String?>? _initialization;
  static final ValueNotifier<String?> tokenListenable = ValueNotifier<String?>(
    null,
  );

  static String? get latestToken => _latestToken;

  /// Invalidates this installation's current FCM token before an account
  /// boundary. This is the fallback that prevents a stale server row from
  /// delivering the departing account's notifications to a later account.
  Future<void> revokeDeviceToken() async {
    if (_latestToken == null) {
      return;
    }
    if (!kIsWeb) {
      await FirebaseMessaging.instance.deleteToken();
    }
    _latestToken = null;
    tokenListenable.value = null;
  }

  static void configureBackgroundHandler() {
    if (kIsWeb) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode || kIsWeb) {
      return null;
    }
    final Future<String?>? inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final Future<String?> initialization = _initializeOnce();
    _initialization = initialization;
    final String? result = await initialization;
    if (result != null && identical(_initialization, initialization)) {
      _initialization = null;
    }
    return result;
  }

  Future<String?> _initializeOnce() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      messaging.onTokenRefresh.listen((String refreshedToken) {
        if (refreshedToken.trim().isEmpty) {
          Logger.warn('FCM token refresh returned empty token.');
          RuntimeDiagnostics.record('FCM token refresh returned empty token.');
          return;
        }
        _latestToken = refreshedToken.trim();
        tokenListenable.value = _latestToken;
        Logger.log('Push', 'FCM token refreshed.');
        RuntimeDiagnostics.record('FCM token refreshed.');
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.log(
          'Push',
          'Foreground push received: ${message.messageId ?? 'unknown'}',
        );
        RuntimeDiagnostics.record('Foreground push received.');
      });

      return null;
    } on Object {
      Logger.warn('Firebase Messaging initialization failed.');
      RuntimeDiagnostics.record('Firebase Messaging initialization failed.');
      return 'Firebase Messaging initialization failed.';
    }
  }

  /// Requests push permission and obtains a token only after an explicit
  /// user-facing notification action. Startup calls [initialize], which only
  /// installs listeners and never opens an operating-system prompt.
  Future<String?> requestPermissionAndToken({required bool isMockMode}) async {
    if (isMockMode || kIsWeb) {
      return null;
    }
    configureBackgroundHandler();
    final String? initializationError = await initialize(isMockMode: false);
    if (initializationError != null) {
      return initializationError;
    }
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return 'Push notification permission was denied.';
      }
      final String? token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return 'Push notification registration is unavailable.';
      }
      _latestToken = token.trim();
      tokenListenable.value = _latestToken;
      Logger.log('Push', 'FCM token acquired after explicit permission.');
      RuntimeDiagnostics.record(
        'FCM token acquired after explicit permission.',
      );
      return null;
    } on Object catch (_) {
      return 'Push notification registration failed.';
    }
  }
}
