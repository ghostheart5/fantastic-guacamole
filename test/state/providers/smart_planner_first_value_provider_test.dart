import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String accountA = 'v2.account-a';
  const String accountB = 'v2.account-b';
  final DateTime now = DateTime.utc(2026, 8, 30, 12);

  test('same account consumes a staged request exactly once', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerFirstValueRequest request = SmartPlannerFirstValueRequest(
      accountScopeId: accountA,
      prompt: 'Help me choose the smallest useful launch step.',
      energy: 0.4,
      createdAt: now,
    );

    container.read(smartPlannerFirstValueProvider.notifier).stage(request);

    expect(
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: accountA, now: now),
      same(request),
    );
    expect(container.read(smartPlannerFirstValueProvider), isNull);
    expect(
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: accountA, now: now),
      isNull,
    );
  });

  test('construction normalizes account, prompt, and UTC timestamp', () {
    final SmartPlannerFirstValueRequest request = SmartPlannerFirstValueRequest(
      accountScopeId: '  $accountA  ',
      prompt: '  Help me choose one step.  ',
      energy: 0,
      createdAt: DateTime(2026, 8, 30, 7),
    );
    final SmartPlannerFirstValueRequest blankPrompt =
        SmartPlannerFirstValueRequest(
          accountScopeId: accountA,
          prompt: '   ',
          energy: 1,
          createdAt: now,
        );

    expect(request.accountScopeId, accountA);
    expect(request.prompt, 'Help me choose one step.');
    expect(request.energy, 0);
    expect(request.createdAt.isUtc, isTrue);
    expect(blankPrompt.prompt, isNull);
  });

  test('construction rejects blank account and invalid energy', () {
    expect(
      () => SmartPlannerFirstValueRequest(accountScopeId: '  ', createdAt: now),
      throwsArgumentError,
    );
    for (final double energy in <double>[
      double.nan,
      double.infinity,
      -0.01,
      1.01,
    ]) {
      expect(
        () => SmartPlannerFirstValueRequest(
          accountScopeId: accountA,
          energy: energy,
          createdAt: now,
        ),
        throwsArgumentError,
        reason: 'energy $energy must be rejected',
      );
    }
  });

  test('account mismatch clears the pending request', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: accountA,
            createdAt: now,
          ),
        );

    expect(
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: accountB, now: now),
      isNull,
    );
    expect(container.read(smartPlannerFirstValueProvider), isNull);
    expect(
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: accountA, now: now),
      isNull,
    );
  });

  test('expired request is cleared at the lifetime boundary', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: accountA,
            prompt: 'This should not be reused.',
            energy: 0.8,
            createdAt: now.subtract(smartPlannerFirstValueRequestLifetime),
          ),
        );

    expect(
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: accountA, now: now),
      isNull,
    );
    expect(container.read(smartPlannerFirstValueProvider), isNull);
  });

  test('future request is cleared against the take-time clock', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: accountA,
            prompt: 'Do not reuse after a clock rollback.',
            createdAt: now.add(const Duration(microseconds: 1)),
          ),
        );

    expect(
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: accountA, now: now),
      isNull,
    );
    expect(container.read(smartPlannerFirstValueProvider), isNull);
  });
}
