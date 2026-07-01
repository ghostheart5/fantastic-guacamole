import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'app/app.dart';
import 'core/system/local_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.instance.initialize();

    final bool crashlyticsSupported =
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Enable Crashlytics collection and set up error handlers on supported platforms.
  if (crashlyticsSupported) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
  }

  runZonedGuarded<Future<void>>(
    () async {
      runApp(const ChronoSparkApp());
    },
    (Object error, StackTrace stackTrace) {
      if (crashlyticsSupported) {
        FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      } else {
        debugPrint('Unhandled error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    },
  );
}
