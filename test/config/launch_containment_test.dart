import 'dart:io';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsafe launch capabilities fail closed without an override path', () {
    expect(LaunchContainment.cloudSyncEnabled, isFalse);
    expect(LaunchContainment.cloudRestoreEnabled, isFalse);
    expect(LaunchContainment.subscriptionsEnabled, isFalse);
    expect(LaunchContainment.externalAiEnabled, isFalse);
    expect(LaunchContainment.creditSpendingEnabled, isFalse);
    expect(LaunchContainment.externalAiProviderRetentionVerified, isFalse);
    expect(LaunchContainment.externalAiSafetyReviewApproved, isFalse);
    expect(LaunchContainment.analyticsEnabled, isFalse);
    expect(LaunchContainment.crashReportingEnabled, isFalse);
    expect(LaunchContainment.inferredIdentityEnabled, isFalse);

    expect(Env.enableCloudSync, isFalse);
    expect(Env.enableCloudRestore, isFalse);
    expect(Env.subscriptionsEnabled, isFalse);
    expect(Env.externalAiEnabled, isFalse);
    expect(Env.creditSpendingEnabled, isFalse);
    expect(Env.enableAnalytics, isFalse);
    expect(Env.enableCrashReporting, isFalse);
    expect(Env.isAiProxyConfigured, isFalse);
  });

  test('Planner explanation endpoint is canonical to the Supabase origin', () {
    expect(
      Env.resolvePlannerExplanationEndpoint(
        supabaseUrl: 'https://project-ref.supabase.co',
      ),
      'https://project-ref.supabase.co/functions/v1/planner-explanation',
    );
    expect(
      Env.resolvePlannerExplanationEndpoint(
        supabaseUrl: 'https://attacker.example/path',
      ),
      isEmpty,
    );
    expect(
      Env.resolvePlannerExplanationEndpoint(supabaseUrl: 'http://localhost'),
      isEmpty,
    );
  });

  test('native Android telemetry and billing defaults are contained', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('firebase_analytics_collection_enabled'));
    expect(manifest, contains('firebase_crashlytics_collection_enabled'));
    expect(manifest, contains('android:name="com.android.vending.BILLING"'));
    expect(manifest, contains('tools:node="remove"'));
  });

  test('Apple telemetry collection defaults are contained', () {
    for (final String path in <String>[
      'ios/Runner/Info.plist',
      'macos/Runner/Info.plist',
    ]) {
      final String plist = File(path).readAsStringSync();
      expect(plist, contains('FIREBASE_ANALYTICS_COLLECTION_ENABLED'));
      expect(plist, contains('FirebaseCrashlyticsCollectionEnabled'));
    }
  });
}
