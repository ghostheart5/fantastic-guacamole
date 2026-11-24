import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // A throwaway test key; never a real one.
  final String deviceKey = base64Encode(List<int>.filled(32, 3));

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  ProviderContainer containerFor({
    String? existingKey,
    RecoveryKeyImportOutcome importOutcome = RecoveryKeyImportOutcome.installed,
    CloudBackupKeyCheck? keyStatus,
    bool keySaved = false,
    CloudBackupDiscardOutcome discardOutcome =
        CloudBackupDiscardOutcome.discarded,
    CloudBackupPresence presence = CloudBackupPresence.noEncryptedBackup,
    bool importThrows = false,
    _Calls? calls,
  }) {
    final _Calls record = calls ?? _Calls();
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('key-flow-owner'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        cloudSyncPreferenceProvider.overrideWith(
          () => _FakeCloudBackupPreference(record),
        ),
        settingsUiActionsProvider.overrideWith(
          (Ref ref) => _FakeKeyActions(ref, existingKey, record),
        ),
        backupRecoveryKeyImportProvider.overrideWithValue((String key) async {
          record.imports.add(key);
          return importOutcome;
        }),
        recoveryKeyRestoreBeforeEnablingProvider.overrideWithValue((
          String key,
        ) async {
          // Cloud Backup must still be off while the key is checked.
          record.preferenceAtRestore.add(
            record.preferenceWrites.isNotEmpty && record.preferenceWrites.last,
          );
          record.restores.add(key);
          if (importThrows) throw StateError('secure storage failed');
          return importOutcome;
        }),
        cloudBackupPresenceProvider.overrideWithValue(() async {
          record.presenceChecks += 1;
          return presence;
        }),
        cloudBackupKeyStatusProvider.overrideWith((Ref ref) async => keyStatus),
        cloudBackupDiscardProvider.overrideWithValue(() async {
          record.discards += 1;
          return discardOutcome;
        }),
        if (keySaved) recoveryKeySavedProvider.overrideWith(_AlreadySaved.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> mount(
    WidgetTester tester,
    ProviderContainer container,
    Widget child, {
    required bool spanish,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(spanish ? 'es' : 'en'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: ListView(children: <Widget>[child])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  for (final bool spanish in <bool>[false, true]) {
    final String lang = spanish ? 'es' : 'en';
    final BackupRecoveryKeyCopy copy = BackupRecoveryKeyCopy(
      isSpanish: spanish,
    );
    final CloudBackupDiscardCopy discardCopy = CloudBackupDiscardCopy(
      isSpanish: spanish,
    );
    final String cancel = spanish ? 'Cancelar' : 'Cancel';

    testWidgets(
      'turning Cloud Backup on requires saving the key first ($lang)',
      (tester) async {
        final calls = _Calls();
        final container = containerFor(existingKey: deviceKey, calls: calls);
        await mount(
          tester,
          container,
          const CloudBackupToggle(available: true),
          spanish: spanish,
        );

        // Cancelling leaves backup off and shows no key.
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text(copy.saveKeyFirstTitle), findsOneWidget);
        expect(find.text(deviceKey), findsNothing);
        await tapText(tester, cancel);
        expect(calls.preferenceWrites, isEmpty);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

        // Closing the key without confirming also leaves backup off.
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tapText(tester, copy.showKey);
        expect(find.text(deviceKey), findsOneWidget);
        expect(find.text(copy.copyAction), findsOneWidget);
        await tapText(tester, cancel);
        expect(calls.preferenceWrites, isEmpty);
        expect(await container.read(recoveryKeySavedProvider.future), isFalse);

        // Confirming turns it on and is remembered for the account.
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tapText(tester, copy.showKey);
        await tapText(tester, copy.savedIt);
        expect(calls.preferenceWrites, <bool>[true]);
        expect(await container.read(recoveryKeySavedProvider.future), isTrue);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text(copy.saveKeyFirstTitle), findsNothing);
        expect(calls.preferenceWrites, <bool>[true, false, true]);
        expect(calls.createdKeys, 0);
      },
    );

    testWidgets(
      'with no key, a new key is created only on request and must be saved ($lang)',
      (tester) async {
        final calls = _Calls();
        final container = containerFor(calls: calls);
        await mount(
          tester,
          container,
          const CloudBackupToggle(available: true),
          spanish: spanish,
        );

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text(copy.noKeyTitle), findsOneWidget);
        expect(calls.createdKeys, 0);
        await tapText(tester, copy.createNewKey);
        expect(calls.presenceChecks, 1);
        expect(calls.createdKeys, 1);
        await tapText(tester, copy.showKey);
        expect(find.text(deviceKey), findsOneWidget);
        await tapText(tester, copy.savedIt);
        expect(calls.preferenceWrites, <bool>[true]);
      },
    );

    testWidgets(
      'a new key is refused when the account already has an encrypted backup ($lang)',
      (tester) async {
        final calls = _Calls();
        final container = containerFor(
          calls: calls,
          presence: CloudBackupPresence.encryptedBackup,
        );
        await mount(
          tester,
          container,
          const CloudBackupToggle(available: true),
          spanish: spanish,
        );

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tapText(tester, copy.createNewKey);
        expect(calls.createdKeys, 0);
        expect(find.text(copy.backupExistsTitle), findsOneWidget);
        expect(find.text(copy.backupExistsBody), findsOneWidget);
        // The only way forward is the saved key.
        await tapText(tester, copy.useSavedKey);
        expect(
          find.byKey(const Key('backup-recovery-key-input')),
          findsOneWidget,
        );
        await tapText(tester, cancel);
        expect(calls.createdKeys, 0);
        expect(calls.preferenceWrites, isEmpty);
      },
    );

    testWidgets('no new key is made when the cloud cannot be checked ($lang)', (
      tester,
    ) async {
      final calls = _Calls();
      final container = containerFor(
        calls: calls,
        presence: CloudBackupPresence.unknown,
      );
      await mount(
        tester,
        container,
        const CloudBackupToggle(available: true),
        spanish: spanish,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tapText(tester, copy.createNewKey);
      expect(calls.createdKeys, 0);
      expect(find.text(copy.cannotCheckForBackup), findsOneWidget);
      expect(calls.preferenceWrites, isEmpty);
    });

    testWidgets('a failing key check leaves Cloud Backup off ($lang)', (
      tester,
    ) async {
      final calls = _Calls();
      final container = containerFor(calls: calls, importThrows: true);
      await mount(
        tester,
        container,
        const CloudBackupToggle(available: true),
        spanish: spanish,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tapText(tester, copy.useSavedKey);
      await tester.enterText(
        find.byKey(const Key('backup-recovery-key-input')),
        deviceKey,
      );
      await tapText(tester, spanish ? 'Continuar' : 'Continue');
      expect(calls.restores, <String>[deviceKey]);
      expect(calls.preferenceWrites, isEmpty);
      expect(
        find.text(
          copy.importOutcome(RecoveryKeyImportOutcome.cloudUnavailable),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a backup from a newer app version is never offered for discard ($lang)',
      (tester) async {
        final statusCopy = CloudBackupKeyStatusCopy(isSpanish: spanish);
        final container = containerFor(
          existingKey: deviceKey,
          keyStatus: CloudBackupKeyCheck.newerVersion,
          keySaved: true,
        );
        await mount(
          tester,
          container,
          const CloudBackupKeyStatus(),
          spanish: spanish,
        );
        expect(
          find.text(statusCopy.status(CloudBackupKeyCheck.newerVersion)),
          findsOneWidget,
        );
        expect(find.text(discardCopy.actionTitle), findsNothing);
      },
    );

    for (final bool matches in <bool>[true, false]) {
      testWidgets(
        'with no key, a saved key from another device is checked before backup stays on (matches=$matches, $lang)',
        (tester) async {
          final calls = _Calls();
          final container = containerFor(
            calls: calls,
            importOutcome: matches
                ? RecoveryKeyImportOutcome.installed
                : RecoveryKeyImportOutcome.doesNotMatch,
          );
          await mount(
            tester,
            container,
            const CloudBackupToggle(available: true),
            spanish: spanish,
          );

          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          await tapText(tester, copy.useSavedKey);
          // Backup stays off while the user goes to fetch the key.
          expect(calls.preferenceWrites, isEmpty);
          await tester.enterText(
            find.byKey(const Key('backup-recovery-key-input')),
            deviceKey,
          );
          await tapText(tester, spanish ? 'Continuar' : 'Continue');

          expect(calls.restores, <String>[deviceKey]);
          // The key was checked with Cloud Backup still off, and it is
          // turned on only after the key was accepted.
          expect(calls.preferenceAtRestore, <bool>[false]);
          expect(calls.imports, isEmpty);
          expect(calls.createdKeys, 0);
          expect(calls.preferenceWrites, matches ? <bool>[true] : isEmpty);
          expect(
            find.text(
              copy.importOutcome(
                matches
                    ? RecoveryKeyImportOutcome.installed
                    : RecoveryKeyImportOutcome.doesNotMatch,
              ),
            ),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'status line says whether this device can read the backup ($lang)',
      (tester) async {
        final statusCopy = CloudBackupKeyStatusCopy(isSpanish: spanish);
        final container = containerFor(
          existingKey: deviceKey,
          keyStatus: CloudBackupKeyCheck.matches,
          keySaved: true,
        );
        await mount(
          tester,
          container,
          const CloudBackupKeyStatus(),
          spanish: spanish,
        );
        expect(find.text(statusCopy.title), findsOneWidget);
        expect(
          find.text(statusCopy.status(CloudBackupKeyCheck.matches)),
          findsOneWidget,
        );
        expect(find.text(discardCopy.actionTitle), findsNothing);
      },
    );

    testWidgets(
      'an unconfirmed key is offered for saving from the status line ($lang)',
      (tester) async {
        final statusCopy = CloudBackupKeyStatusCopy(isSpanish: spanish);
        final calls = _Calls();
        final container = containerFor(
          existingKey: deviceKey,
          keyStatus: CloudBackupKeyCheck.matches,
          calls: calls,
        );
        await mount(
          tester,
          container,
          const CloudBackupKeyStatus(),
          spanish: spanish,
        );
        final String text = statusCopy.status(
          CloudBackupKeyCheck.matches,
          keySaved: false,
        );
        expect(text, contains(statusCopy.notConfirmedNote));
        await tapText(tester, text);
        await tapText(tester, copy.showKey);
        await tapText(tester, copy.savedIt);
        expect(await container.read(recoveryKeySavedProvider.future), isTrue);
        // Cloud Backup is already on: saving the key does not toggle it.
        expect(calls.preferenceWrites, isEmpty);
      },
    );

    testWidgets(
      'discarding an unreadable backup takes two deliberate steps ($lang)',
      (tester) async {
        final calls = _Calls();
        final container = containerFor(
          existingKey: deviceKey,
          keyStatus: CloudBackupKeyCheck.doesNotMatch,
          keySaved: true,
          calls: calls,
        );
        await mount(
          tester,
          container,
          const CloudBackupKeyStatus(),
          spanish: spanish,
        );

        // Step 1 can be cancelled.
        await tapText(tester, discardCopy.actionTitle);
        expect(find.text(discardCopy.firstStepTitle), findsOneWidget);
        await tapText(tester, cancel);
        expect(calls.discards, 0);

        // Step 2 stays disabled until the confirmation word is typed.
        await tapText(tester, discardCopy.actionTitle);
        await tapText(tester, discardCopy.continueAction);
        expect(find.text(discardCopy.secondStepTitle), findsOneWidget);
        FilledButton deleteButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, discardCopy.deleteAction),
        );
        expect(deleteButton().onPressed, isNull);
        await tester.enterText(
          find.byKey(const Key('discard-cloud-backup-confirmation')),
          'yes',
        );
        await tester.pump();
        expect(deleteButton().onPressed, isNull);
        await tester.enterText(
          find.byKey(const Key('discard-cloud-backup-confirmation')),
          discardCopy.confirmationWord,
        );
        await tester.pump();
        expect(deleteButton().onPressed, isNotNull);
        await tapText(tester, discardCopy.deleteAction);

        expect(calls.discards, 1);
        expect(
          find.text(discardCopy.outcome(CloudBackupDiscardOutcome.discarded)),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('a refused discard is explained and nothing else happens', (
    tester,
  ) async {
    const discardCopy = CloudBackupDiscardCopy(isSpanish: false);
    final calls = _Calls();
    final container = containerFor(
      existingKey: deviceKey,
      keyStatus: CloudBackupKeyCheck.unreadable,
      keySaved: true,
      discardOutcome: CloudBackupDiscardOutcome.refused,
      calls: calls,
    );
    await mount(
      tester,
      container,
      const CloudBackupKeyStatus(),
      spanish: false,
    );
    await tapText(tester, discardCopy.actionTitle);
    await tapText(tester, discardCopy.continueAction);
    await tester.enterText(
      find.byKey(const Key('discard-cloud-backup-confirmation')),
      discardCopy.confirmationWord,
    );
    await tester.pump();
    await tapText(tester, discardCopy.deleteAction);
    expect(calls.discards, 1);
    expect(
      find.text(discardCopy.outcome(CloudBackupDiscardOutcome.refused)),
      findsOneWidget,
    );
  });

  test('discard is offered only when this device cannot read the backup', () {
    expect(
      CloudBackupKeyCheck.values.where(CloudBackupKeyStatus.offersDiscard),
      unorderedEquals(<CloudBackupKeyCheck>[
        CloudBackupKeyCheck.doesNotMatch,
        CloudBackupKeyCheck.unreadable,
        CloudBackupKeyCheck.malformed,
      ]),
    );
  });

  test('key status, discard and key-step copy is bilingual and distinct', () {
    const en = CloudBackupKeyStatusCopy(isSpanish: false);
    const es = CloudBackupKeyStatusCopy(isSpanish: true);
    for (final CloudBackupKeyCheck check in CloudBackupKeyCheck.values) {
      expect(en.status(check), isNot(es.status(check)), reason: '$check');
      expect(en.status(check), isNotEmpty);
    }
    expect(
      en.status(CloudBackupKeyCheck.doesNotMatch),
      contains('does not open your cloud backup'),
    );
    expect(
      es.status(CloudBackupKeyCheck.doesNotMatch),
      contains('no abre tu copia en la nube'),
    );
    // A newer app's backup is never called damaged and never offers discard.
    expect(
      en.status(CloudBackupKeyCheck.newerVersion),
      allOf(contains('newer version'), isNot(contains('damaged'))),
    );
    expect(
      en.status(CloudBackupKeyCheck.newerVersion),
      isNot(contains('discard')),
    );
    expect(
      es.status(CloudBackupKeyCheck.newerVersion),
      allOf(contains('versión más nueva'), isNot(contains('dañada'))),
    );
    const kEn = BackupRecoveryKeyCopy(isSpanish: false);
    const kEs = BackupRecoveryKeyCopy(isSpanish: true);
    expect(
      kEn.importOutcome(RecoveryKeyImportOutcome.newerVersion),
      allOf(contains('newer version'), contains('not changed')),
    );
    expect(
      kEs.importOutcome(RecoveryKeyImportOutcome.newerVersion),
      allOf(contains('versión más nueva'), contains('no se cambió')),
    );
    expect(kEn.backupExistsBody, contains('Use my saved key'));
    expect(kEs.backupExistsBody, contains('Usar mi clave guardada'));
    expect(kEn.cannotCheckForBackup, contains('online'));
    expect(kEs.cannotCheckForBackup, contains('conexión'));
    expect(en.status(CloudBackupKeyCheck.unreadable), contains('damaged'));
    expect(es.status(CloudBackupKeyCheck.unreadable), contains('dañada'));
    // No key: nothing to confirm, so no "tap to save" note.
    expect(
      en.status(CloudBackupKeyCheck.noKeyOnDevice, keySaved: false),
      isNot(contains(en.notConfirmedNote)),
    );

    const dEn = CloudBackupDiscardCopy(isSpanish: false);
    const dEs = CloudBackupDiscardCopy(isSpanish: true);
    for (final CloudBackupDiscardOutcome outcome
        in CloudBackupDiscardOutcome.values) {
      expect(dEn.outcome(outcome), isNot(dEs.outcome(outcome)));
    }
    expect(dEn.confirmationWord, 'DISCARD');
    expect(dEs.confirmationWord, 'DESCARTAR');
    expect(dEn.firstStepBody, contains('cannot be undone'));
    expect(dEs.firstStepBody, contains('no se puede deshacer'));
    expect(dEn.firstStepBody, contains('restore the key instead'));
    expect(
      dEn.outcome(CloudBackupDiscardOutcome.refused),
      contains('nothing was deleted'),
    );
    expect(
      dEs.outcome(CloudBackupDiscardOutcome.refused),
      contains('no se borró nada'),
    );
  });
}

class _Calls {
  final List<bool> preferenceWrites = <bool>[];
  final List<String> imports = <String>[];
  final List<String> restores = <String>[];
  final List<bool> preferenceAtRestore = <bool>[];
  int presenceChecks = 0;
  int createdKeys = 0;
  int discards = 0;
}

class _FakeCloudBackupPreference extends CloudSyncPreferenceNotifier {
  _FakeCloudBackupPreference(this._calls);

  final _Calls _calls;

  @override
  Future<bool> build() async =>
      _calls.preferenceWrites.isEmpty ? false : _calls.preferenceWrites.last;

  @override
  Future<void> setEnabled(bool enabled) async {
    _calls.preferenceWrites.add(enabled);
    state = AsyncData<bool>(enabled);
  }
}

class _AlreadySaved extends RecoveryKeySavedNotifier {
  @override
  Future<bool> build() async => true;
}

class _FakeKeyActions extends SettingsUiActions {
  _FakeKeyActions(super.ref, this._key, this._calls);

  String? _key;
  final _Calls _calls;

  @override
  Future<String?> exportBackupRecoveryKey() async => _key;

  @override
  Future<String> createBackupRecoveryKey() async {
    _calls.createdKeys += 1;
    return _key ??= base64Encode(List<int>.filled(32, 3));
  }
}
