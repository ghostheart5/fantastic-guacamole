import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/firebase_options.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const bool _isTestBuild = bool.fromEnvironment('FLUTTER_TEST');

typedef FirebaseMessagingTokenRefreshHandler =
    Future<void> Function(String token);

class FirebaseNotificationOpenAdapter {
  FirebaseNotificationOpenAdapter({void Function(String payload)? onOpen})
    : _onOpen =
          onOpen ?? NotificationScheduler.queueExternalNotificationPayload;

  static const Set<String> _allowedDestinations = <String>{
    'task',
    'goal',
    'timeline',
    'siConsole',
    'home',
  };

  final void Function(String payload) _onOpen;
  final Set<String> _handledMessageKeys = <String>{};

  bool handle({required Map<String, dynamic> data, String? messageId}) {
    final String destination = (data['destination'] ?? '').toString().trim();
    if (!_allowedDestinations.contains(destination)) {
      Logger.warn(
        'Ignored Firebase notification open with unsupported destination.',
      );
      return false;
    }
    final String payload = '{"destination":"$destination"}';
    final String key = messageId?.trim().isNotEmpty == true
        ? messageId!.trim()
        : payload;
    if (!_handledMessageKeys.add(key)) {
      RuntimeDiagnostics.record(
        'Duplicate Firebase notification open ignored.',
      );
      return false;
    }
    _onOpen(payload);
    Logger.log('Push', 'Firebase notification open routed: $destination.');
    RuntimeDiagnostics.record('Firebase notification open routed.');
    return true;
  }
}

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
  static FirebaseMessagingTokenRefreshHandler? _tokenRefreshHandler;

  static String? get latestToken => _latestToken;

  static void configureTokenRefreshHandler(
    FirebaseMessagingTokenRefreshHandler? handler,
  ) {
    _tokenRefreshHandler = handler;
  }

  @visibleForTesting
  static Future<void> handleTokenRefreshForTesting(String token) {
    return _handleTokenRefresh(token);
  }

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
      final FirebaseNotificationOpenAdapter notificationOpenAdapter =
          FirebaseNotificationOpenAdapter();

      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        notificationOpenAdapter.handle(
          data: initialMessage.data,
          messageId: initialMessage.messageId,
        );
      }

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        notificationOpenAdapter.handle(
          data: message.data,
          messageId: message.messageId,
        );
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.log(
          'Push',
          'Foreground push received: ${message.messageId ?? 'unknown'}',
        );
        RuntimeDiagnostics.record('Foreground push received.');
      });

      messaging.onTokenRefresh.listen(_handleTokenRefresh);

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
        await _handleTokenRefresh(token);
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

  static Future<void> _handleTokenRefresh(String token) async {
    final String normalized = token.trim();
    if (normalized.isEmpty) {
      Logger.warn('FCM token refresh returned empty token.');
      RuntimeDiagnostics.record('FCM token refresh returned empty token.');
      return;
    }
    _latestToken = normalized;
    Logger.log('Push', 'FCM token acquired or refreshed.');
    RuntimeDiagnostics.record('FCM token acquired or refreshed.');
    try {
      await _tokenRefreshHandler?.call(normalized);
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'Push',
        'FCM token persistence/sync failed non-fatally.',
        error,
        stackTrace,
      );
    }
  }
}
