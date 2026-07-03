// ChronoSpark FirebaseOptions
// Paste your generated values from `flutterfire configure`.
// This file is stable and does not change across environments.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ------------------------------------------------------------
  // WEB
  // ------------------------------------------------------------
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "PASTE_WEB_API_KEY",
    appId: "PASTE_WEB_APP_ID",
    messagingSenderId: "PASTE_WEB_SENDER_ID",
    projectId: "PASTE_PROJECT_ID",
    authDomain: "PASTE_AUTH_DOMAIN",
    storageBucket: "PASTE_STORAGE_BUCKET",
  );

  // ------------------------------------------------------------
  // ANDROID
  // ------------------------------------------------------------
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBEdXHOa-AZLTDCi97SBqD4fAvH3vdnneU",
    appId: "1:956622397052:android:3ecf5fcda0f2e1ef9133f9",
    messagingSenderId: "956622397052",
    projectId: "chronospark-app",
    storageBucket: "chronospark-app.firebasestorage.app",
  );

  // ------------------------------------------------------------
  // iOS
  // ------------------------------------------------------------
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "PASTE_IOS_API_KEY",
    appId: "1:956622397052:ios:4a522f3f234d24959133f9",
    messagingSenderId: "PASTE_IOS_SENDER_ID",
    projectId: "PASTE_PROJECT_ID",
    iosBundleId: "PASTE_IOS_BUNDLE_ID",
    storageBucket: "PASTE_STORAGE_BUCKET",
  );

  // ------------------------------------------------------------
  // macOS
  // ------------------------------------------------------------
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "PASTE_MACOS_API_KEY",
    appId: "PASTE_MACOS_APP_ID",
    messagingSenderId: "PASTE_MACOS_SENDER_ID",
    projectId: "PASTE_PROJECT_ID",
    iosBundleId: "PASTE_MACOS_BUNDLE_ID",
    storageBucket: "PASTE_STORAGE_BUCKET",
  );

  // ------------------------------------------------------------
  // WINDOWS
  // ------------------------------------------------------------
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "PASTE_WINDOWS_API_KEY",
    appId: "PASTE_WINDOWS_APP_ID",
    messagingSenderId: "PASTE_WINDOWS_SENDER_ID",
    projectId: "PASTE_PROJECT_ID",
    storageBucket: "PASTE_STORAGE_BUCKET",
  );

  // ------------------------------------------------------------
  // LINUX
  // ------------------------------------------------------------
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: "PASTE_LINUX_API_KEY",
    appId: "PASTE_LINUX_APP_ID",
    messagingSenderId: "PASTE_LINUX_SENDER_ID",
    projectId: "PASTE_PROJECT_ID",
    storageBucket: "PASTE_STORAGE_BUCKET",
  );
}
