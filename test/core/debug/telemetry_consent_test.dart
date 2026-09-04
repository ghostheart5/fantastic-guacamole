import 'dart:async';

import 'package:fantastic_guacamole/core/debug/telemetry_consent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
      final TelemetryConsentStore store = TelemetryConsentStore(
        configureRuntime: (TelemetryConsent consent) async {
          applied.add(consent);
        },
      );
      const TelemetryConsent optedIn = TelemetryConsent(
        analytics: true,
        crashReporting: true,
      );

      await store.save(accountId: 'account-123', consent: optedIn);

      expect(await store.load('account-123'), optedIn);
      expect(await store.load('account-456'), const TelemetryConsent());
      expect(applied, <TelemetryConsent>[optedIn]);
      // Launch containment remains authoritative even when a person saves a
      // future preference for a later reviewed release.
      expect(
        TelemetryConsentStore.analyticsCollectionEnabled(optedIn),
        isFalse,
      );
      expect(TelemetryConsentStore.crashCollectionEnabled(optedIn), isFalse);
    },
  );

  test('rapid account changes apply runtime consent in order', () async {
    final String accountAKey = TelemetryConsentStore.storageKeyForAccount(
      'account-a',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      '$accountAKey.analytics': true,
      '$accountAKey.crash_reporting': true,
    });
    final Completer<void> firstStarted = Completer<void>();
    final Completer<void> releaseFirst = Completer<void>();
    final List<TelemetryConsent> applied = <TelemetryConsent>[];
    final TelemetryConsentAccountTransitionCoordinator coordinator =
        TelemetryConsentAccountTransitionCoordinator(
          TelemetryConsentStore(
            configureRuntime: (TelemetryConsent consent) async {
              applied.add(consent);
              if (applied.length == 1) {
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

    expect(applied, <TelemetryConsent>[
      const TelemetryConsent(analytics: true, crashReporting: true),
    ]);
    releaseFirst.complete();
    await Future.wait(<Future<void>>[accountA, accountB, signedOut]);

    expect(applied, <TelemetryConsent>[
      const TelemetryConsent(analytics: true, crashReporting: true),
      const TelemetryConsent(),
      const TelemetryConsent(),
    ]);
  });
}
