import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local registration retains required storage and notification plugins', () {
    final String registration = File(
      'android/app/src/main/kotlin/com/ghostheart5/chronospark/LocalPluginRegistrant.kt',
    ).readAsStringSync();
    final Set<String> classes = RegExp(
      r'engine\.plugins\.add\(([^()]+)\(\)\)',
    ).allMatches(registration).map((match) => match.group(1)!).toSet();
    expect(
      classes,
      containsAll(<String>[
        'com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin',
        'com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin',
        'io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin',
        'net.wolverinebeach.flutter_timezone.FlutterTimezonePlugin',
        'com.github.dart_lang.jni.JniPlugin',
        'com.github.dart_lang.jni_flutter.JniFlutterPlugin',
      ]),
    );
    expect(classes, isNotEmpty);
    expect(
      classes.where(
        (name) => RegExp(
          'firebase|inapppurchase|speech_to_text',
        ).hasMatch(name.toLowerCase()),
      ),
      isEmpty,
    );
  });

  test('automatic native registration and activity selection share Dart mode', () {
    final String gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final String activity = File(
      'android/app/src/main/kotlin/com/ghostheart5/chronospark/MainActivity.kt',
    ).readAsStringSync();
    expect(
      gradle,
      contains('manifestPlaceholders["chronosparkBackendMode"] = backendMode'),
    );
    expect(
      gradle,
      contains(
        'manifestPlaceholders["chronosparkAutoRegisterPlugins"] = (!isLocalBackend).toString()',
      ),
    );
    expect(
      manifest,
      contains('android:name="io.flutter.automatically-register-plugins"'),
    );
    expect(
      manifest,
      contains(r'android:value="${chronosparkAutoRegisterPlugins}"'),
    );
    expect(
      activity,
      contains('"local" -> LocalPluginRegistrant.registerWith(flutterEngine)'),
    );
    expect(
      activity,
      contains('"cloud" -> super.configureFlutterEngine(flutterEngine)'),
    );
    expect(
      RegExp(
        r'super\.configureFlutterEngine\(flutterEngine\)',
      ).allMatches(activity),
      hasLength(1),
    );
  });
}
