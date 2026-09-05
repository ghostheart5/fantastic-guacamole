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
    expect(LaunchContainment.paidCreditPlansEnabled, isFalse);
    expect(LaunchContainment.analyticsEnabled, isFalse);
    expect(LaunchContainment.crashReportingEnabled, isFalse);
    expect(LaunchContainment.inferredIdentityEnabled, isFalse);

    expect(Env.enableCloudSync, isFalse);
    expect(Env.enableCloudRestore, isFalse);
    expect(Env.subscriptionsEnabled, isFalse);
    expect(Env.externalAiEnabled, isFalse);
    expect(Env.creditSpendingEnabled, isFalse);
    expect(Env.paidCreditPlansEnabled, isFalse);
    expect(Env.enableAnalytics, isFalse);
    expect(Env.enableCrashReporting, isFalse);
    expect(Env.isAiProxyConfigured, isFalse);
  });

  test('paid credit plans require every monetization trust gate', () {
    bool resolve({
      bool subscriptions = true,
      bool externalAi = true,
      bool creditSpending = true,
      bool providerRetention = true,
      bool safetyApproval = true,
    }) {
      return LaunchContainment.resolvePaidCreditPlansEnabled(
        subscriptionsEnabled: subscriptions,
        externalAiEnabled: externalAi,
        creditSpendingEnabled: creditSpending,
        providerRetentionVerified: providerRetention,
        safetyReviewApproved: safetyApproval,
      );
    }

    expect(resolve(), isTrue);
    expect(resolve(subscriptions: false), isFalse);
    expect(resolve(externalAi: false), isFalse);
    expect(resolve(creditSpending: false), isFalse);
    expect(resolve(providerRetention: false), isFalse);
    expect(resolve(safetyApproval: false), isFalse);
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

    for (final String setting in <String>[
      'firebase_analytics_collection_enabled',
      'firebase_messaging_auto_init_enabled',
    ]) {
      final List<RegExpMatch> entries = RegExp(
        '<meta-data\\s+[^>]*android:name="$setting"[^>]*/>',
      ).allMatches(manifest).toList();
      expect(entries, hasLength(1), reason: setting);
      expect(entries.single.group(0), contains('android:value="false"'));
    }
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
      expect(
        RegExp(
          r'<key>FirebaseMessagingAutoInitEnabled</key>',
        ).allMatches(plist),
        hasLength(1),
        reason: path,
      );
      expect(
        RegExp(
          r'<key>FirebaseMessagingAutoInitEnabled</key>\s*<false\s*/>',
        ).allMatches(plist),
        hasLength(1),
        reason: path,
      );
    }
  });
}
