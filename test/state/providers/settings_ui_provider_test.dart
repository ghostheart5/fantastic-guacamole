import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
