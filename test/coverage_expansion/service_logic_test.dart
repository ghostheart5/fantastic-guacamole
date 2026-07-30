import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/utils/helpers.dart';
import 'package:fantastic_guacamole/core/utils/rate_limiter.dart';
import 'package:fantastic_guacamole/core/utils/throttle.dart';
import 'package:fantastic_guacamole/core/utils/validators.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('service and pure logic coverage', () {
    test('Validators enforce expected constraints', () {
      expect(Validators.isNonEmpty('  a  '), isTrue);
      expect(Validators.isNonEmpty('   '), isFalse);
      expect(Validators.minLength('abc', 3), isTrue);
      expect(Validators.maxLength('abc', 2), isFalse);
      expect(Validators.isValidEmail('pilot@chronospark.app'), isTrue);
      expect(Validators.isValidEmail('not-an-email'), isFalse);
      expect(Validators.isStrongPassword('Abcdef12'), isTrue);
      expect(Validators.isStrongPassword('weakpass'), isFalse);
      expect(Validators.isSafeName('Vector-1 alpha_2'), isTrue);
      expect(Validators.isSafeName('bad<>name'), isFalse);
    });

    test('helpers parse mixed values safely', () {
      expect(safeInt('17'), 17);
      expect(safeInt('bad', 9), 9);
      expect(safeDouble('4.25'), closeTo(4.25, 0.0001));
      expect(safeDouble('bad', 1.5), 1.5);
      expect(safeBool('TRUE'), isTrue);
      expect(safeBool('0'), isFalse);
      expect(safeBool('other', true), isTrue);
      expect(safeString(null, 'fallback'), 'fallback');
      expect(safeList<String>(<dynamic>['a', 1, 'b']), const <String>[
        'a',
        'b',
      ]);
      expect(safeMap(<dynamic, dynamic>{1: 'x', 'k': 2}), <String, dynamic>{
        '1': 'x',
        'k': 2,
      });
    });

    test('SlidingWindowRateLimiter enforces quotas and slot timing', () {
      DateTime now = DateTime.utc(2026, 7, 28, 12, 0, 0);
      final SlidingWindowRateLimiter limiter = SlidingWindowRateLimiter(
        maxRequests: 2,
        window: const Duration(seconds: 10),
        now: () => now,
      );

      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse);
      expect(limiter.remaining, 0);
      expect(limiter.timeUntilNextSlot, const Duration(seconds: 10));

      now = now.add(const Duration(seconds: 11));
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.remaining, 1);

      limiter.reset();
      expect(limiter.remaining, 2);
      expect(limiter.timeUntilNextSlot, isNull);
    });

    test('Throttle run and runAsync gate repeated execution', () async {
      final Throttle throttle = Throttle(const Duration(milliseconds: 20));
      int count = 0;

      throttle.run(() => count += 1);
      throttle.run(() => count += 1);
      expect(count, 1);
      expect(throttle.isReady, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 25));
      throttle.run(() => count += 1);
      expect(count, 2);
      await Future<void>.delayed(const Duration(milliseconds: 25));

      int asyncCount = 0;
      await throttle.runAsync(() async {
        asyncCount += 1;
      });
      await throttle.runAsync(() async {
        asyncCount += 1;
      });
      expect(asyncCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 25));
      await throttle.runAsync(() async {
        asyncCount += 1;
      });
      expect(asyncCount, 2);

      throttle.dispose();
      throttle.reset();
      expect(throttle.isReady, isTrue);
    });

    test('Route and onboarding key helpers map consistently', () {
      expect(
        onboardingCompleteStorageKeyForUser('u-1'),
        'onboarding_complete_u-1',
      );
      expect(
        onboardingContentVersionStorageKeyForUser('u-1'),
        'onboarding_content_version_u-1',
      );
      expect(
        onboardingStepStorageKeyForUser('u-1'),
        'onboarding_step_index_u-1',
      );
      expect(
        creatorFirstItemCreatedStorageKeyForUser('u-1'),
        'creator_first_item_created_v1_u-1',
      );
      expect(
        timelineFirstActionCompletedStorageKeyForUser('u-1'),
        'timeline_first_action_completed_v1_u-1',
      );

      expect(RoutePaths.logs, '${RoutePaths.advancedRoot}/logs');
      expect(RoutePaths.timeline, RoutePaths.logs);
      expect(RoutePaths.legacyLogs, RoutePaths.legacyTimeline);
    });
  });
}
