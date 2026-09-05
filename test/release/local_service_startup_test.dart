import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/telemetry_consent.dart';
import 'package:fantastic_guacamole/data/repositories/feature_flag_repository.dart';
import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/data/services/supabase_client_service.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_bootstrap.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Run separately with --dart-define=CHRONOSPARK_BACKEND_MODE=local.
// A cloud invocation covers the default mode; local cases require that command.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!Env.isLocalMode) {
    test('default build retains the cloud service boundary', () {
      expect(Env.cloudServicesEnabled, isTrue);
      expect(Env.isLocalMode, isFalse);
    });
    return;
  }

  group('local production service isolation', () {
    setUp(() {
      FirebaseBootstrap.resetForTesting();
      SupabaseClientService.resetForTesting();
    });

    test(
      'configured Firebase and Supabase initializers are never called',
      () async {
        int coreCalls = 0;
        int crashCalls = 0;
        int supabaseCalls = 0;
        final FirebaseBootstrap firebase = FirebaseBootstrap(
          initializeCore: () async {
            coreCalls++;
            return null;
          },
          configureCrashlytics: () async {
            crashCalls++;
            return null;
          },
          supportsCrashlytics: true,
        );
        final SupabaseClientService supabase = SupabaseClientService(
          isConfigured: true,
          initializeClient: () async {
            supabaseCalls++;
            return null;
          },
        );

        expect(await firebase.initialize(isMockMode: false), isNull);
        expect(await supabase.initialize(isMockMode: false), isNull);
        expect(coreCalls, 0);
        expect(crashCalls, 0);
        expect(supabaseCalls, 0);
        expect(supabase.client, isNull);
      },
    );

    test(
      'push entry points return without accessing native messaging',
      () async {
        const FirebaseMessagingBootstrap messaging =
            FirebaseMessagingBootstrap();
        FirebaseMessagingBootstrap.configureBackgroundHandler();
        expect(await messaging.initialize(isMockMode: false), isNull);
        expect(
          await messaging.requestPermissionAndToken(isMockMode: false),
          isNull,
        );
        await firebaseMessagingBackgroundHandler(const RemoteMessage());
        expect(FirebaseMessagingBootstrap.latestToken, isNull);
      },
    );

    test('bridge cannot read cloud dependencies or install auth listeners', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((_) {
            fail('Local bridge touched the cloud client provider.');
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(firebaseSupabaseBridgeProvider);
    });

    test('feature flags use local defaults without a Firebase app', () async {
      final RemoteConfigService config = RemoteConfigService(
        initialValues: <String, Object?>{'flag_new_paywall_copy_enabled': true},
      );
      final Map<String, bool> flags = await FeatureFlagRepository(
        config,
      ).loadFlags();
      expect(flags['daily_reflection_tutorial_enabled'], isTrue);
      expect(flags['new_paywall_copy_enabled'], isTrue);
    });

    test('telemetry consent cannot enable collection in local mode', () {
      final TelemetryConsent consent = TelemetryConsent(
        analytics: true,
        crashReporting: true,
        consentVersion: TelemetryConsent.currentConsentVersion,
        updatedAtUtc: DateTime.utc(2026, 9, 5),
      );
      expect(
        TelemetryConsentStore.analyticsCollectionEnabled(consent),
        isFalse,
      );
      expect(TelemetryConsentStore.crashCollectionEnabled(consent), isFalse);
      AppAnalytics.track('app_open');
    });

    test(
      'local secure storage uses the platform backend across containers',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final ProviderContainer first = ProviderContainer();
        await first
            .read(secureStoreProvider)
            .writeString('local_probe', 'persisted');
        first.dispose();
        final ProviderContainer second = ProviderContainer();
        addTearDown(second.dispose);
        expect(
          await second.read(secureStoreProvider).readString('local_probe'),
          'persisted',
        );
        expect(second.read(supabaseClientProvider), isNull);
      },
    );
  });
}
