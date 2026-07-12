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
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  Logger.log('Push', 'Background message received: ${message.messageId ?? 'unknown'}');
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
    if (isMockMode || kIsWeb) {
      return null;
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final String? token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        _latestToken = token.trim();
        Logger.log('Push', 'FCM token acquired.');
        RuntimeDiagnostics.record('FCM token acquired.');
      } else {
        Logger.warn('FCM token is empty.');
        RuntimeDiagnostics.record('FCM token is empty.');
      }

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

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.log('Push', 'Foreground push received: ${message.messageId ?? 'unknown'}');
        RuntimeDiagnostics.record('Foreground push received.');
      });

      return null;
    } on Exception catch (error) {
      return 'Firebase Messaging initialization failed: $error';
    }
  }
}
