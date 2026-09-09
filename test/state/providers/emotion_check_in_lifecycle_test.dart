import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets(
    'explicit sharing expires and clears on account or consent changes',
    (tester) async {
      var scope = AccountStorageScope.authenticated('owner-a');
      var now = DateTime.utc(2026, 9, 8, 12);
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((ref) => scope),
          emotionClockProvider.overrideWithValue(() => now),
          personalizationProfileProvider.overrideWith(_Consented.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(),
        ),
      );
      final current = container.listen(
        currentPlannerEmotionProvider,
        (_, _) {},
      );
      final shared = container.listen(observedEmotionProvider, (_, _) {});
      addTearDown(current.close);
      addTearDown(shared.close);
      final notifier = container.read(emotionCheckInProvider.notifier);
      notifier.set(EmotionalState.anxious);
      expect(current.read(), EmotionalState.anxious);
      expect(shared.read(), isNull);
      notifier.share(true);
      expect(shared.read(), EmotionalState.anxious);
      now = now.add(const Duration(hours: 2, seconds: 1));
      await tester.pump(const Duration(hours: 2, seconds: 1));
      expect(current.read(), isNull);
      expect(shared.read(), isNull);
      notifier.set(EmotionalState.calm);
      notifier.share(true);
      scope = AccountStorageScope.authenticated('owner-b');
      container.invalidate(accountStorageScopeProvider);
      expect(current.read(), isNull);
      expect(shared.read(), isNull);
      notifier.set(EmotionalState.engaged);
      notifier.share(true);
      (container.read(personalizationProfileProvider.notifier) as _Consented)
          .revoke();
      expect(current.read(), isNull);
      expect(shared.read(), isNull);
      await tester.pump();
    },
  );

  test('future and older than two-hour reports are not current', () {
    final now = DateTime.utc(2026, 9, 8, 12);
    expect(
      EmotionCheckIn(
        value: EmotionalState.calm,
        reportedAt: now.subtract(const Duration(hours: 2, seconds: 1)),
      ).isFreshAt(now),
      isFalse,
    );
    expect(
      EmotionCheckIn(
        value: EmotionalState.calm,
        reportedAt: now.add(const Duration(seconds: 1)),
      ).isFreshAt(now),
      isFalse,
    );
    expect(
      EmotionCheckIn(
        value: EmotionalState.calm,
        reportedAt: now.subtract(const Duration(hours: 1)),
      ).isFreshAt(now),
      isTrue,
    );
  });
}

class _Consented extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() => PersonalizationProfile(
    useEmotionSignals: true,
    emotionConsentGrantedAt: DateTime.utc(2026, 9, 8),
  );
  void revoke() => state = state.copyWith(
    useEmotionSignals: false,
    clearEmotionConsent: true,
  );
}
