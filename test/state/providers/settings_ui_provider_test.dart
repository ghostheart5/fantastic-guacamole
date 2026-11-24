import 'dart:convert';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
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
  test('revealing the backup key never invents one', () async {
    final SecureStore keys = SecureStore(backend: InMemorySecureStoreBackend());
    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(keys),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('account-a'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final SettingsUiActions actions = container.read(settingsUiActionsProvider);

    expect(await actions.exportBackupRecoveryKey(), isNull);
    expect(await keys.readAll(), isEmpty);

    // The key the cloud backup path uses for this account is the one shown.
    await BackupCipher(
      keys,
      accountId: 'account-a',
    ).encryptPayload(<String, dynamic>{'version': '3.0.0'});
    final String? shown = await actions.exportBackupRecoveryKey();
    expect(base64Decode(shown!), hasLength(32));
    expect(
      shown,
      await BackupCipher(
        keys,
        accountId: 'account-a',
      ).loadExistingRecoveryKey(),
    );
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
