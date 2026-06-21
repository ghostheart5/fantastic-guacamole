import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'chronospark_system_app.dart';
import 'core/di/app_locator.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Firebase options may not be configured in local dev yet.
  }

  // Touch the singleton to initialise all repository singletons before
  // the widget tree is built.
  AppLocator.instance;
  runApp(const ChronoSparkSystemApp());
}
