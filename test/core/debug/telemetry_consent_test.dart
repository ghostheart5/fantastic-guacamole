import 'dart:async';

import 'package:fantastic_guacamole/core/debug/telemetry_consent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TelemetryConsentStore.resetRuntimeGateForTesting();
  });

  test('telemetry consent defaults off in a one-way account scope', () async {
    final TelemetryConsentStore store = TelemetryConsentStore(
      configureRuntime: (_) async {},
    );

    expect(await store.load('account-123'), const TelemetryConsent());
    expect(
      TelemetryConsentStore.storageKeyForAccount('account-123'),
      isNot(contains('account-123')),
    );
  });

  test(
    'telemetry choices persist separately and apply runtime controls',
    () async {
      final List<TelemetryConsent> applied = <TelemetryConsent>[];
      final DateTime savedAt = DateTime.utc(2026, 9, 4, 12, 30);
      final TelemetryConsentStore store = TelemetryConsentStore(
        configureRuntime: (TelemetryConsent consent) async {
          applied.add(consent);
        },
        now: () => savedAt,
      );
      const TelemetryConsent optedIn = TelemetryConsent(
        analytics: true,
        crashReporting: true,
      );

      final TelemetryConsent saved = await store.save(
        accountId: 'account-123',
        consent: optedIn,
      );

      expect(saved.analytics, isTrue);
      expect(saved.crashReporting, isTrue);
      expect(saved.consentVersion, TelemetryConsent.currentConsentVersion);
      expect(saved.updatedAtUtc, savedAt);
      expect(await store.load('account-123'), saved);
      expect(await store.load('account-456'), const TelemetryConsent());
      expect(applied, <TelemetryConsent>[const TelemetryConsent(), saved]);
      // Launch containment remains authoritative even when a person saves a
      // future preference for a later reviewed release.
      expect(TelemetryConsentStore.analyticsCollectionEnabled(saved), isFalse);
      expect(TelemetryConsentStore.crashCollectionEnabled(saved), isFalse);
      expect(TelemetryConsentStore.analyticsDispatchAllowed, isFalse);
      expect(TelemetryConsentStore.crashDispatchAllowed, isFalse);
    },
  );

  test(
    'legacy unversioned choices fail closed until consent is renewed',
    () async {
      final String key = TelemetryConsentStore.storageKeyForAccount('legacy');
      SharedPreferences.setMockInitialValues(<String, Object>{
        '$key.analytics': true,
        '$key.crash_reporting': true,
      });
      final TelemetryConsentStore store = TelemetryConsentStore(
        configureRuntime: (_) async {},
      );

      expect(await store.load('legacy'), const TelemetryConsent());
    },
  );

  test(
    'runtime failure rolls persisted consent back and keeps dispatch off',
    () async {
      final String key = TelemetryConsentStore.storageKeyForAccount(
        'account-7',
      );
      final DateTime originalTime = DateTime.utc(2026, 9, 3);
      SharedPreferences.setMockInitialValues(<String, Object>{
        '$key.analytics': false,
        '$key.crash_reporting': false,
        '$key.consent_version': TelemetryConsent.currentConsentVersion,
        '$key.updated_at_utc': originalTime.toIso8601String(),
      });
      final TelemetryConsentStore store = TelemetryConsentStore(
        configureRuntime: (TelemetryConsent consent) async {
          if (consent.analytics) {
            throw StateError('runtime rejected enablement');
          }
        },
        now: () => DateTime.utc(2026, 9, 4),
      );

      await expectLater(
        store.save(
          accountId: 'account-7',
          consent: const TelemetryConsent(analytics: true),
        ),
        throwsStateError,
      );

      expect(
        await store.load('account-7'),
        TelemetryConsent(
          consentVersion: TelemetryConsent.currentConsentVersion,
          updatedAtUtc: originalTime,
        ),
      );
      expect(TelemetryConsentStore.analyticsDispatchAllowed, isFalse);
      expect(TelemetryConsentStore.crashDispatchAllowed, isFalse);
    },
  );

  test('rapid account changes apply runtime consent in order', () async {
    final String accountAKey = TelemetryConsentStore.storageKeyForAccount(
      'account-a',
    );
    final DateTime accountATime = DateTime.utc(2026, 9, 4, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      '$accountAKey.analytics': true,
      '$accountAKey.crash_reporting': true,
      '$accountAKey.consent_version': TelemetryConsent.currentConsentVersion,
      '$accountAKey.updated_at_utc': accountATime.toIso8601String(),
    });
    final Completer<void> firstStarted = Completer<void>();
    final Completer<void> releaseFirst = Completer<void>();
    final List<TelemetryConsent> applied = <TelemetryConsent>[];
    final TelemetryConsentAccountTransitionCoordinator coordinator =
        TelemetryConsentAccountTransitionCoordinator(
          TelemetryConsentStore(
            configureRuntime: (TelemetryConsent consent) async {
              applied.add(consent);
              if (consent.analytics) {
                firstStarted.complete();
                await releaseFirst.future;
              }
            },
          ),
        );

    final Future<void> accountA = coordinator.applyForAccount('account-a');
    await firstStarted.future;
    final Future<void> accountB = coordinator.applyForAccount('account-b');
    final Future<void> signedOut = coordinator.applyForAccount(null);

    expect(applied.first, const TelemetryConsent());
    expect(applied.last.analytics, isTrue);
    expect(applied.last.crashReporting, isTrue);
    releaseFirst.complete();
    await Future.wait(<Future<void>>[accountA, accountB, signedOut]);

    expect(
      applied.where((TelemetryConsent value) => value.analytics),
      hasLength(1),
    );
    expect(applied.last, const TelemetryConsent());
    expect(TelemetryConsentStore.analyticsDispatchAllowed, isFalse);
  });
}
