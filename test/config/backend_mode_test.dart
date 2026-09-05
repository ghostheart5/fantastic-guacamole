import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/backend_mode.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/system/voice/speech_recognition_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scripts/validate_production_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, String> localConfiguration() {
    final Map<String, dynamic> decoded =
        jsonDecode(
              File('tool/local_production_defines.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    return decoded.map(
      (String key, dynamic value) => MapEntry(key, value.toString()),
    );
  }

  test('backend mode has a strict independent identity', () {
    expect(BackendConfiguration.parse('cloud'), BackendMode.cloud);
    expect(BackendConfiguration.parse(' local '), BackendMode.local);
    for (final String invalid in <String>['', 'qa', 'LOCAL', 'locla']) {
      expect(BackendConfiguration.parse(invalid), isNull);
      expect(
        validateProductionConfiguration(<String, String>{
          'CHRONOSPARK_BACKEND_MODE': invalid,
        }),
        contains('CHRONOSPARK_BACKEND_MODE must be cloud or local.'),
      );
    }
  });

  test('local production preset is complete without a cloud configuration', () {
    final Map<String, String> values = localConfiguration();
    expect(validateProductionConfiguration(values), isEmpty);
    expect(values['CHRONOSPARK_APP_FLAVOR'], 'prod');
    expect(values['CHRONOSPARK_BACKEND_MODE'], 'local');
    expect(
      validateProductionConfiguration(values, target: ProductionTarget.ios),
      contains('Local production currently supports Android only.'),
    );
  });

  test(
    'local production validation rejects QA bypasses and service endpoints',
    () {
      for (final String key in <String>[
        'CHRONOSPARK_ENABLE_MOCK_LOGIN',
        'CHRONOSPARK_ENABLE_MOCK_MODE',
        'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
        'CHRONOSPARK_PAYWALL_DISABLED',
        'CHRONOSPARK_ENABLE_CLOUD_SYNC',
        'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
      ]) {
        final Map<String, String> values = localConfiguration()..[key] = 'true';
        expect(
          validateProductionConfiguration(values),
          isNotEmpty,
          reason: key,
        );
      }
      final Map<String, String> cloudEndpoint = localConfiguration()
        ..['CHRONOSPARK_SUPABASE_URL'] = 'https://configured.supabase.co';
      expect(validateProductionConfiguration(cloudEndpoint), isNotEmpty);
      final Map<String, String> noReadiness = localConfiguration()
        ..['CHRONOSPARK_ENFORCE_PROD_READINESS'] = 'false';
      expect(validateProductionConfiguration(noReadiness), isNotEmpty);
    },
  );

  test('cloud production still requires its account backend', () {
    expect(
      validateProductionConfiguration(const <String, String>{}),
      contains('CHRONOSPARK_SUPABASE_URL is required.'),
    );
    expect(
      validateProductionConfiguration(const <String, String>{}),
      contains('CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT is required.'),
    );
  });

  test('bundled environment cannot change compiled backend mode', () {
    final BackendMode? original = BackendConfiguration.mode;
    dotenv.loadFromString(envString: 'CHRONOSPARK_BACKEND_MODE=local');
    expect(BackendConfiguration.mode, original);
    dotenv.clean();
  });

  if (!Env.isLocalMode) {
    test('default build retains cloud mode', () {
      expect(Env.cloudServicesEnabled, isTrue);
    });
    return;
  }

  test(
    'local runtime capabilities stay production-safe without cloud services',
    () {
      expect(Env.cloudServicesEnabled, isFalse);
      expect(Env.isSupabaseConfigured, isFalse);
      expect(Env.isAiProxyConfigured, isFalse);
      expect(Env.enableCloudSync, isFalse);
      expect(Env.enableCloudRestore, isFalse);
      expect(Env.enableRuntimeFeatureFlags, isFalse);
      expect(Env.enableAnalytics, isFalse);
      expect(Env.enableCrashReporting, isFalse);
      expect(Env.subscriptionsEnabled, isFalse);
      expect(Env.paidCreditPlansEnabled, isFalse);
      expect(Env.creditSpendingEnabled, isFalse);
      expect(Env.isMockMode, isFalse);
      expect(Env.isMockLoginEnabled, isFalse);
      expect(Env.hasTesterFullAccess, isFalse);
      expect(Env.isPaywallDisabled, isFalse);
      expect(
        Env.productionReadinessIssues(
          force: true,
          firebaseInitialized: false,
          targetPlatform: TargetPlatform.android,
        ),
        isEmpty,
      );
    },
  );

  test(
    'local access never requests a premium entitlement or tester access',
    () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          entitlementProvider.overrideWith(() => _UnexpectedEntitlement()),
        ],
      );
      addTearDown(container.dispose);
      final AppAccessState access = container.read(appAccessProvider);
      expect(access.isLocalMode, isTrue);
      expect(access.hasPremiumAccess, isFalse);
      expect(access.hasTesterFullAccess, isFalse);
      expect(access.paywallDisabled, isFalse);
      expect(access.paywallEnabled, isFalse);
      expect(access.subscriptionStatusLabel, 'Local profile');
    },
  );

  test('local entitlement rejects stale purchase results', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(entitlementProvider.future);
    await expectLater(
      container
          .read(entitlementProvider.notifier)
          .applyPurchaseResult(
            const SubscriptionState(
              isActive: true,
              status: 'active',
              source: 'supabase_authority',
            ),
          ),
      throwsStateError,
    );
    expect(
      (await container.read(entitlementProvider.future)).isPremium,
      isFalse,
    );
  });

  test(
    'local speech refuses initialization without invoking the platform',
    () async {
      expect(await PluginSpeechRecognitionService().initialize(), isFalse);
    },
  );
}

class _UnexpectedEntitlement extends EntitlementNotifier {
  @override
  Future<EntitlementState> build() =>
      throw StateError('Local access must not request billing entitlement.');
}
