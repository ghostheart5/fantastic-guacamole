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
}
