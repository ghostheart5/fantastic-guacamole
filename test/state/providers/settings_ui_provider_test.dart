import 'dart:convert';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android app settings use the native gateway', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <String>[];
    const channel = MethodChannel('chronospark/location');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final external = _SettingsExternalUrls();
    final container = ProviderContainer(
      overrides: [externalUrlServiceProvider.overrideWithValue(external)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(settingsUiActionsProvider).openSystemAppSettings(),
      isTrue,
    );
    expect(calls, ['openAppSettings']);
    expect(external.calls, isEmpty);
  });
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('$platform app settings preserve external fallback', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final external = _SettingsExternalUrls();
      final container = ProviderContainer(
        overrides: [externalUrlServiceProvider.overrideWithValue(external)],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(settingsUiActionsProvider).openSystemAppSettings(),
        isTrue,
      );
      expect(external.calls, ['app-settings:', 'app-prefs:root']);
    });
  }
  test('settings actions export and import the backup recovery key', () async {
    final ProviderContainer source = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ],
    );
    addTearDown(source.dispose);

    final String recoveryKey = await source
        .read(settingsUiActionsProvider)
        .exportBackupRecoveryKey();
    expect(base64Decode(recoveryKey), hasLength(32));

    final ProviderContainer destination = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ],
    );
    addTearDown(destination.dispose);

    final SettingsUiActions destinationActions = destination.read(
      settingsUiActionsProvider,
    );
    await destinationActions.importBackupRecoveryKey(recoveryKey);

    expect(await destinationActions.exportBackupRecoveryKey(), recoveryKey);
  });

  test('cloud sync legacy fallback is proven-owner read-only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cloud_sync_enabled_v1': true,
    });
    final ProviderContainer owner = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('account-a'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenOwned,
        ),
      ],
    );
    final ProviderContainer other = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('account-b'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.ambiguous,
        ),
      ],
    );
    addTearDown(owner.dispose);
    addTearDown(other.dispose);

    expect(await owner.read(cloudSyncPreferenceProvider.future), isTrue);
    expect(await other.read(cloudSyncPreferenceProvider.future), isFalse);
    await other.read(cloudSyncPreferenceProvider.notifier).setEnabled(true);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cloud_sync_enabled_v1'), isTrue);
    expect(
      prefs.getBool(
        'cloud_sync_enabled_v1.'
        '${AccountStorageScope.authenticated('account-b').v2Namespace}',
      ),
      isTrue,
    );
  });
}

class _SettingsExternalUrls extends ExternalUrlService {
  final calls = <String>[];
  @override
  Future<bool> open(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    calls.add(uri.toString());
    return calls.length == 2;
  }
}
