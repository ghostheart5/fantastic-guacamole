import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const bool _isTestBuild = bool.fromEnvironment('FLUTTER_TEST');

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

  static String? get latestToken => _latestToken;

  static void configureBackgroundHandler() {
    if (kIsWeb) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode || kIsWeb || _isTestBuild) {
      return null;
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.log(
          'Push',
          'Foreground push received: ${message.messageId ?? 'unknown'}',
        );
        RuntimeDiagnostics.record('Foreground push received.');
      });

      messaging.onTokenRefresh.listen((String refreshedToken) {
        if (refreshedToken.trim().isEmpty) {
          Logger.warn('FCM token refresh returned empty token.');
          RuntimeDiagnostics.record('FCM token refresh returned empty token.');
          return;
        }
        _latestToken = refreshedToken.trim();
        Logger.log('Push', 'FCM token refreshed.');
        RuntimeDiagnostics.record('FCM token refreshed.');
      });

      unawaited(_primeMessaging(messaging));

      return null;
    } on TimeoutException catch (error) {
      Logger.warn('Firebase Messaging initialization timed out: $error');
      RuntimeDiagnostics.record('Firebase Messaging initialization timed out.');
      return null;
    } on Exception catch (error) {
      Logger.warn('Firebase Messaging initialization failed: $error');
      RuntimeDiagnostics.record('Firebase Messaging initialization failed.');
      return null;
    }
  }

  Future<void> _primeMessaging(FirebaseMessaging messaging) async {
    try {
      await messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 5));

      final String? token = await messaging.getToken().timeout(
        const Duration(seconds: 10),
      );
      if (token != null && token.trim().isNotEmpty) {
        _latestToken = token.trim();
        Logger.log('Push', 'FCM token acquired.');
        RuntimeDiagnostics.record('FCM token acquired.');
      } else {
        Logger.warn('FCM token is empty.');
        RuntimeDiagnostics.record('FCM token is empty.');
      }
    } on TimeoutException catch (error) {
      Logger.warn('Firebase Messaging warmup timed out: $error');
      RuntimeDiagnostics.record('Firebase Messaging warmup timed out.');
    } on Exception catch (error) {
      Logger.warn('Firebase Messaging warmup failed: $error');
      RuntimeDiagnostics.record('Firebase Messaging warmup failed.');
    }
  }
}
